use async_trait::async_trait;
use serde_json::Value;
use uuid::Uuid;

use crate::CoreError;

#[async_trait]
pub trait ArtifactStore: Send + Sync {
    async fn put(&self, artifact_id: Uuid, data: Value) -> Result<(), CoreError>;
    async fn get(&self, artifact_id: Uuid) -> Result<Option<Value>, CoreError>;
    async fn delete(&self, artifact_id: Uuid) -> Result<(), CoreError>;
}
