use async_trait::async_trait;
use uuid::Uuid;

use crate::domain::Comment;
use crate::CoreError;

#[async_trait]
pub trait CommentRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Comment>, CoreError>;
    async fn list_by_issue(&self, issue_id: Uuid) -> Result<Vec<Comment>, CoreError>;
    async fn create(&self, comment: Comment) -> Result<Comment, CoreError>;
    async fn update(&self, comment: Comment) -> Result<Comment, CoreError>;
    async fn delete(&self, id: Uuid) -> Result<(), CoreError>;
}
