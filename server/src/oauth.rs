use ::axum::extract::Query;
use ::axum::{routing::get, Router};
use ::serde::Deserialize;
use ::tracing::debug;

pub(crate) fn router() -> Router<()> {
    Router::new().route("/callback/github", get(github_callback))
}

#[derive(Debug, Deserialize)]
struct CallbackParams {
    code: String,
    state: Option<String>,
}

async fn github_callback(params: Query<CallbackParams>) -> String {
    let info = match params.0 {
        CallbackParams{code, state:Some(state)} => 
            format!("code: {code}, state: {state}"),
        CallbackParams{code, state:None} =>
            format!("code: {code}, no state"),
    };
    debug!("{info}");
    info.to_string()
}
