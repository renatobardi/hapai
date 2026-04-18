use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Workspace {
    pub id: Uuid,
    pub name: String,
    pub slug: String,
    pub created_at: DateTime<Utc>,
}

impl Workspace {
    pub fn new(name: String, slug: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            slug,
            created_at: Utc::now(),
        }
    }
}
