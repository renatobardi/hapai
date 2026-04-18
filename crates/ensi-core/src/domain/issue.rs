use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IssueStatus {
    Todo,
    InProgress,
    InReview,
    Done,
    Blocked,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IssuePriority {
    Urgent,
    High,
    Medium,
    Low,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IssueAssigneeType {
    Member,
    Agent,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Issue {
    pub id: Uuid,
    pub project_id: Uuid,
    pub workspace_id: Uuid,
    pub number: i64,
    pub title: String,
    pub description: Option<String>,
    pub status: IssueStatus,
    pub priority: IssuePriority,
    pub parent_id: Option<Uuid>,
    pub assignee_id: Option<Uuid>,
    pub assignee_type: Option<IssueAssigneeType>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Issue {
    pub fn new(
        project_id: Uuid,
        workspace_id: Uuid,
        number: i64,
        title: String,
        description: Option<String>,
        priority: IssuePriority,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            project_id,
            workspace_id,
            number,
            title,
            description,
            status: IssueStatus::Todo,
            priority,
            parent_id: None,
            assignee_id: None,
            assignee_type: None,
            created_at: now,
            updated_at: now,
        }
    }
}
