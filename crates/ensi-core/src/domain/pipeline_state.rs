use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PipelineStage {
    Discovery,
    Planning,
    Architecture,
    Development,
    Review,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StageStatus {
    Pending,
    Running,
    Done,
    Failed,
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

impl PipelineState {
    pub fn new(issue_id: Uuid) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            issue_id,
            stage: PipelineStage::Discovery,
            stage_status: StageStatus::Pending,
            blocked_from_stage: None,
            current_task_id: None,
            retry_count: 0,
            created_at: now,
            updated_at: now,
        }
    }
}
