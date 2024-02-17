use axum::Router;
use tower_http::services::{ServeDir, ServeFile};

#[shuttle_runtime::main]
async fn axum() -> shuttle_axum::ShuttleAxum {
    let router = Router::new().nest_service(
        "/",
        ServeDir::new("ui/dist").not_found_service(ServeFile::new("ui/dist/index.html")),
    );

    Ok(router.into())
}
