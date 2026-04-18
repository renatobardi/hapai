use async_trait::async_trait;
use uuid::Uuid;

use crate::domain::PipelineState;
use crate::CoreError;

#[async_trait]
pub trait PipelineRepository: Send + Sync {
    async fn find_by_issue(&self, issue_id: Uuid) -> Result<Option<PipelineState>, CoreError>;
    async fn find_by_id(&self, id: Uuid) -> Result<Option<PipelineState>, CoreError>;
    async fn create(&self, state: PipelineState) -> Result<PipelineState, CoreError>;
    async fn update(&self, state: PipelineState) -> Result<PipelineState, CoreError>;
}
