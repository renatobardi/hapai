use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use crate::domain::pipeline_state::PipelineStage;
use crate::errors::CoreError;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionInput {
    pub task_id: Uuid,
    pub issue_id: Uuid,
    pub workspace_id: Uuid,
    pub stage: PipelineStage,
    pub issue_title: String,
    pub issue_description: Option<String>,
    pub prior_artifacts: Vec<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionOutput {
    pub task_id: Uuid,
    pub artifact_type: String,
    pub data: Value,
}

pub trait AgentExecutor: Send + Sync {
    async fn execute(&self, input: ExecutionInput) -> Result<ExecutionOutput, CoreError>;
}
