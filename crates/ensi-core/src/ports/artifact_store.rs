use serde_json::Value;
use uuid::Uuid;

use crate::errors::CoreError;

pub trait ArtifactStore: Send + Sync {
    async fn store(&self, task_id: Uuid, artifact_type: &str, data: Value)
        -> Result<Uuid, CoreError>;
    async fn retrieve(&self, artifact_id: Uuid) -> Result<Option<Value>, CoreError>;
}
