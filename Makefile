.PHONY: help
help:
	@echo 'There is no default target. Try these targets:'
	@echo '  make build  – build ui and server'
	@echo '  make server – build ui and run the server locally'
	@echo '  make deploy – build all and deploy on shuttle'
	@echo '  make clean'


ELM_SRC := $(shell find ui/src -type f -name '*.elm')


.PHONY: build
build: build_ui build_server


.PHONY: build_ui
build_ui: ui/dist/index.html


.PHONY: build_server
build_server:
	cargo build


.PHONY: clean
clean:
	rm -rf ui/dist
	cargo clean


.PHONY: server
server:
	./start_dev_server.sh


.PHONY: deploy
deploy: build
	cargo shuttle deploy


ui/dist/index.html: $(ELM_SRC)
	cd ui && elm-land make
