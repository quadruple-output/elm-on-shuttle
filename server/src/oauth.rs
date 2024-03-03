use ::axum::{extract::Query, routing::get, Router};
use ::reqwest;
use ::serde::{Deserialize, Serialize};
use ::std::collections::HashMap;
use ::tracing::debug;
use axum::Json;

pub(crate) fn router() -> Router<()> {
    Router::new().route("/callback/github", get(github_callback))
}

#[derive(Debug, Deserialize)]
struct CallbackParams {
    code: String,
    state: Option<String>,
}

#[derive(Default, Serialize)]
struct TokenResponse {
    server_status: Option<String>,
    error_message: Option<String>,
    raw_body: Option<String>,
}

async fn github_callback(params: Query<CallbackParams>) -> Json<TokenResponse> {
    let CallbackParams { code, state } = params.0;
    let info = match (&*code, state) {
        (code, Some(state)) => format!("code: {code}, state: {state}"),
        (code, None) => format!("code: {code}, no state"),
    };
    debug!("{info}");

    let mut map = HashMap::new();
    map.insert("client_id", "Iv1.b5ba4dcd32da9063".to_string());
    map.insert(
        "client_secret",
        "".to_string(), // !!!!!!!!!!!!!!!!!!!!!!! TODO
    );
    map.insert("code", code.to_string());
    map.insert("redirect_uri", "".to_string());

    let client = reqwest::Client::new();
    let response = client
        .post("https://github.com/login/oauth/access_token")
        .header(reqwest::header::ACCEPT, "application/json")
        .json(&map)
        .send()
        .await;

    let mut out = TokenResponse::default();
    match response {
        Ok(response) => {
            let status = response.status();
            let status_reason = status.canonical_reason().unwrap_or("<unknown>");
            out.server_status = Some(format!("{status}: {status_reason}"));
            let body = response.text().await;
            match body {
                Ok(body) => out.raw_body = Some(body),
                Err(e) => out.error_message = Some(format!("Error receiving response body: {e}")),
            }
        }
        Err(e) => out.error_message = Some(format!("Error connecting to token service: {e}")),
    }
    Json(out)
}
