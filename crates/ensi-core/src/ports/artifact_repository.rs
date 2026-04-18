use uuid::Uuid;

use crate::domain::Artifact;
use crate::errors::CoreError;

pub trait ArtifactRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Artifact>, CoreError>;
    async fn find_by_issue(&self, issue_id: Uuid) -> Result<Vec<Artifact>, CoreError>;
    async fn find_by_issue_and_type(
        &self,
        issue_id: Uuid,
        artifact_type: &str,
    ) -> Result<Vec<Artifact>, CoreError>;
    async fn create(&self, artifact: Artifact) -> Result<Artifact, CoreError>;
}
