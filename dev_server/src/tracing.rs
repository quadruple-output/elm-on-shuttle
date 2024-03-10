use ::tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use axum::Router;
use tower_http::trace::TraceLayer;

pub(crate) fn init() {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                // axum logs rejections from built-in extractors with the `axum::rejection`
                // target, at `TRACE` level. `axum::rejection=trace` enables showing those events
                "dev_server=info,tower_http=trace,axum::rejection=trace".into()
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
    router.layer(TraceLayer::new_for_http())
}
