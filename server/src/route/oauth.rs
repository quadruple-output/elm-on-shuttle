use ::axum::body::Body;
use ::axum::extract::Query;
use ::axum::http::header;
use ::axum::http::StatusCode;
use ::axum::response::{IntoResponse, Response};
use ::axum::routing::any;
use ::axum::routing::get;
use ::axum::Json;
use ::axum::Router;
use ::reqwest;
use ::serde::{Deserialize, Serialize};
use ::std::collections::HashMap;

const GITHUB_TOKEN_SERVICE: &str = "https://github.com/login/oauth/access_token";

pub(crate) fn router(github_app_client_secret: String) -> Router<()> {
    Router::new()
        .route(
            "/callback/github",
            get(|params| github_callback(github_app_client_secret, params)),
        )
        .route("/*_", any(super::no_route))
        .route("/", any(super::no_route))
}

#[derive(Debug, Deserialize)]
struct CallbackQueryParams {
    code: String,
    _state: Option<String>,
}

#[derive(Default, Serialize)]
struct ReceivedResponse {
    server_status: Option<String>,
    error_message: Option<String>,
    token_response: Option<GithubTokenResponse>,
}

#[derive(Serialize)]
enum GithubTokenResponse {
    Ok(GithubTokenResponseOk),
    Err(GithubTokenResponseErr),
    Unrecognized { raw: String },
}

/// The response to a token request (if successful), as returned by GitHub
#[derive(Debug, Deserialize, Serialize)]
struct GithubTokenResponseOk {
    /// The user access token. The token starts with `ghu_`.
    access_token: String,
    /// The number of seconds until access_token expires. If you disabled expiration of user access
    /// tokens, this parameter will be omitted. The value will always be `28800` (8 hours).
    #[serde(rename = "expires_in")]
    expires_in_seconds: Option<u32>,
    /// The refresh token. If you disabled expiration of user access tokens, this parameter will be
    /// omitted. The token starts with `ghr_`.
    refresh_token: Option<String>,
    /// The number of seconds until `refresh_token` expires. If you disabled expiration of user
    /// access tokens, this parameter will be omitted. The value will always be `15811200` (6
    /// months).
    #[serde(rename = "refresh_token_expires_in")]
    refresh_token_expires_in_seconds: Option<u32>,
    /// The scopes that the token has. This value will always be an empty string. Unlike a
    /// traditional OAuth token, the user access token is limited to the permissions that both your
    /// app and the user have.
    scope: String,
    /// The type of token. The value will always be `bearer`.
    token_type: String,
}

#[derive(Debug, Deserialize, Serialize)]
struct GithubTokenResponseErr {
    /// Error-ID
    error: String,
    /// One-sentence description of the error
    error_description: Option<String>,
    /// Link to further documentation on the error
    error_uri: Option<String>,
}

async fn github_callback(
    app_client_secret: String,
    query_params: Query<CallbackQueryParams>,
) -> Response {
    // Use the received code to request an access token from GitHub:
    let response = reqwest::Client::new()
        .post(GITHUB_TOKEN_SERVICE)
        .header(header::ACCEPT, mime::APPLICATION_JSON.as_ref())
        .json(&HashMap::from([
            ("client_id", "Iv1.b5ba4dcd32da9063"),
            ("client_secret", &app_client_secret),
            ("code", &query_params.code),
        ]))
        .send()
        .await;

    let out = analyze_client_response(response).await;
    if let ReceivedResponse {
        server_status: _,
        error_message: _,
        token_response: Some(GithubTokenResponse::Ok(ok_response)),
    } = out
    {
        let new_url = "/sign-in";
        // Set-Cookie spec: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
        let max_age = if let Some(expires_in_seconds) = ok_response.expires_in_seconds {
            format!(
                "Max-Age={}; ",
                // Expire earlier than necessary to reduce the risk of token expiration during use
                expires_in_seconds - 60 * 60
            )
        } else {
            "".to_string()
        };
        // Setting a cookie with `StatusCode::FOUND` does not work. We use a `REFRESH` header
        // instead.
        Response::builder()
            .status(StatusCode::OK)
            .header(
                header::SET_COOKIE,
                format!(
                    "github-access-token={access_token}; path=/; {max_age}SameSite=Strict",
                    access_token = ok_response.access_token
                ),
            )
            .header(header::REFRESH, format!("0;url={new_url}"))
            .body(Body::empty())
            .unwrap()
    } else {
        // Something went wrong. Just dump what we have.
        Json(out).into_response()
    }
}

async fn analyze_client_response(response: reqwest::Result<reqwest::Response>) -> ReceivedResponse {
    let mut out = ReceivedResponse::default();
    match response {
        Ok(response) => {
            out.server_status = Some(format!("{}", response.status()));
            match response.text().await {
                Ok(body) => out.token_response = Some(parse_token_response(body)),
                Err(e) => out.error_message = Some(format!("Error receiving response body: {e}")),
            }
        }
        Err(e) => {
            out.error_message = Some(format!("Cannot connect to {GITHUB_TOKEN_SERVICE}: {e}"))
        }
    };
    out
}

fn parse_token_response(body: String) -> GithubTokenResponse {
    match (
        serde_json::from_str::<GithubTokenResponseOk>(&body),
        serde_json::from_str::<GithubTokenResponseErr>(&body),
        body,
    ) {
        (Ok(ok_response), _, _) => GithubTokenResponse::Ok(ok_response),
        (Err(_), Ok(err_response), _) => GithubTokenResponse::Err(err_response),
        (Err(_), Err(_), body) => GithubTokenResponse::Unrecognized { raw: body },
    }
}
