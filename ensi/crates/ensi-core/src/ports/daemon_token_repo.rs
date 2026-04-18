use async_trait::async_trait;
use uuid::Uuid;

use crate::domain::DaemonToken;
use crate::CoreError;

#[async_trait]
pub trait DaemonTokenRepository: Send + Sync {
    async fn find_by_task(&self, task_id: Uuid) -> Result<Option<DaemonToken>, CoreError>;
    async fn find_by_token_hash(&self, token_hash: &str) -> Result<Option<DaemonToken>, CoreError>;
    async fn create(&self, token: DaemonToken) -> Result<DaemonToken, CoreError>;
    async fn revoke(&self, id: Uuid) -> Result<(), CoreError>;
}
