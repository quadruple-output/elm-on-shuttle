use ::axum::Router;
use ::axum::{extract::MatchedPath, http};
use ::tower_http::trace::TraceLayer;
use ::tracing::info_span;
use ::tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

pub(crate) fn init() {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                // axum logs rejections from built-in extractors with the `axum::rejection`
                // target, at `TRACE` level. `axum::rejection=trace` enables showing those events
                "server=debug,tower_http=debug,axum::rejection=trace".into()
            }),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();
}

pub(crate) fn wrap_router(router: Router) -> Router {
    //----------------------------------------
    // The below code is copied and adapted from
    // https://github.com/tokio-rs/axum/blob/main/examples/tracing-aka-logging/src/main.rs
    //----------------------------------------

    // `TraceLayer` is provided by tower-http so you have to add that as a dependency.
    // It provides good defaults but is also very customizable.
    //
    // See https://docs.rs/tower-http/0.1.1/tower_http/trace/index.html for more details.
    //
    // If you want to customize the behavior using closures here is how.
    router.layer(
        TraceLayer::new_for_http().make_span_with(|request: &http::Request<_>| {
            // Log the matched route's path (with placeholders not filled in).
            // Use request.uri() or OriginalUri if you want the real path.
            let path = request.uri().path();
            let matched_path = request
                .extensions()
                .get::<MatchedPath>()
                .map(MatchedPath::as_str)
                .filter(|&matched_path| matched_path != path);
            info_span!(
                "http_request",
                method = ?request.method(),
                matched_path,
                path,
                some_other_field = tracing::field::Empty,
            )
        }),
        // use std::time::Duration;
        // use tower_http::classify::ServerErrorsFailureClass;
        // use tracing::Span;
        // .on_request(|_request: &Request<_>, _span: &Span| {
        //     // You can use `_span.record("some_other_field", value)` in one of these
        //     // closures to attach a value to the initially empty field in the info_span
        //     // created above.
        // })
        // .on_response(
        //     |_response: &http::Response, _latency: Duration, _span: &Span| {
        //         // ...
        //     },
        // )
        // .on_body_chunk(|_chunk: &Bytes, _latency: Duration, _span: &Span| {
        //     // ...
        // })
        // .on_eos(
        //     |_trailers: Option<&HeaderMap>, _stream_duration: Duration, _span: &Span| {
        //         // ...
        //     },
        // )
        // .on_failure(
        //     |_error: ServerErrorsFailureClass, _latency: Duration, _span: &Span| {
        //         // ...
        //     },
        // ),
    )
}
