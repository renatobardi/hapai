"""
Cloud Function: Load audit logs from Cloud Storage to BigQuery
Triggered by: Cloud Storage finalizeCreate event on hapai-audit-* buckets
"""

import json
import logging
import re
from datetime import datetime
from typing import Dict, List, Any
from google.cloud import storage
from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError

# Initialize clients
storage_client = storage.Client()
bigquery_client = bigquery.Client()

# Configuration
PROJECT_ID = None  # Will be inferred from BigQuery client
DATASET_ID = "hapai_dataset"
TABLE_ID = "events"

# Validation patterns
VALID_PROJECT_ID_PATTERN = re.compile(r"^[a-z0-9\-]{6,30}$")
VALID_BUCKET_PATTERN = re.compile(r"^[a-z0-9\-]{3,63}$")
VALID_IDENTIFIER_PATTERN = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")

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


def validate_identifier(identifier: str, identifier_type: str = "identifier") -> bool:
    """Validate BigQuery identifiers (dataset, table names)"""
    if not identifier or not isinstance(identifier, str):
        logger.warning(f"Invalid {identifier_type}: not a string")
        return False
    if len(identifier) > 1024:
        logger.warning(f"Invalid {identifier_type}: too long")
        return False
    if not VALID_IDENTIFIER_PATTERN.match(identifier):
        logger.warning(f"Invalid {identifier_type}: invalid characters")
        return False
    return True


def validate_bucket_name(bucket_name: str) -> bool:
    """Validate Cloud Storage bucket name format"""
    if not bucket_name or not isinstance(bucket_name, str):
        logger.warning("Invalid bucket name: not a string")
        return False
    # Bucket names must be 3-63 chars, lowercase, alphanumeric, hyphens
    if not VALID_BUCKET_PATTERN.match(bucket_name):
        logger.warning(f"Invalid bucket name format: {bucket_name[:50]}")
        return False
    return True


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


def validate_event_fields(obj: Dict[str, Any], line_num: int) -> bool:
    """Validate event object has required fields with correct types"""
    if not isinstance(obj, dict):
        logger.warning(f"Line {line_num}: Event is not a dict")
        return False

    # Check required fields
    if "ts" not in obj or "event" not in obj:
        logger.warning(f"Line {line_num}: Missing required fields (ts, event)")
        return False

    # Type validation
    if not isinstance(obj["ts"], str) or not isinstance(obj["event"], str):
        logger.warning(f"Line {line_num}: Invalid field types")
        return False

    # Length validation (prevent excessively large values)
    max_str_len = 1024
    for field in ["ts", "event", "hook", "tool", "result", "project"]:
        val = obj.get(field, "")
        if isinstance(val, str) and len(val) > max_str_len:
            logger.warning(f"Line {line_num}: Field {field} exceeds max length")
            return False

    return True


def load_jsonl_to_bigquery(
    bucket_name: str, file_path: str, table_id: str
) -> int:
    """
    Load JSONL file from Cloud Storage to BigQuery.
    Returns the number of rows loaded.

    Args:
        bucket_name: Cloud Storage bucket name
        file_path: Path to JSONL file
        table_id: BigQuery table ID (project.dataset.table)

    Returns:
        Number of rows successfully inserted

    Raises:
        ValueError: If inputs are invalid
        GoogleCloudError: If GCS or BigQuery operations fail
    """
    # Validate inputs
    if not validate_bucket_name(bucket_name):
        raise ValueError(f"Invalid bucket name: {bucket_name}")
    if not file_path or not isinstance(file_path, str) or len(file_path) > 1024:
        raise ValueError("Invalid file path")
    if not table_id or not isinstance(table_id, str):
        raise ValueError("Invalid table ID")

    # Security: prevent path traversal
    if ".." in file_path or file_path.startswith("/"):
        raise ValueError("Invalid file path: path traversal detected")

    try:
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(file_path)

        logger.info(f"Reading {file_path} from {bucket_name}")

        # Download blob content with size limit (max 100MB)
        max_file_size = 100 * 1024 * 1024
        content = blob.download_as_text(max_size=max_file_size)

    except GoogleCloudError as e:
        logger.error(f"Error reading GCS file: {e}")
        raise

    if not content or not content.strip():
        logger.warning(f"File {file_path} is empty")
        return 0

    # Parse JSONL and prepare rows
    rows = []
    skipped = 0

    for line_num, line in enumerate(content.strip().split("\n"), 1):
        if not line.strip():
            continue

        try:
            obj = json.loads(line)

            # Validate event structure and fields
            if not validate_event_fields(obj, line_num):
                skipped += 1
                continue

            # Normalize timestamp if needed (ensure RFC 3339 format)
            ts_str = obj.get("ts", "").strip()
            if not ts_str.endswith("Z") and ts_str:
                ts_str += "Z"

            # Build row matching schema (sanitize string values)
            row = {
                "ts": ts_str,
                "event": obj.get("event", "").strip()[:100],
                "hook": obj.get("hook", "").strip()[:100],
                "tool": obj.get("tool", "").strip()[:100],
                "result": str(obj.get("result", "")).strip()[:1024],
                "project": obj.get("project", "").strip()[:100],
            }
            rows.append(row)

        except (json.JSONDecodeError, AttributeError, ValueError) as e:
            logger.warning(f"Line {line_num}: Error parsing record: {type(e).__name__}")
            skipped += 1
            continue

    if not rows:
        logger.warning(f"No valid rows found in {file_path} (skipped {skipped})")
        return 0

    # Insert rows into BigQuery with error handling
    try:
        errors = bigquery_client.insert_rows_json(table_id, rows, timeout=30)

        if errors:
            logger.error(f"BigQuery insert errors (inserted {len(rows) - len(errors)} of {len(rows)}): {errors[:3]}")
            # Return count of successfully inserted rows
            return len(rows) - len(errors)
        else:
            logger.info(f"Successfully inserted {len(rows)} rows into {table_id}")
            return len(rows)

    except GoogleCloudError as e:
        logger.error(f"BigQuery insert failed: {e}")
        raise


