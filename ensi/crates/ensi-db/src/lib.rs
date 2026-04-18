pub mod client;
pub mod error;
pub mod repo;

pub use client::{DbClient, DbConfig};
pub use error::DbError;

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn test_config(data_path: PathBuf) -> DbConfig {
        DbConfig {
            data_path,
            username: "root".to_string(),
            password: "root".to_string(),
            namespace: "ensi_test".to_string(),
            database: "ensi_test".to_string(),
        }
    }

    #[tokio::test]
    async fn test_db_connect_and_health_check() {
        let dir = tempfile::tempdir().expect("tempdir");
        let config = test_config(dir.path().to_path_buf());
        let client = DbClient::connect(config).await.expect("connect");
        client.health_check().await.expect("health check");
    }

    #[tokio::test]
    async fn test_migrations_are_recorded_once() {
        let dir = tempfile::tempdir().expect("tempdir");
        let client = DbClient::connect(test_config(dir.path().to_path_buf())).await.expect("connect");

        // Running migrations again manually on an already-migrated DB should not error
        // (IF NOT EXISTS ensures idempotency at the DDL level)
        let recorded: Vec<serde_json::Value> = client
            .db
            .query("SELECT * FROM _migration ORDER BY version ASC")
            .await
            .expect("query")
            .take(0)
            .expect("take");

        assert_eq!(recorded.len(), 1, "exactly 1 migration record should exist");
    }

    #[tokio::test]
    async fn test_schema_defines_all_12_tables() {
        let dir = tempfile::tempdir().expect("tempdir");
        let config = test_config(dir.path().to_path_buf());
        let client = DbClient::connect(config).await.expect("connect");

        let tables = [
            "workspace",
            "member",
            "agent",
            "project",
            "issue",
            "pipeline_state",
            "task",
            "task_message",
            "artifact",
            "comment",
            "pat",
            "daemon_token",
        ];

        for table in &tables {
            let result: Vec<serde_json::Value> = client
                .db
                .query(format!("INFO FOR TABLE {table}"))
                .await
                .unwrap_or_else(|e| panic!("query failed for table {table}: {e}"))
                .take(0)
                .unwrap_or_else(|e| panic!("take failed for table {table}: {e}"));

            assert!(!result.is_empty(), "table {table} should exist in schema");
        }
    }
}
