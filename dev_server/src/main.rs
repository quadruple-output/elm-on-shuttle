//! This is a simple development server that listens on a local port and forwards all traffic
//! to other ports, depending on the request path.
#![allow(clippy::needless_return)]

use ::axum::body::Body as AxumBody;
use ::axum::extract;
use ::axum::extract::FromRequestParts;
use ::axum::extract::State;
use ::axum::extract::WebSocketUpgrade;
use ::axum::http;
use ::axum::http::uri::Authority;
use ::axum::http::uri::Scheme;
use ::axum::http::Uri;
use ::axum::response::IntoResponse;
use ::axum::response::Response as AxumResponse;
use ::axum::routing::get;
use ::axum::routing::post;
use ::axum::Router;
use ::futures_util::Sink;
use ::futures_util::SinkExt;
use ::futures_util::StreamExt;
use ::hyper_util::client::legacy::connect::HttpConnector;
use ::hyper_util::rt::TokioExecutor;
use ::lazy_static::lazy_static;
use ::std::net::IpAddr;
use ::std::net::Ipv4Addr;
use ::std::net::SocketAddr;
use ::std::str::FromStr;
use ::std::time::Duration;
use ::tokio::net::TcpListener;
use ::tokio::net::TcpStream;
use ::tokio_tungstenite::MaybeTlsStream;
use ::tracing::error;
use ::tracing::info;
use tokio_tungstenite::tungstenite;

mod tracing;

const BIND_ADDR: SocketAddr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 8080);
const RUST_SERVER_ADDR: SocketAddr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 8000);
const ELM_SERVER_ADDR: SocketAddr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 1234);

lazy_static! {
    static ref RUST_AUTHORITY: Authority =
        Authority::try_from(RUST_SERVER_ADDR.to_string()).unwrap();
    static ref ELM_AUTHORITY: Authority = Authority::try_from(ELM_SERVER_ADDR.to_string()).unwrap();
}

type Client = hyper_util::client::legacy::Client<HttpConnector, AxumBody>;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing::init();

    let client: Client =
        hyper_util::client::legacy::Client::<(), ()>::builder(TokioExecutor::new())
            .build(HttpConnector::new());

    let router = Router::new()
        .route("/api/*_", get(proxy_to_rust))
        .route("/api/*_", post(proxy_to_rust))
        .route("/oauth/*_", get(proxy_to_rust))
        .route("/oauth/*_", post(proxy_to_rust))
        .route("/*_", get(proxy_to_elm))
        .route("/", get(proxy_to_elm))
        .with_state(client);

    let listener = TcpListener::bind(BIND_ADDR).await?;
    info!("listening on {}", listener.local_addr().unwrap());
    let router = tracing::wrap_router(router);
    Ok(axum::serve(listener, router.into_make_service()).await?)
}

async fn proxy_to_elm(State(client): State<Client>, req: extract::Request) -> AxumResponse {
    proxy_to(&ELM_AUTHORITY, req, client).await
}

async fn proxy_to_rust(State(client): State<Client>, req: extract::Request) -> AxumResponse {
    proxy_to(&RUST_AUTHORITY, req, client).await
}

async fn proxy_to(
    new_authority: &Authority,
    req: extract::Request,
    client: Client,
) -> AxumResponse {
    let original_uri = req.uri().clone(); // cloning avoids borrowing of req
    let new_uri = replace_authority(&original_uri, new_authority);

    // Attempt to upgrade to WebSocket
    let (mut parts, body) = req.into_parts();
    if let Ok(ws_upgrade) = WebSocketUpgrade::from_request_parts(&mut parts, &()).await {
        info!("Attempting to upgrade WebSocket connection");
        let new_uri = replace_scheme(&new_uri, "ws");
        ws_upgrade
            .on_failed_upgrade(|err| {
                error!("Error upgrading WebSocket: {err}");
            })
            .on_upgrade(|upstream_ws| async move {
                info!("Connection upgraded, now connecting to {new_uri}");
                // Reconstruct the request with the new URI. Note that upgrading is only supported
                // for GET requests, so we don't need the body.
                let mut req = extract::Request::from_parts(parts, ());
                *req.uri_mut() = new_uri.clone();
                match tokio::time::timeout(
                    Duration::from_millis(1000),
                    tokio_tungstenite::connect_async(req),
                )
                .await
                {
                    Ok(no_timeout) => match no_timeout {
                        Ok((downstream_ws, ws_connect_response)) => {
                            info!("Upgraded WebSocket connection");
                            let status = ws_connect_response.status();
                            info!("(status: {status})");
                            connect_websockets(upstream_ws, downstream_ws).await;
                        }
                        Err(err) => error!("Error connecting to {new_uri}: {err}"),
                    },
                    Err(err) => error!("Error connecting to {new_uri}: {err}"),
                }
            })
    } else {
        // Forward the request
        let mut req = extract::Request::from_parts(parts, body);
        // This code is an adaptation of
        // https://github.com/tokio-rs/axum/blob/b02ce307371a973039018a13fa012af14775948c/examples/reverse-proxy/src/main.rs
        info!("Fwd to {new_authority}: {original_uri}");
        *req.uri_mut() = new_uri.clone();
        client
            .request(req)
            .await
            .map(IntoResponse::into_response)
            .unwrap_or_else(|err| {
                error!("Error forwarding {original_uri}: {err}");
                (http::StatusCode::BAD_GATEWAY, format!("{err}")).into_response()
            })
    }
}

