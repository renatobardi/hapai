use async_trait::async_trait;
use uuid::Uuid;

use crate::domain::{Issue, IssueStatus, IssuePriority};
use crate::CoreError;

pub struct IssueFilter {
    pub workspace_id: Uuid,
    pub project_id: Option<Uuid>,
    pub status: Option<IssueStatus>,
    pub priority: Option<IssuePriority>,
    pub assignee_id: Option<Uuid>,
    pub limit: i64,
    pub offset: i64,
}

pub struct IssueList {
    pub items: Vec<Issue>,
    pub total: i64,
}

#[async_trait]
pub trait IssueRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Issue>, CoreError>;
    async fn find_by_number(&self, project_id: Uuid, number: i64) -> Result<Option<Issue>, CoreError>;
    async fn list(&self, filter: IssueFilter) -> Result<IssueList, CoreError>;
    async fn create(&self, issue: Issue) -> Result<Issue, CoreError>;
    async fn update(&self, issue: Issue) -> Result<Issue, CoreError>;
    async fn delete(&self, id: Uuid) -> Result<(), CoreError>;
}
