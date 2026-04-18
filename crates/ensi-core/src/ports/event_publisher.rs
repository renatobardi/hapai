use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::domain::pipeline_state::PipelineStage;
use crate::errors::CoreError;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum EnsiEvent {
    TaskCreated {
        task_id: Uuid,
        issue_id: Uuid,
        workspace_id: Uuid,
        stage: PipelineStage,
    },
    TaskMessage {
        task_id: Uuid,
        seq: i64,
        role: String,
        content: String,
    },
    TaskCompleted {
        task_id: Uuid,
        artifact_type: String,
    },
    TaskFailed {
        task_id: Uuid,
        error: String,
    },
    PipelineTransition {
        issue_id: Uuid,
        from: PipelineStage,
        to: PipelineStage,
    },
}

pub trait EventPublisher: Send + Sync {
    async fn publish(&self, event: EnsiEvent) -> Result<(), CoreError>;
}
