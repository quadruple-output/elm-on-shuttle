use ::anyhow::{anyhow, Result};
use ::shuttle_secrets::SecretStore as ShuttleSecretStore;

const SECRET_KEY_GITHUB_APP_CLIENT_SECRET: &str = "GITHUB_APP_CLIENT_SECRET";

pub(crate) fn try_from(store: ShuttleSecretStore) -> Result<Secrets> {
    Ok(Secrets {
        github_app_client_secret: try_get_secret(&store, SECRET_KEY_GITHUB_APP_CLIENT_SECRET)?,
    })
}

pub(crate) struct Secrets {
    pub github_app_client_secret: String,
}

fn try_get_secret(store: &ShuttleSecretStore, key: &str) -> Result<String> {
    if let Some(secret) = store.get(key) {
        Ok(secret)
    } else {
        Err(anyhow!("Secret {key} is not configured in secret store"))
    }
}
