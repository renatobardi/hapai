use uuid::Uuid;

use crate::domain::Project;
use crate::errors::CoreError;

pub trait ProjectRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Project>, CoreError>;
    async fn find_by_workspace(&self, workspace_id: Uuid) -> Result<Vec<Project>, CoreError>;
    async fn find_by_slug(
        &self,
        workspace_id: Uuid,
        slug: &str,
    ) -> Result<Option<Project>, CoreError>;
    async fn create(&self, project: Project) -> Result<Project, CoreError>;
    async fn update(&self, project: Project) -> Result<Project, CoreError>;
    async fn delete(&self, id: Uuid) -> Result<(), CoreError>;
    async fn increment_issue_counter(&self, id: Uuid) -> Result<i64, CoreError>;
}
