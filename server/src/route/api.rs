use ::axum::{routing::get, Router};

pub(crate) fn router() -> Router<()> {
    Router::new().route("/greet", get(greet))
}

async fn greet() -> &'static str {
    "Hello from the server"
}
