use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgPoolOptions;
use sqlx::{PgPool, Row};
use std::env;

// Request/Response types
#[derive(Deserialize)]
struct CalcRequest {
    a: i32,
    b: i32,
}

#[derive(Serialize)]
struct CalcResponse {
    result: f64,
}

#[derive(Serialize)]
struct HealthResponse {
    status: String,
}

#[derive(Serialize)]
struct UserResponse {
    id: i32,
    name: String,
    email: String,
    created_at: String,
}

// App state
#[derive(Clone)]
struct AppState {
    db: PgPool,
}

// Handlers
async fn calculate(Json(payload): Json<CalcRequest>) -> Json<CalcResponse> {
    let result = ((payload.a.pow(2) + payload.b.pow(2)) as f64).sqrt();
    Json(CalcResponse { result })
}

async fn get_user(
    State(state): State<AppState>,
    Path(user_id): Path<i32>,
) -> Result<Json<UserResponse>, (StatusCode, String)> {
    let row = sqlx::query("SELECT id, name, email, created_at FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_one(&state.db)
        .await
        .map_err(|e| {
            if matches!(e, sqlx::Error::RowNotFound) {
                (StatusCode::NOT_FOUND, "User not found".to_string())
            } else {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Database error".to_string(),
                )
            }
        })?;

    Ok(Json(UserResponse {
        id: row.get("id"),
        name: row.get("name"),
        email: row.get("email"),
        created_at: row
            .get::<chrono::NaiveDateTime, _>("created_at")
            .to_string(),
    }))
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok".to_string(),
    })
}

#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    // Database configuration
    let db_host = env::var("DB_HOST").unwrap_or_else(|_| "postgres".to_string());
    let db_port = env::var("DB_PORT").unwrap_or_else(|_| "5432".to_string());
    let db_user = env::var("DB_USER").unwrap_or_else(|_| "benchmark".to_string());
    let db_password = env::var("DB_PASSWORD").unwrap_or_else(|_| "benchmark123".to_string());
    let db_name = env::var("DB_NAME").unwrap_or_else(|_| "benchmark".to_string());

    let database_url = format!(
        "postgres://{}:{}@{}:{}/{}",
        db_user, db_password, db_host, db_port, db_name
    );

    // Create connection pool
    let pool = PgPoolOptions::new()
        .max_connections(20)
        .min_connections(10)
        .connect(&database_url)
        .await
        .expect("Failed to create pool");

    tracing::info!("Database connected");

    let app_state = AppState { db: pool };

    // Build router
    let app = Router::new()
        .route("/calculate", post(calculate))
        .route("/user/:id", get(get_user))
        .route("/health", get(health))
        .with_state(app_state);

    // Start server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8000").await.unwrap();

    tracing::info!(
        "Rust Axum API running on {}",
        listener.local_addr().unwrap()
    );

    axum::serve(listener, app).await.unwrap();
}
