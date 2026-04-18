use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MemberRole {
    Owner,
    Admin,
    Member,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Member {
    pub id: Uuid,
    pub workspace_id: Uuid,
    pub email: String,
    pub name: String,
    pub role: MemberRole,
    pub password_hash: String,
    pub created_at: DateTime<Utc>,
}

impl Member {
    pub fn new(
        workspace_id: Uuid,
        email: String,
        name: String,
        role: MemberRole,
        password_hash: String,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            workspace_id,
            email,
            name,
            role,
            password_hash,
            created_at: Utc::now(),
        }
    }
}
