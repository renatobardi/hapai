use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Agent {
    pub id: Uuid,
    pub workspace_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
}

impl Agent {
    pub fn new(workspace_id: Uuid, name: String, description: Option<String>) -> Self {
        Self {
            id: Uuid::new_v4(),
            workspace_id,
            name,
            description,
            created_at: Utc::now(),
        }
    }
}
