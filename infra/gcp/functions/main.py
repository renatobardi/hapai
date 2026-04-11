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
    """Get parameterized table reference using current project ID."""
    return f"`{PROJECT_ID}.{DATASET_ID}.{table_name}`"


def _validate_period(body: dict) -> int:
    """Validate period param. Returns 7, 14, or 30 (default 30)."""
    period = body.get("period", 30)
    try:
        period = int(period)
    except (TypeError, ValueError):
        return 30
    return period if period in (7, 14, 30) else 30


def _validate_safe_string(value, max_len: int = 100):
    """Validate a string for use as a BigQuery query parameter."""
    if not value or not isinstance(value, str):
        return None
    value = value.strip()
    if not value or len(value) > max_len:
        return None
    return value


def _validate_limit(body: dict, default: int = 100) -> int:
    limit = body.get("limit", default)
    try:
        limit = int(limit)
    except (TypeError, ValueError):
        return default
    return max(10, min(200, limit))


def _validate_offset(body: dict) -> int:
    offset = body.get("offset", 0)
    try:
        offset = int(offset)
    except (TypeError, ValueError):
        return 0
    return max(0, min(10000, offset))


def _run_query(sql: str, params=None) -> list:
    """Run a BigQuery query, optionally with parameterized inputs."""
    job_config = bigquery.QueryJobConfig(query_parameters=params) if params else None
    result = bigquery_client.query(sql, job_config=job_config).result()
    return [dict(row) for row in result]


def _query_stats(period: int) -> list:
    ref = _get_table_ref(TABLE_ID)
    sql = f"""
        SELECT
          COUNTIF(result = 'deny')        AS denials,
          COUNTIF(result = 'warn')        AS warnings,
          COUNTIF(result = 'allow')       AS allow_count,
          CAST(COUNT(*) AS INT64)         AS total_events
        FROM {ref}
        WHERE ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
    """
    return _run_query(sql)


def _query_timeline(period: int) -> list:
    ref = _get_table_ref(TABLE_ID)
    sql = f"""
        SELECT
          FORMAT_DATE('%Y-%m-%d', DATE(ts)) AS day,
          result                            AS event,
          CAST(COUNT(*) AS INT64)           AS count
        FROM {ref}
        WHERE ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
          AND result IN ('allow', 'deny', 'warn')
        GROUP BY day, result
        ORDER BY day
    """
    return _run_query(sql)


def _query_hooks(period: int) -> list:
    ref = _get_table_ref(TABLE_ID)
    sql = f"""
        SELECT
          hook,
          CAST(COUNT(*) AS INT64) AS blocks
        FROM {ref}
        WHERE result = 'deny'
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
        GROUP BY hook
        ORDER BY blocks DESC
        LIMIT 10
    """
    return _run_query(sql)


def _query_tools(period: int) -> list:
    ref = _get_table_ref(TABLE_ID)
    sql = f"""
        SELECT
          tool,
          CAST(COUNT(*) AS INT64) AS count
        FROM {ref}
        WHERE result = 'deny'
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
        GROUP BY tool
        ORDER BY count DESC
    """
    return _run_query(sql)


def _query_projects(period: int) -> list:
    ref = _get_table_ref(TABLE_ID)
    sql = f"""
        SELECT
          project,
          CAST(COUNT(*) AS INT64) AS count
        FROM {ref}
        WHERE result = 'deny'
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
          AND project IS NOT NULL
        GROUP BY project
        ORDER BY count DESC
        LIMIT 10
    """
    return _run_query(sql)


def _query_denials(
    limit: int,
    offset: int,
    event_filter: str = None,
    hook_filter: str = None,
    tool_filter: str = None,
) -> list:
    ref = _get_table_ref(TABLE_ID)
    where = ["result IN ('deny', 'warn')"]
    params: List[Any] = []

    if event_filter:
        where.append("result = @event_filter")
        params.append(bigquery.ScalarQueryParameter("event_filter", "STRING", event_filter))
    if hook_filter:
        where.append("hook = @hook_filter")
        params.append(bigquery.ScalarQueryParameter("hook_filter", "STRING", hook_filter))
    if tool_filter:
        where.append("tool = @tool_filter")
        params.append(bigquery.ScalarQueryParameter("tool_filter", "STRING", tool_filter))

    params.append(bigquery.ScalarQueryParameter("q_limit",  "INT64", limit))
    params.append(bigquery.ScalarQueryParameter("q_offset", "INT64", offset))

    sql = f"""
        SELECT
          FORMAT_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', ts) AS ts,
          event, hook, tool, result, project
        FROM {ref}
        WHERE {" AND ".join(where)}
        ORDER BY ts DESC
        LIMIT @q_limit
        OFFSET @q_offset
    """
    return _run_query(sql, params)


