use async_trait::async_trait;
use uuid::Uuid;

use crate::domain::Pat;
use crate::CoreError;

#[async_trait]
pub trait PatRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Pat>, CoreError>;
    async fn find_by_token_hash(&self, token_hash: &str) -> Result<Option<Pat>, CoreError>;
    async fn list_by_member(&self, member_id: Uuid) -> Result<Vec<Pat>, CoreError>;
    async fn create(&self, pat: Pat) -> Result<Pat, CoreError>;
    async fn delete(&self, id: Uuid) -> Result<(), CoreError>;
}
