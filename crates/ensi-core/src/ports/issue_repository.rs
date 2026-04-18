use uuid::Uuid;

use crate::domain::issue::{IssuePriority, IssueStatus};
use crate::domain::Issue;
use crate::errors::CoreError;

pub struct IssueFilter {
    pub status: Option<IssueStatus>,
    pub priority: Option<IssuePriority>,
    pub assignee_id: Option<Uuid>,
    pub limit: i64,
    pub offset: i64,
}

impl Default for IssueFilter {
    fn default() -> Self {
        Self {
            status: None,
            priority: None,
            assignee_id: None,
            limit: 50,
            offset: 0,
        }
    }
}

pub trait IssueRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Issue>, CoreError>;
    async fn find_by_project(
        &self,
        project_id: Uuid,
        filter: IssueFilter,
    ) -> Result<Vec<Issue>, CoreError>;
    async fn create(&self, issue: Issue) -> Result<Issue, CoreError>;
    async fn update(&self, issue: Issue) -> Result<Issue, CoreError>;
    async fn delete(&self, id: Uuid) -> Result<(), CoreError>;
}
