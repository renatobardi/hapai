use thiserror::Error;
use uuid::Uuid;

#[derive(Debug, Error)]
pub enum CoreError {
    #[error("not found: {entity} with id {id}")]
    NotFound { entity: &'static str, id: Uuid },

    #[error("conflict: {0}")]
    Conflict(String),

    #[error("validation error: {0}")]
    Validation(String),

    #[error("unauthorized")]
    Unauthorized,

    #[error("forbidden")]
    Forbidden,

    #[error("infrastructure error: {0}")]
    Infrastructure(String),

    #[error("executor error: {0}")]
    Executor(String),

    #[error("max retries exceeded")]
    MaxRetriesExceeded,

    #[error("event publish error: {0}")]
    EventPublish(String),

    #[error("artifact validation error: {0}")]
    ArtifactValidation(String),
}
