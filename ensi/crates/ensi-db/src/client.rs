use std::path::PathBuf;

use surrealdb::Surreal;
use surrealdb::engine::local::{Db, SurrealKv};
use surrealdb::opt::Config;
use surrealdb::opt::auth::Root;
use tracing::{info, error};

use crate::error::DbError;


#[derive(Debug, Clone)]
pub struct DbConfig {
    pub data_path: PathBuf,
    pub username: String,
    pub password: String,
    pub namespace: String,
    pub database: String,
}

impl DbConfig {
    pub fn from_env() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        let data_path = std::env::var("ENSI_DATA_PATH")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from(&home).join("ensi_data"));

        Self {
            data_path,
            username: std::env::var("ENSI_DB_USER").unwrap_or_else(|_| "root".to_string()),
            password: std::env::var("ENSI_DB_PASS").unwrap_or_else(|_| "root".to_string()),
            namespace: "ensi".to_string(),
            database: "ensi".to_string(),
        }
    }
}

#[derive(Clone)]
pub struct DbClient {
    pub db: Surreal<Db>,
}

impl DbClient {
    pub async fn connect(config: DbConfig) -> Result<Self, DbError> {
        std::fs::create_dir_all(&config.data_path).map_err(|e| {
            DbError::Migration(format!("failed to create data dir: {e}"))
        })?;

        let root = Root {
            username: config.username.clone(),
            password: config.password.clone(),
        };

        let surreal_config = Config::new().user(root.clone());

        let db = Surreal::new::<SurrealKv>((config.data_path.as_path(), surreal_config))
            .await?;

        db.signin(root).await?;
        db.use_ns(&config.namespace).use_db(&config.database).await?;

        info!(
            data_path = %config.data_path.display(),
            "SurrealDB embedded started"
        );

        let client = Self { db };
        client.run_migrations().await?;
        client.health_check().await?;

        Ok(client)
    }

    pub async fn health_check(&self) -> Result<(), DbError> {
        self.db.health().await.map_err(|e| {
            error!(error = %e, "SurrealDB health check failed");
            DbError::Surreal(e)
        })?;
        info!("SurrealDB health check passed");
        Ok(())
    }

    async fn run_migrations(&self) -> Result<(), DbError> {
        self.db
            .query(MIGRATION_TABLE_DDL)
            .await?
            .check()
            .map_err(|e| DbError::Migration(format!("failed to create migration table: {e}")))?;

        for &(version, name, sql) in MIGRATIONS {
            let applied: Vec<serde_json::Value> = self
                .db
                .query("SELECT * FROM _migration WHERE version = $v LIMIT 1")
                .bind(("v", version))
                .await?
                .take(0)
                .map_err(|e| DbError::Migration(e.to_string()))?;

            if applied.is_empty() {
                info!(version, name, "applying migration");
                self.db
                    .query(sql)
                    .await?
                    .check()
                    .map_err(|e| DbError::Migration(format!("migration {version} failed: {e}")))?;

                self.db
                    .query("CREATE _migration SET version = $v, name = $n, applied_at = time::now()")
                    .bind(("v", version))
                    .bind(("n", name))
                    .await?
                    .check()
                    .map_err(|e| DbError::Migration(format!("recording migration {version}: {e}")))?;

                info!(version, name, "migration applied");
            }
        }

        Ok(())
    }
}

const MIGRATION_TABLE_DDL: &str = r#"
DEFINE TABLE IF NOT EXISTS _migration SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS version    ON _migration TYPE int;
DEFINE FIELD IF NOT EXISTS name       ON _migration TYPE string;
DEFINE FIELD IF NOT EXISTS applied_at ON _migration TYPE datetime DEFAULT time::now();
DEFINE INDEX IF NOT EXISTS idx_migration_version ON _migration COLUMNS version UNIQUE;
"#;

const MIGRATIONS: &[(i32, &str, &str)] = &[
    (1, "initial_schema", include_str!("migrations/V001__initial_schema.surql")),
];