def load_audit_from_gcs(event: Dict[str, Any], context=None) -> Dict[str, Any]:
    """
    Cloud Function entry point for Eventarc trigger.
    Triggered by: gs://hapai-audit-*/**.jsonl (Cloud Storage finalize events)

    Args:
        event: Cloud Storage event dict with keys: bucket, name, time, etc.
        context: Cloud Function context (unused)

    Returns:
        JSON response with status, message, and details
    """
    try:
        # Validate event structure
        if not isinstance(event, dict):
            logger.error("Invalid event: not a dict")
            return {"status": "error", "message": "Invalid event format"}

        # Parse trigger metadata
        bucket_name = event.get("bucket")
        file_path = event.get("name")

        # Validate required event fields
        if not bucket_name or not file_path:
            logger.error("Missing bucket or file path in event")
            return {"status": "error", "message": "Missing bucket or file path"}

        # Type validation
        if not isinstance(bucket_name, str) or not isinstance(file_path, str):
            logger.error("Invalid event field types")
            return {"status": "error", "message": "Invalid field types"}

        # Security: validate identifiers
        if not validate_bucket_name(bucket_name):
            logger.error(f"Invalid bucket name format: {bucket_name}")
            return {"status": "error", "message": "Invalid bucket name"}

        # Security: prevent path traversal
        if ".." in file_path or file_path.startswith("/"):
            logger.error(f"Security: Path traversal detected in file_path")
            return {"status": "error", "message": "Invalid file path"}

        # Validate file type (must be JSONL)
        if not file_path.endswith(".jsonl"):
            logger.info(f"Skipping non-JSONL file: {file_path}")
            return {"status": "skipped", "message": "Not a JSONL file"}

        # Security: validate bucket matches expected pattern (hapai-audit-*)
        if not bucket_name.startswith("hapai-audit-"):
            logger.warning(f"Bucket name doesn't match expected pattern: {bucket_name}")
            # Don't reject - allow flexibility, but log for monitoring

        # Infer project ID from BigQuery client
        try:
            project_id = bigquery_client.project
            if not project_id or not isinstance(project_id, str):
                raise ValueError("Cannot determine GCP project")
        except Exception as e:
            logger.error(f"Cannot infer project ID: {e}")
            return {"status": "error", "message": "Cannot determine GCP project"}

        # Ensure dataset and table exist (with validation)
        try:
            table_id = ensure_dataset_and_table(project_id)
        except (ValueError, GoogleCloudError) as e:
            logger.error(f"Failed to ensure dataset/table: {e}")
            return {"status": "error", "message": f"Dataset/table error: {str(e)[:100]}"}

        # Load audit log from GCS to BigQuery
        try:
            rows_loaded = load_jsonl_to_bigquery(bucket_name, file_path, table_id)
        except (ValueError, GoogleCloudError) as e:
            logger.error(f"Failed to load JSONL: {e}")
            return {"status": "error", "message": f"Load error: {str(e)[:100]}"}

        # Success response
        return {
            "status": "success",
            "message": f"Loaded {rows_loaded} rows",
            "rows_loaded": rows_loaded,
            "bucket": bucket_name,
            "file": file_path,
            "table": table_id,
        }

    except Exception as e:
        # Unexpected error - log fully but return safe message
        logger.error(f"Unexpected error in load_audit_from_gcs: {str(e)}", exc_info=True)
        return {"status": "error", "message": "Internal server error"}


def load_audit_logs(request) -> tuple:
    """
    HTTP entry point for Cloud Functions health check.
    For testing/health checks only. Real trigger is Eventarc on Cloud Storage.

    Args:
        request: Flask request object

    Returns:
        Tuple of (response dict, status_code, headers)
    """
    import json as json_module

    try:
        # Log request for monitoring
        logger.info(f"HTTP request received: {request.method}")

        # Only allow GET for health checks
        if request.method not in ["GET", "HEAD"]:
            return (
                json_module.dumps({"status": "error", "message": "Method not allowed"}),
                405,
                {"Content-Type": "application/json"},
            )

        # Return health check response
        response = {"status": "ok", "message": "Cloud Function is running"}
        return (
            json_module.dumps(response),
            200,
            {"Content-Type": "application/json"},
        )

    except Exception as e:
        logger.error(f"Error in load_audit_logs HTTP handler: {e}")
        error_response = {"status": "error", "message": "Internal server error"}
        return (
            json_module.dumps(error_response),
            500,
            {"Content-Type": "application/json"},
        )
