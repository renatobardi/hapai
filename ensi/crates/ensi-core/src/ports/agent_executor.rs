use async_trait::async_trait;
use serde_json::Value;
use uuid::Uuid;

use crate::domain::pipeline_state::PipelineStage;
use crate::CoreError;

pub enum GeminiModel {
    Flash,
    Pro,
}

#[async_trait]
pub trait AgentExecutor: Send + Sync {
    fn model_for_stage(&self, stage: &PipelineStage) -> GeminiModel;

    async fn execute(
        &self,
        task_id: Uuid,
        prompt: &str,
        schema: &Value,
    ) -> Result<Value, CoreError>;
}
