use thiserror::Error;

#[derive(Debug, Error)]
pub enum DbError {
    #[error("surrealdb error: {0}")]
    Surreal(#[from] surrealdb::Error),

    #[error("migration error: {0}")]
    Migration(String),

    #[error("serialization error: {0}")]
    Serialization(String),
}
