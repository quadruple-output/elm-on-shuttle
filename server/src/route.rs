use ::axum::{extract::OriginalUri, http::StatusCode};

pub(crate) mod api;
pub(crate) mod oauth;
pub(crate) mod spa;

pub(crate) async fn no_route(OriginalUri(uri): OriginalUri) -> (StatusCode, String) {
    (StatusCode::NOT_FOUND, format!("No route for {uri}"))
}
