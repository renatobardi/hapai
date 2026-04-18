use async_trait::async_trait;
use uuid::Uuid;

use crate::domain::Member;
use crate::CoreError;

#[async_trait]
pub trait MemberRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Member>, CoreError>;
    async fn find_by_email(&self, workspace_id: Uuid, email: &str) -> Result<Option<Member>, CoreError>;
    async fn list_by_workspace(&self, workspace_id: Uuid) -> Result<Vec<Member>, CoreError>;
    async fn create(&self, member: Member) -> Result<Member, CoreError>;
    async fn update(&self, member: Member) -> Result<Member, CoreError>;
    async fn delete(&self, id: Uuid) -> Result<(), CoreError>;
}
