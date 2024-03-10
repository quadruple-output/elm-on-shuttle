//! This is a simple development server that listens on a local port and forwards all traffic
//! to other ports, depending on the request path.
#![allow(clippy::needless_return)]

use ::axum::extract::OriginalUri;
use ::axum::http::uri;
use ::axum::http::uri::Authority;
use ::axum::response::IntoResponse;
use ::axum::response::Redirect;
use ::axum::routing::get;
use ::axum::routing::post;
use ::axum::Router;
use ::lazy_static::lazy_static;
use ::std::net::IpAddr;
use ::std::net::Ipv4Addr;
use ::std::net::SocketAddr;
use ::tokio::net::TcpListener;
use ::tracing::info;

mod tracing;

const BIND_ADDR: SocketAddr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 8080);
const RUST_SERVER_ADDR: SocketAddr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 8000);
const ELM_SERVER_ADDR: SocketAddr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 1234);

lazy_static! {
    static ref RUST_AUTHORITY: Authority =
        Authority::try_from(RUST_SERVER_ADDR.to_string()).unwrap();
    static ref ELM_AUTHORITY: Authority = Authority::try_from(ELM_SERVER_ADDR.to_string()).unwrap();
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing::init();

    let router = Router::new()
        .route("/api/*_", get(forward_to_rust))
        .route("/api/*_", post(forward_to_rust))
        .route("/oauth/*_", get(forward_to_rust))
        .route("/oauth/*_", post(forward_to_rust))
        .route("/*_", get(forward_to_elm))
        .route("/*_", post(forward_to_elm))
        .route("/", get(forward_to_elm))
        .route("/", post(forward_to_elm));
    let listener = TcpListener::bind(BIND_ADDR).await?;
    let router = tracing::wrap_router(router);
    Ok(axum::serve(listener, router.into_make_service()).await?)
}

async fn forward_to(
    OriginalUri(original_uri): OriginalUri,
    new_authority: &Authority,
) -> impl IntoResponse {
    let mut parts = original_uri.clone().into_parts();
    parts.scheme = Some("http".parse().unwrap());
    parts.authority = Some(new_authority.clone());
    let new_uri = uri::Uri::from_parts(parts).unwrap();
    info!("Forwarding {original_uri} to {new_uri}");
    Redirect::temporary(&new_uri.to_string())
}

async fn forward_to_rust(original_uri: OriginalUri) -> impl IntoResponse {
    forward_to(original_uri, &RUST_AUTHORITY).await
}

async fn forward_to_elm(original_uri: OriginalUri) -> impl IntoResponse {
    forward_to(original_uri, &ELM_AUTHORITY).await
}
