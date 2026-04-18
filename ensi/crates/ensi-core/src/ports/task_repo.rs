use async_trait::async_trait;
use uuid::Uuid;

use crate::domain::{Task, TaskMessage};
use crate::CoreError;

#[async_trait]
pub trait TaskRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Task>, CoreError>;
    async fn list_by_issue(&self, issue_id: Uuid) -> Result<Vec<Task>, CoreError>;
    async fn create(&self, task: Task) -> Result<Task, CoreError>;
    async fn update(&self, task: Task) -> Result<Task, CoreError>;

    async fn add_message(&self, message: TaskMessage) -> Result<TaskMessage, CoreError>;
    async fn list_messages(&self, task_id: Uuid, since_seq: i64, limit: i64) -> Result<Vec<TaskMessage>, CoreError>;
    async fn next_sequence(&self, task_id: Uuid) -> Result<i64, CoreError>;
}
