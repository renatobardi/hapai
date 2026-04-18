use uuid::Uuid;

use crate::domain::PipelineState;
use crate::errors::CoreError;

pub trait PipelineRepository: Send + Sync {
    async fn find_by_issue_id(&self, issue_id: Uuid) -> Result<Option<PipelineState>, CoreError>;
    async fn create(&self, state: PipelineState) -> Result<PipelineState, CoreError>;
    async fn update(&self, state: PipelineState) -> Result<PipelineState, CoreError>;
}