fn replace_authority(uri: &Uri, new_authority: &Authority) -> http::Uri {
    let mut parts = uri.clone().into_parts();
    parts.scheme = Some(Scheme::HTTP); // we don't need https for localhost
    parts.authority = Some(new_authority.clone());
    http::Uri::from_parts(parts).unwrap() // cannot fail because we've set all parts
}

fn replace_scheme(uri: &Uri, new_scheme: &str) -> http::Uri {
    let mut parts = uri.clone().into_parts();
    parts.scheme = Scheme::from_str(new_scheme).ok(); // this is no proper error handling, but we
                                                      // know that the scheme is valid
    http::Uri::from_parts(parts).unwrap() // cannot fail because we've set all parts
}

async fn connect_websockets(
    client: axum::extract::ws::WebSocket,
    server: tokio_tungstenite::WebSocketStream<MaybeTlsStream<TcpStream>>,
) {
    enum ConnectionCtrl {
        KeepOpen,
        Close,
    }

    let mut server = server.fuse();
    let mut client = client.fuse();
    loop {
        if let ConnectionCtrl::Close = tokio::select! {
            maybe_next = server.next() => try_forward("server", maybe_next, &mut client).await,
            maybe_next = client.next() => try_forward("client", maybe_next, &mut server).await,
        } {
            break;
        }
    }
    info!("Closing WebSocket connection");

    async fn try_forward<S, Msg1, Msg2, E>(
        source_name: &str,
        maybe_msg: Option<Result<Msg1, E>>,
        target: &mut S,
    ) -> ConnectionCtrl
    where
        S: SinkExt<Msg2> + std::marker::Unpin,
        <S as Sink<Msg2>>::Error: std::fmt::Display,
        Msg1: IntoOtherMessage<Other = Msg2> + std::fmt::Debug,
        E: std::fmt::Display,
    {
        let mut connection_ctrl = ConnectionCtrl::Close;
        if let Some(msg_result) = maybe_msg {
            match msg_result {
                Ok(msg) => {
                    info!("WebSocket message from {source_name}: {msg:?}");
                    if let Err(err) = target.send(msg.into_other()).await {
                        error!("Error forwarding WebSocket message: {err}");
                    } else {
                        connection_ctrl = ConnectionCtrl::KeepOpen;
                    }
                }
                Err(err) => error!("Error receiving WebSocket message from {source_name}: {err}"),
            }
        } else {
            info!("WebSocket closed by {source_name}")
        };
        connection_ctrl
    }
}

trait IntoOtherMessage {
    type Other;

    fn into_other(self) -> Self::Other;
}

impl IntoOtherMessage for tungstenite::Message {
    type Other = axum::extract::ws::Message;

    fn into_other(self) -> Self::Other {
        type SelfMessage = tungstenite::Message;
        type OtherMessage = axum::extract::ws::Message;
        match self {
            SelfMessage::Text(text) => OtherMessage::Text(text),
            SelfMessage::Binary(bin) => OtherMessage::Binary(bin),
            SelfMessage::Ping(uvec) => OtherMessage::Ping(uvec),
            SelfMessage::Pong(uvec) => OtherMessage::Pong(uvec),
            SelfMessage::Close(Some(close)) => {
                OtherMessage::Close(Some(axum::extract::ws::CloseFrame {
                    code: close.code.into(),
                    reason: close.reason,
                }))
            }
            SelfMessage::Close(None) => OtherMessage::Close(None),
            SelfMessage::Frame(_) => panic!("got unexpected raw frame"),
        }
    }
}

impl IntoOtherMessage for axum::extract::ws::Message {
    type Other = tungstenite::Message;

    fn into_other(self) -> Self::Other {
        type SelfMessage = axum::extract::ws::Message;
        type OtherMessage = tungstenite::Message;
        match self {
            SelfMessage::Text(text) => OtherMessage::Text(text),
            SelfMessage::Binary(bin) => OtherMessage::Binary(bin),
            SelfMessage::Ping(uvec) => OtherMessage::Ping(uvec),
            SelfMessage::Pong(uvec) => OtherMessage::Pong(uvec),
            SelfMessage::Close(Some(close)) => {
                OtherMessage::Close(Some(tungstenite::protocol::CloseFrame {
                    code: close.code.into(),
                    reason: close.reason,
                }))
            }
            SelfMessage::Close(None) => OtherMessage::Close(None),
        }
    }
}
