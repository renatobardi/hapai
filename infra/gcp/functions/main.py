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
PROJECT_ID = bigquery_client.project
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


# ─── BigQuery Query Proxy ──────────────────────────────────────────────────────

import firebase_admin
from firebase_admin import auth as firebase_auth
import functions_framework

if not firebase_admin._apps:
    firebase_admin.initialize_app()

_ALLOWED_ORIGINS = {
    "https://hapai.oute.pro",
    "https://renatobardi.github.io",
}

def _get_table_ref(table_name: str) -> str:
    """Get parameterized table reference using current project ID"""
    return f"`{PROJECT_ID}.{DATASET_ID}.{table_name}`"


_QUERY_TEMPLATES = {
    "stats": """
        SELECT
          COUNTIF(event = 'deny')  AS denials,
          COUNTIF(event = 'warn')  AS warnings
        FROM {table_ref}
        WHERE ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    """,
    "timeline": """
        SELECT
          FORMAT_DATE('%Y-%m-%d', DATE(ts)) AS day,
          event,
          CAST(COUNT(*) AS INT64)           AS count
        FROM {table_ref}
        WHERE ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        GROUP BY day, event
        ORDER BY day
    """,
    "hooks": """
        SELECT
          hook,
          CAST(COUNT(*) AS INT64) AS blocks
        FROM {table_ref}
        WHERE event = 'deny'
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        GROUP BY hook
        ORDER BY blocks DESC
        LIMIT 10
    """,
    "denials": """
        SELECT
          FORMAT_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', ts) AS ts,
          event, hook, tool, result
        FROM {table_ref}
        WHERE event IN ('deny', 'warn')
        ORDER BY ts DESC
        LIMIT 50
    """,
    "tools": """
        SELECT
          tool,
          CAST(COUNT(*) AS INT64) AS count
        FROM {table_ref}
        WHERE event = 'deny'
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        GROUP BY tool
        ORDER BY count DESC
    """,
    "projects": """
        SELECT
          project,
          CAST(COUNT(*) AS INT64) AS count
        FROM {table_ref}
        WHERE event = 'deny'
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
          AND project IS NOT NULL
        GROUP BY project
        ORDER BY count DESC
        LIMIT 10
    """,
    "trends": """
        SELECT
          FORMAT_DATE('%Y-%m-%d', DATE(ts))      AS day,
          CAST(COUNTIF(event = 'deny') AS INT64) AS denies
        FROM {table_ref}
        WHERE ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        GROUP BY day
        ORDER BY day
    """,
}


def get_query(query_name: str) -> str:
    """Get a query template with project ID substituted"""
    template = _QUERY_TEMPLATES.get(query_name)
    if not template:
        return None
    return template.format(table_ref=_get_table_ref(TABLE_ID))


@functions_framework.http
def bq_query(request):
    """
    HTTP endpoint: validates Firebase ID token, runs a named BigQuery query.
    Frontend sends: POST { "query_name": "stats" }
    Authorization: Bearer <firebase-id-token>
    """
    origin = request.headers.get("Origin", "")
    allowed_origin = origin if origin in _ALLOWED_ORIGINS else next(iter(_ALLOWED_ORIGINS))
    cors = {"Access-Control-Allow-Origin": allowed_origin}

    if request.method == "OPTIONS":
        return ("", 204, {
            **cors,
            "Access-Control-Allow-Headers": "Authorization, Content-Type",
            "Access-Control-Allow-Methods": "POST",
        })

    auth_header = request.headers.get("Authorization", "") or ""
    if not auth_header.startswith("Bearer "):
        return ({"error": "Unauthorized"}, 401, cors)

    id_token = auth_header[len("Bearer "):]
    try:
        firebase_auth.verify_id_token(id_token)
    except Exception as e:
        logger.warning(f"Token validation failed: {e}")
        return ({"error": "Invalid token"}, 401, cors)

    body = request.get_json(silent=True) or {}
    query_name = body.get("query_name")
    query = get_query(query_name)
    if not query:
        return ({"error": f"Unknown query: {query_name}"}, 400, cors)

    try:
        rows = [dict(row) for row in bigquery_client.query(query).result()]
        return (rows, 200, cors)
    except Exception as e:
        logger.error(f"BigQuery query '{query_name}' failed: {e}", exc_info=True)
        return ({"error": "Query failed"}, 500, cors)
