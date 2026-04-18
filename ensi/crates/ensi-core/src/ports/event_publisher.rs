use async_trait::async_trait;
use serde::Serialize;

use crate::CoreError;

#[async_trait]
pub trait EventPublisher: Send + Sync {
    async fn publish<E: Serialize + Send + Sync>(&self, subject: &str, event: &E) -> Result<(), CoreError>;
}
