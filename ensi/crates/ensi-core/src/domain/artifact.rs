use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use super::pipeline_state::PipelineStage;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Artifact {
    pub id: Uuid,
    pub issue_id: Uuid,
    pub workspace_id: Uuid,
    pub artifact_type: String,
    pub pipeline_stage: PipelineStage,
    pub data: Value,
    pub schema_version: String,
    pub created_by_task: Uuid,
    pub created_at: DateTime<Utc>,
}
