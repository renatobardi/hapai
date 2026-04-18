use async_trait::async_trait;
use uuid::Uuid;

use crate::domain::Artifact;
use crate::CoreError;

#[async_trait]
pub trait ArtifactRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Artifact>, CoreError>;
    async fn find_by_type(&self, issue_id: Uuid, artifact_type: &str) -> Result<Option<Artifact>, CoreError>;
    async fn list_by_issue(&self, issue_id: Uuid) -> Result<Vec<Artifact>, CoreError>;
    async fn create(&self, artifact: Artifact) -> Result<Artifact, CoreError>;
}
