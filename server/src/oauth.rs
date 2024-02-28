use ::axum::extract::Query;
use ::axum::{routing::get, Router};
use ::serde::Deserialize;

pub(crate) fn router() -> Router<()> {
    Router::new().route("/callback/github", get(github_callback))
}

#[derive(Debug, Deserialize)]
struct CallbackParams {
    code: String,
    state: Option<String>,
}

async fn github_callback(params: Query<CallbackParams>) -> String {
    format!("{params:?}")
}
