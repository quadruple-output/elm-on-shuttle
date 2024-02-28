use ::axum::Router;
use ::std::path::PathBuf;
use ::tower_http::services::{ServeDir, ServeFile};

mod api;
mod oauth;
mod tracing;

#[shuttle_runtime::main]
async fn main() -> shuttle_axum::ShuttleAxum {
    tracing::init();

    let router = Router::new()
        .nest("/api", api::router())
        .nest("/oauth", oauth::router())
        .nest_service("/", static_file_service());

    Ok(tracing::wrap_router(router).into())
}

fn static_file_service() -> ServeDir<ServeFile> {
    ServeDir::new(["ui", "dist"].iter().collect::<PathBuf>())
        // The served directory contains a single page app (SPA), and 'index.html' is the only HTML
        // file to be served. However, URLs to (virtual) paths must be resolved to the same app.
        // Routing to the virtual path will be done by the JavaScript of the SPA.
        .fallback(ServeFile::new(
            ["ui", "dist", "index.html"].iter().collect::<PathBuf>(),
        ))
}
