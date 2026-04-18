-- V001: Initial SCHEMAFULL schema for all 12 ensi tables
-- Applied idempotently at startup via _migration table

-- ─── workspace ───────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS workspace SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id         ON workspace TYPE string;
DEFINE FIELD IF NOT EXISTS name       ON workspace TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS slug       ON workspace TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS created_at ON workspace TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at ON workspace TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_workspace_slug ON workspace COLUMNS slug UNIQUE;

-- ─── member ──────────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS member SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id            ON member TYPE string;
DEFINE FIELD IF NOT EXISTS workspace_id  ON member TYPE string;
DEFINE FIELD IF NOT EXISTS name          ON member TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS email         ON member TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS password_hash ON member TYPE string;
DEFINE FIELD IF NOT EXISTS role          ON member TYPE string ASSERT $value IN ["owner", "admin", "member"];
DEFINE FIELD IF NOT EXISTS created_at    ON member TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at    ON member TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_member_workspace    ON member COLUMNS workspace_id;
DEFINE INDEX IF NOT EXISTS idx_member_email_ws     ON member COLUMNS workspace_id, email UNIQUE;

-- ─── agent ───────────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS agent SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id           ON agent TYPE string;
DEFINE FIELD IF NOT EXISTS workspace_id ON agent TYPE string;
DEFINE FIELD IF NOT EXISTS name         ON agent TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS description  ON agent TYPE option<string>;
DEFINE FIELD IF NOT EXISTS created_at   ON agent TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at   ON agent TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_agent_workspace ON agent COLUMNS workspace_id;

-- ─── project ─────────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS project SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id             ON project TYPE string;
DEFINE FIELD IF NOT EXISTS workspace_id   ON project TYPE string;
DEFINE FIELD IF NOT EXISTS name           ON project TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS slug           ON project TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS issue_counter  ON project TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS created_at     ON project TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at     ON project TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_project_workspace ON project COLUMNS workspace_id;
DEFINE INDEX IF NOT EXISTS idx_project_slug_ws   ON project COLUMNS workspace_id, slug UNIQUE;

-- ─── issue ───────────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS issue SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id            ON issue TYPE string;
DEFINE FIELD IF NOT EXISTS workspace_id  ON issue TYPE string;
DEFINE FIELD IF NOT EXISTS project_id    ON issue TYPE string;
DEFINE FIELD IF NOT EXISTS number        ON issue TYPE int;
DEFINE FIELD IF NOT EXISTS title         ON issue TYPE string
    ASSERT string::len($value) > 0 AND string::len($value) <= 512;
DEFINE FIELD IF NOT EXISTS description   ON issue TYPE option<string>
    ASSERT $value = NONE OR string::len($value) <= 65536;
DEFINE FIELD IF NOT EXISTS status        ON issue TYPE string
    ASSERT $value IN ["todo", "in_progress", "in_review", "done", "blocked"];
DEFINE FIELD IF NOT EXISTS priority      ON issue TYPE string
    ASSERT $value IN ["urgent", "high", "medium", "low"];
DEFINE FIELD IF NOT EXISTS parent_id     ON issue TYPE option<string>;
DEFINE FIELD IF NOT EXISTS assignee_id   ON issue TYPE option<string>;
DEFINE FIELD IF NOT EXISTS assignee_type ON issue TYPE option<string>
    ASSERT $value = NONE OR $value IN ["member", "agent"];
DEFINE FIELD IF NOT EXISTS created_at    ON issue TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at    ON issue TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_issue_workspace ON issue COLUMNS workspace_id;
DEFINE INDEX IF NOT EXISTS idx_issue_project   ON issue COLUMNS project_id;
DEFINE INDEX IF NOT EXISTS idx_issue_number    ON issue COLUMNS project_id, number UNIQUE;
DEFINE INDEX IF NOT EXISTS idx_issue_status    ON issue COLUMNS workspace_id, status;
DEFINE INDEX IF NOT EXISTS idx_issue_assignee  ON issue COLUMNS workspace_id, assignee_id;

-- ─── pipeline_state ──────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS pipeline_state SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id                  ON pipeline_state TYPE string;
DEFINE FIELD IF NOT EXISTS issue_id            ON pipeline_state TYPE string;
DEFINE FIELD IF NOT EXISTS stage               ON pipeline_state TYPE string
    ASSERT $value IN ["Discovery", "Planning", "Architecture", "Development", "Review"];
DEFINE FIELD IF NOT EXISTS stage_status        ON pipeline_state TYPE string
    ASSERT $value IN ["pending", "running", "done", "failed"];
DEFINE FIELD IF NOT EXISTS blocked_from_stage  ON pipeline_state TYPE option<string>
    ASSERT $value = NONE OR $value IN ["Discovery", "Planning", "Architecture", "Development", "Review"];
DEFINE FIELD IF NOT EXISTS current_task_id     ON pipeline_state TYPE option<string>;
DEFINE FIELD IF NOT EXISTS retry_count         ON pipeline_state TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS created_at          ON pipeline_state TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at          ON pipeline_state TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_pipeline_issue  ON pipeline_state COLUMNS issue_id UNIQUE;

