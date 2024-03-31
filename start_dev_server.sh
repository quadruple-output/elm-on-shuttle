#!/usr/bin/env bash
# Launches a dev-server for local development.

set -e

cd "$(dirname "$0")"

cargo build -p dev_server

pushd ui
# The `elm-land server` command, by default, listens on port 1234.
( elm-land server | awk '{print "elm: " $0}' 2>&1 ) &
elm_server_pid=$!
popd

# The `cargo shuttle run` command, by default, listens on port 8000.
( cargo shuttle run | awk '{print "rust: " $0}' 2>&1 ) &
rust_server_pid=$!

# `open` may only work on a Mac. The opened browser will not be able to connect to the locally
# running server, until the servers have finished initializing.
open http://localhost.home.ig:8080/

cargo run -p dev_server | awk '{print "dev-server: " $0}' 2>&1
kill "$rust_server_pid"
kill "$elm_server_pid"
