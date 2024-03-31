# Elm on Shuttle

Playground repository for learning how to deploy an [elm](https://elm-lang.org) app on
[shuttle](https://shuttle.rs).

This README shall be updated according to the progress of the project.


## Backend

The backend service is written in [rust](https://rust-lang.org) and hosted on
[`shuttle.rs`](https://shuttle.rs). The backend implements

1. A static file server, whose sole purpose is to serve the files for the single-page front-end app;
2. A REST API, for the front-end app, currently just sending a hello message.
3. An OAuth authentication callback end-point, to perform the second step of an OAuth2
   authentication flow with GitHub.


## UI

The browser front-end is a single-page app (SPA), written in [elm](https://elm-lang.org), with the
[`elm.land`](https://elm.land) framework. It communicates with the backend REST API. It also uses an
OAuth flow to authenticate with GitHub, with the help of a GitHub App installed in my GitHub
account.

For now, the UI is in a particularly ugly state, but it works as desired.
