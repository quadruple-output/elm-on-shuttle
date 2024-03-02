.PHONY: help
help:
	@echo 'There is no default target. Try these targets:'
	@echo '  make build  – build ui and server'
	@echo '  make run    – build ui and run the server locally'
	@echo '  make deploy – build all and deploy on shuttle'
	@echo '  make clean'

.PHONY: build
build: build_ui build_server

.PHONY: build_ui
build_ui:
	cd ui && elm-land build

.PHONY: build_server
build_server:
	cargo build

.PHONY: clean
clean:
	rm -rf ui/dist
	cargo clean

.PHONY: run
run: build
	# `open` may only work on a Mac. The opened browser will not be able to connect to the locally
	# running server, until the `cargo shuttle run` command below has finished initializing.
	# The host name `localhost.home.ig` requires an entry in `/etc/hosts` to point to 127.0.0.1
	open http://localhost.home.ig:8000/
	cargo shuttle run

.PHONY: deploy
deploy: build
	cargo shuttle deploy