-- ─── task ────────────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS task SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id             ON task TYPE string;
DEFINE FIELD IF NOT EXISTS issue_id       ON task TYPE string;
DEFINE FIELD IF NOT EXISTS workspace_id   ON task TYPE string;
DEFINE FIELD IF NOT EXISTS agent_id       ON task TYPE string;
DEFINE FIELD IF NOT EXISTS pipeline_stage ON task TYPE string
    ASSERT $value IN ["Discovery", "Planning", "Architecture", "Development", "Review"];
DEFINE FIELD IF NOT EXISTS status         ON task TYPE string
    ASSERT $value IN ["pending", "running", "completed", "failed"];
DEFINE FIELD IF NOT EXISTS error          ON task TYPE option<string>;
DEFINE FIELD IF NOT EXISTS created_at     ON task TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at     ON task TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_task_issue     ON task COLUMNS issue_id;
DEFINE INDEX IF NOT EXISTS idx_task_workspace ON task COLUMNS workspace_id;
DEFINE INDEX IF NOT EXISTS idx_task_status    ON task COLUMNS workspace_id, status;

-- ─── task_message ─────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS task_message SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id         ON task_message TYPE string;
DEFINE FIELD IF NOT EXISTS task_id    ON task_message TYPE string;
DEFINE FIELD IF NOT EXISTS sequence   ON task_message TYPE int;
DEFINE FIELD IF NOT EXISTS role       ON task_message TYPE string
    ASSERT $value IN ["system", "user", "assistant"];
DEFINE FIELD IF NOT EXISTS content    ON task_message TYPE string;
DEFINE FIELD IF NOT EXISTS created_at ON task_message TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_task_message_task ON task_message COLUMNS task_id;
DEFINE INDEX IF NOT EXISTS idx_task_message_seq  ON task_message COLUMNS task_id, sequence UNIQUE;

-- ─── artifact ─────────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS artifact SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id                ON artifact TYPE string;
DEFINE FIELD IF NOT EXISTS issue_id          ON artifact TYPE string;
DEFINE FIELD IF NOT EXISTS workspace_id      ON artifact TYPE string;
DEFINE FIELD IF NOT EXISTS artifact_type     ON artifact TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS pipeline_stage    ON artifact TYPE string
    ASSERT $value IN ["Discovery", "Planning", "Architecture", "Development", "Review"];
DEFINE FIELD IF NOT EXISTS data              ON artifact TYPE object;
DEFINE FIELD IF NOT EXISTS schema_version    ON artifact TYPE string DEFAULT "1.0";
DEFINE FIELD IF NOT EXISTS created_by_task   ON artifact TYPE string;
DEFINE FIELD IF NOT EXISTS created_at        ON artifact TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_artifact_issue ON artifact COLUMNS issue_id;
DEFINE INDEX IF NOT EXISTS idx_artifact_type  ON artifact COLUMNS issue_id, artifact_type;

-- ─── comment ──────────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS comment SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id           ON comment TYPE string;
DEFINE FIELD IF NOT EXISTS issue_id     ON comment TYPE string;
DEFINE FIELD IF NOT EXISTS workspace_id ON comment TYPE string;
DEFINE FIELD IF NOT EXISTS author_id    ON comment TYPE string;
DEFINE FIELD IF NOT EXISTS author_type  ON comment TYPE string ASSERT $value IN ["member", "agent"];
DEFINE FIELD IF NOT EXISTS content      ON comment TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS parent_id    ON comment TYPE option<string>;
DEFINE FIELD IF NOT EXISTS created_at   ON comment TYPE datetime DEFAULT time::now();
DEFINE FIELD IF NOT EXISTS updated_at   ON comment TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_comment_issue ON comment COLUMNS issue_id;

-- ─── pat ──────────────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS pat SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id           ON pat TYPE string;
DEFINE FIELD IF NOT EXISTS workspace_id ON pat TYPE string;
DEFINE FIELD IF NOT EXISTS member_id    ON pat TYPE string;
DEFINE FIELD IF NOT EXISTS name         ON pat TYPE string ASSERT string::len($value) > 0;
DEFINE FIELD IF NOT EXISTS token_hash   ON pat TYPE string;
DEFINE FIELD IF NOT EXISTS expires_at   ON pat TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at   ON pat TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_pat_member     ON pat COLUMNS member_id;
DEFINE INDEX IF NOT EXISTS idx_pat_token_hash ON pat COLUMNS token_hash UNIQUE;

-- ─── daemon_token ─────────────────────────────────────────────────────────────

DEFINE TABLE IF NOT EXISTS daemon_token SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS id           ON daemon_token TYPE string;
DEFINE FIELD IF NOT EXISTS task_id      ON daemon_token TYPE string;
DEFINE FIELD IF NOT EXISTS workspace_id ON daemon_token TYPE string;
DEFINE FIELD IF NOT EXISTS token_hash   ON daemon_token TYPE string;
DEFINE FIELD IF NOT EXISTS expires_at   ON daemon_token TYPE datetime;
DEFINE FIELD IF NOT EXISTS revoked      ON daemon_token TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS created_at   ON daemon_token TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_daemon_token_task       ON daemon_token COLUMNS task_id UNIQUE;
DEFINE INDEX IF NOT EXISTS idx_daemon_token_hash       ON daemon_token COLUMNS token_hash UNIQUE;
