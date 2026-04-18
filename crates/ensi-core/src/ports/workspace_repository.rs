use uuid::Uuid;

use crate::domain::Workspace;
use crate::errors::CoreError;

pub trait WorkspaceRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Workspace>, CoreError>;
    async fn find_by_slug(&self, slug: &str) -> Result<Option<Workspace>, CoreError>;
    async fn create(&self, workspace: Workspace) -> Result<Workspace, CoreError>;
    async fn update(&self, workspace: Workspace) -> Result<Workspace, CoreError>;
}
