use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use super::pipeline_state::PipelineStage;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Artifact {
    pub id: Uuid,
    pub issue_id: Uuid,
    pub artifact_type: String,
    pub pipeline_stage: PipelineStage,
    pub data: Value,
    pub schema_version: String,
    pub created_by_task: Uuid,
    pub created_at: DateTime<Utc>,
}

impl Artifact {
    pub fn new(
        issue_id: Uuid,
        artifact_type: String,
        pipeline_stage: PipelineStage,
        data: Value,
        created_by_task: Uuid,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            issue_id,
            artifact_type,
            pipeline_stage,
            data,
            schema_version: "1.0".to_string(),
            created_by_task,
            created_at: Utc::now(),
        }
    }
}
