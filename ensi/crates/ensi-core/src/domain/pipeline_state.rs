use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum StageStatus {
    Pending,
    Running,
    Done,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "PascalCase")]
pub enum PipelineStage {
    Discovery,
    Planning,
    Architecture,
    Development,
    Review,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PipelineState {
    pub id: Uuid,
    pub issue_id: Uuid,
    pub stage: PipelineStage,
    pub stage_status: StageStatus,
    pub blocked_from_stage: Option<PipelineStage>,
    pub current_task_id: Option<Uuid>,
    pub retry_count: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