def _query_hook_detail(hook_name: str, period: int) -> dict:
    """Mini-timeline + tool breakdown + recent events for a specific guard."""
    ref = _get_table_ref(TABLE_ID)
    p = [bigquery.ScalarQueryParameter("hook_name", "STRING", hook_name)]

    timeline = _run_query(f"""
        SELECT
          FORMAT_DATE('%Y-%m-%d', DATE(ts)) AS day,
          CAST(COUNT(*) AS INT64)           AS count
        FROM {ref}
        WHERE hook = @hook_name
          AND result IN ('deny', 'warn')
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
        GROUP BY day ORDER BY day
    """, p)

    breakdown = _run_query(f"""
        SELECT
          tool                    AS label,
          CAST(COUNT(*) AS INT64) AS count
        FROM {ref}
        WHERE hook = @hook_name
          AND result IN ('deny', 'warn')
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
        GROUP BY tool ORDER BY count DESC LIMIT 8
    """, p)

    recent = _run_query(f"""
        SELECT
          FORMAT_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', ts) AS ts,
          event, hook, tool, result, project
        FROM {ref}
        WHERE hook = @hook_name
          AND result IN ('deny', 'warn')
        ORDER BY ts DESC LIMIT 10
    """, p)

    stats_row = _run_query(f"""
        SELECT
          CAST(COUNT(*) AS INT64)                 AS total,
          CAST(COUNTIF(result = 'deny') AS INT64) AS deny_count,
          CAST(COUNTIF(result = 'warn') AS INT64) AS warn_count
        FROM {ref}
        WHERE hook = @hook_name
          AND result IN ('deny', 'warn')
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
    """, p)

    s = stats_row[0] if stats_row else {"total": 0, "deny_count": 0, "warn_count": 0}
    return {"timeline": timeline, "breakdown": breakdown, "recent": recent, **s}


def _query_tool_detail(tool_name: str, period: int) -> dict:
    """Mini-timeline + hook breakdown + recent events for a specific tool."""
    ref = _get_table_ref(TABLE_ID)
    p = [bigquery.ScalarQueryParameter("tool_name", "STRING", tool_name)]

    timeline = _run_query(f"""
        SELECT
          FORMAT_DATE('%Y-%m-%d', DATE(ts)) AS day,
          CAST(COUNT(*) AS INT64)           AS count
        FROM {ref}
        WHERE tool = @tool_name
          AND result IN ('deny', 'warn')
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
        GROUP BY day ORDER BY day
    """, p)

    breakdown = _run_query(f"""
        SELECT
          hook                    AS label,
          CAST(COUNT(*) AS INT64) AS count
        FROM {ref}
        WHERE tool = @tool_name
          AND result IN ('deny', 'warn')
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
        GROUP BY hook ORDER BY count DESC LIMIT 8
    """, p)

    recent = _run_query(f"""
        SELECT
          FORMAT_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', ts) AS ts,
          event, hook, tool, result, project
        FROM {ref}
        WHERE tool = @tool_name
          AND result IN ('deny', 'warn')
        ORDER BY ts DESC LIMIT 10
    """, p)

    stats_row = _run_query(f"""
        SELECT
          CAST(COUNT(*) AS INT64)                 AS total,
          CAST(COUNTIF(result = 'deny') AS INT64) AS deny_count,
          CAST(COUNTIF(result = 'warn') AS INT64) AS warn_count
        FROM {ref}
        WHERE tool = @tool_name
          AND result IN ('deny', 'warn')
          AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {period} DAY)
    """, p)

    s = stats_row[0] if stats_row else {"total": 0, "deny_count": 0, "warn_count": 0}
    return {"timeline": timeline, "breakdown": breakdown, "recent": recent, **s}


@functions_framework.http
def bq_query(request):
    """
    HTTP endpoint: validates Firebase ID token, runs a named BigQuery query.
    Frontend sends: POST { "query_name": "stats", "period": 30, ... }
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
    if not query_name:
        return ({"error": "Missing query_name"}, 400, cors)

    period = _validate_period(body)

    try:
        if query_name == "stats":
            result = _query_stats(period)

        elif query_name == "timeline":
            result = _query_timeline(period)

        elif query_name == "hooks":
            result = _query_hooks(period)

        elif query_name == "tools":
            result = _query_tools(period)

        elif query_name == "projects":
            result = _query_projects(period)

        elif query_name == "denials":
            limit  = _validate_limit(body)
            offset = _validate_offset(body)
            event_filter = _validate_safe_string(body.get("event_filter"), max_len=10)
            hook_filter  = _validate_safe_string(body.get("hook_filter"),  max_len=100)
            tool_filter  = _validate_safe_string(body.get("tool_filter"),  max_len=100)
            if event_filter and event_filter not in ("deny", "warn"):
                event_filter = None
            result = _query_denials(limit, offset, event_filter, hook_filter, tool_filter)

        elif query_name == "hook_detail":
            hook_name = _validate_safe_string(body.get("hook_name"))
            if not hook_name:
                return ({"error": "Missing or invalid hook_name"}, 400, cors)
            result = _query_hook_detail(hook_name, period)

        elif query_name == "tool_detail":
            tool_name = _validate_safe_string(body.get("tool_name"))
            if not tool_name:
                return ({"error": "Missing or invalid tool_name"}, 400, cors)
            result = _query_tool_detail(tool_name, period)

        else:
            return ({"error": f"Unknown query: {query_name}"}, 400, cors)

        return (result, 200, cors)

    except Exception as e:
        logger.error(f"BigQuery query '{query_name}' failed: {e}", exc_info=True)
        return ({"error": "Query failed"}, 500, cors)
