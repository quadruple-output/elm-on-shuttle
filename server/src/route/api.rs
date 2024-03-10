use ::axum::{routing::get, Router};
use axum::routing::any;

pub(crate) fn router() -> Router<()> {
    Router::new()
        .route("/greet", get(greet))
        .route("/*_", any(super::no_route))
        .route("/", any(super::no_route))
}

async fn greet() -> &'static str {
    "Hello from the server"
}
