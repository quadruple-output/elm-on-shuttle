use ::axum::Router;
use ::shuttle_axum::ShuttleAxum;
use ::shuttle_secrets::{SecretStore as ShuttleSecretStore, Secrets as ShuttleSecrets};

use self::route::{api, oauth, spa};

mod route;
mod secrets;
mod tracing;

#[shuttle_runtime::main]
async fn main(#[ShuttleSecrets] secret_store: ShuttleSecretStore) -> ShuttleAxum {
    tracing::init();
    let secrets = secrets::try_from(secret_store)?;

    let router = Router::new()
        .nest("/api", api::router())
        .nest("/oauth", oauth::router(secrets.github_app_client_secret))
        .nest_service("/", spa::serve_dir(["ui", "dist"].iter().collect()));

    Ok(tracing::wrap_router(router).into())
}
