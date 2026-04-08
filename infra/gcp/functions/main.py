"""
Cloud Function: Load audit logs from Cloud Storage to BigQuery
Triggered by: Cloud Storage finalizeCreate event on hapai-audit-* buckets
"""

import json
import logging
from datetime import datetime
from google.cloud import storage
from google.cloud import bigquery

# Initialize clients
storage_client = storage.Client()
bigquery_client = bigquery.Client()

# Configuration
PROJECT_ID = None  # Will be inferred from BigQuery client
DATASET_ID = "hapai_dataset"
TABLE_ID = "events"

# BigQuery schema
SCHEMA = [
    bigquery.SchemaField("ts", "TIMESTAMP", mode="REQUIRED"),
    bigquery.SchemaField("event", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("hook", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("tool", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("result", "STRING", mode="NULLABLE"),
    bigquery.SchemaField("project", "STRING", mode="NULLABLE"),
]

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def ensure_dataset_and_table(project_id: str) -> str:
    """
    Ensure BigQuery dataset and table exist with proper schema.
    Returns the full table ID.
    """
    dataset_ref = f"{project_id}.{DATASET_ID}"
    table_ref = f"{dataset_ref}.{TABLE_ID}"

    # Check and create dataset if needed
    try:
        bigquery_client.get_dataset(dataset_ref)
        logger.info(f"Dataset {dataset_ref} exists")
    except Exception as e:
        logger.info(f"Creating dataset {dataset_ref}: {e}")
        dataset = bigquery.Dataset(dataset_ref)
        dataset.location = "US"
        bigquery_client.create_dataset(dataset, timeout=30)

    # Check and create table if needed
    try:
        bigquery_client.get_table(table_ref)
        logger.info(f"Table {table_ref} exists")
    except Exception as e:
        logger.info(f"Creating table {table_ref}: {e}")
        table = bigquery.Table(table_ref, schema=SCHEMA)
        table.time_partitioning = bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field="ts",
            expiration_ms=90 * 24 * 3600 * 1000,  # 90 days
        )
        bigquery_client.create_table(table, timeout=30)

    return table_ref


def load_jsonl_to_bigquery(
    bucket_name: str, file_path: str, table_id: str
) -> int:
    """
    Load JSONL file from Cloud Storage to BigQuery.
    Returns the number of rows loaded.
    """
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_path)

    logger.info(f"Reading {file_path} from {bucket_name}")

    # Download blob content
    content = blob.download_as_text()

    if not content.strip():
        logger.warning(f"File {file_path} is empty")
        return 0

    # Parse JSONL and prepare rows
    rows = []
    for line_num, line in enumerate(content.strip().split("\n"), 1):
        if not line.strip():
            continue

        try:
            obj = json.loads(line)

            # Validate required fields
            if "ts" not in obj or "event" not in obj:
                logger.warning(f"Line {line_num}: Missing required fields (ts, event)")
                continue

            # Normalize timestamp if needed (ensure RFC 3339 format)
            ts_str = obj.get("ts", "")
            if not ts_str.endswith("Z"):
                ts_str += "Z"

            # Build row matching schema
            row = {
                "ts": ts_str,
                "event": obj.get("event", ""),
                "hook": obj.get("hook", ""),
                "tool": obj.get("tool", ""),
                "result": obj.get("result", ""),
                "project": obj.get("project", ""),
            }
            rows.append(row)

        except json.JSONDecodeError as e:
            logger.warning(f"Line {line_num}: Invalid JSON: {e}")
            continue

    if not rows:
        logger.warning(f"No valid rows found in {file_path}")
        return 0

    # Insert rows into BigQuery
    errors = bigquery_client.insert_rows_json(table_id, rows, timeout=30)

    if errors:
        logger.error(f"BigQuery insert errors: {errors}")
        # Don't fail — log and continue
    else:
        logger.info(f"Successfully inserted {len(rows)} rows into {table_id}")

    return len(rows)


def load_audit_from_gcs(event, context):
    """
    Cloud Function entry point.
    Triggered by: gs://hapai-audit-*/**.jsonl (Eventarc/Cloud Storage)
    """
    logger.info(f"Received event: {json.dumps(event)}")

    # Parse trigger metadata
    bucket_name = event.get("bucket")
    file_path = event.get("name")

    if not bucket_name or not file_path:
        logger.error("Missing bucket or file path in event")
        return {"status": "error", "message": "Invalid event"}

    # Validate file type
    if not file_path.endswith(".jsonl"):
        logger.info(f"Skipping non-JSONL file: {file_path}")
        return {"status": "skipped", "message": "Not a JSONL file"}

    try:
        # Infer project ID from bucket name
        # Bucket naming convention: hapai-audit-{username}
        # GCP project can be inferred from the storage bucket's project
        project_id = bigquery_client.project

        # Ensure dataset and table exist
        table_id = ensure_dataset_and_table(project_id)

        # Load audit log
        rows_loaded = load_jsonl_to_bigquery(bucket_name, file_path, table_id)

        return {
            "status": "success",
            "message": f"Loaded {rows_loaded} rows",
            "bucket": bucket_name,
            "file": file_path,
            "table": table_id,
        }

    except Exception as e:
        logger.error(f"Error processing {file_path}: {str(e)}", exc_info=True)
        return {"status": "error", "message": str(e)}


def load_audit_logs(request):
    """
    HTTP entry point for Cloud Functions.
    For testing/health checks only.
    Real trigger is Eventarc on Cloud Storage.
    """
    return {"status": "ok", "message": "Cloud Function is running"}
