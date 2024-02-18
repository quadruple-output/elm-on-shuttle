use axum::routing::get;
use axum::Router;
use tower_http::services::{ServeDir, ServeFile};

#[shuttle_runtime::main]
async fn axum() -> shuttle_axum::ShuttleAxum {
    let api_router = Router::new().route("/greet", get(greet));
    let router = Router::new().nest("/api", api_router).nest_service(
        "/",
        ServeDir::new("ui/dist").not_found_service(ServeFile::new("ui/dist/index.html")),
    );

    Ok(router.into())
}

async fn greet() -> &'static str {
    "Hello from the server"
}
