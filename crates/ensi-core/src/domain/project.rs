use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Project {
    pub id: Uuid,
    pub workspace_id: Uuid,
    pub name: String,
    pub slug: String,
    pub issue_counter: i64,
    pub created_at: DateTime<Utc>,
}

impl Project {
    pub fn new(workspace_id: Uuid, name: String, slug: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            workspace_id,
            name,
            slug,
            issue_counter: 0,
            created_at: Utc::now(),
        }
    }
}
