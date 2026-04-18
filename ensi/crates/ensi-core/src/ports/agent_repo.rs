use async_trait::async_trait;
use uuid::Uuid;

use crate::domain::Agent;
use crate::CoreError;

#[async_trait]
pub trait AgentRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Agent>, CoreError>;
    async fn list_by_workspace(&self, workspace_id: Uuid) -> Result<Vec<Agent>, CoreError>;
    async fn create(&self, agent: Agent) -> Result<Agent, CoreError>;
    async fn update(&self, agent: Agent) -> Result<Agent, CoreError>;
    async fn delete(&self, id: Uuid) -> Result<(), CoreError>;
}
