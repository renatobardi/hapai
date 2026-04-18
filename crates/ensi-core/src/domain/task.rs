use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::pipeline_state::PipelineStage;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskStatus {
    Pending,
    Running,
    Completed,
    Failed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskRole {
    User,
    Assistant,
    System,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: Uuid,
    pub issue_id: Uuid,
    pub workspace_id: Uuid,
    pub agent_id: Uuid,
    pub stage: PipelineStage,
    pub status: TaskStatus,
    pub error: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Task {
    pub fn new(
        issue_id: Uuid,
        workspace_id: Uuid,
        agent_id: Uuid,
        stage: PipelineStage,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            issue_id,
            workspace_id,
            agent_id,
            stage,
            status: TaskStatus::Pending,
            error: None,
            created_at: now,
            updated_at: now,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskMessage {
    pub id: Uuid,
    pub task_id: Uuid,
    pub sequence: i64,
    pub role: TaskRole,
    pub content: String,
    pub created_at: DateTime<Utc>,
}

impl TaskMessage {
    pub fn new(task_id: Uuid, sequence: i64, role: TaskRole, content: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            task_id,
            sequence,
            role,
            content,
            created_at: Utc::now(),
        }
    }
}
