use uuid::Uuid;

use crate::domain::Member;
use crate::errors::CoreError;

pub trait MemberRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Member>, CoreError>;
    async fn find_by_email(&self, email: &str) -> Result<Option<Member>, CoreError>;
    async fn find_by_workspace(&self, workspace_id: Uuid) -> Result<Vec<Member>, CoreError>;
    async fn create(&self, member: Member) -> Result<Member, CoreError>;
    async fn update(&self, member: Member) -> Result<Member, CoreError>;
}
