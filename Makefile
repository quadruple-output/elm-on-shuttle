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
run: build_ui
	cargo shuttle run

.PHONY: deploy
deploy: build
	cargo shuttle deploy
