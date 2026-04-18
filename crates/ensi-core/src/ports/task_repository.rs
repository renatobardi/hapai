use uuid::Uuid;

use crate::domain::task::{Task, TaskMessage};
use crate::errors::CoreError;

pub trait TaskRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Task>, CoreError>;
    async fn find_by_issue(&self, issue_id: Uuid) -> Result<Vec<Task>, CoreError>;
    async fn create(&self, task: Task) -> Result<Task, CoreError>;
    async fn update(&self, task: Task) -> Result<Task, CoreError>;

    async fn append_message(&self, message: TaskMessage) -> Result<TaskMessage, CoreError>;
    async fn find_messages(
        &self,
        task_id: Uuid,
        since_seq: i64,
        limit: i64,
    ) -> Result<Vec<TaskMessage>, CoreError>;
}
