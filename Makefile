# Baby Purr Pal (Godot 4.7.2) — quick launch. `make` or `make help` lists targets.
.DEFAULT_GOAL := help
GODOT ?= godot
APK := build/BabyPurrPal.apk

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

run: ## Run the game in the Godot window
	$(GODOT) --path .

import: ## Import assets and parse all scripts
	$(GODOT) --headless --path . --import

test: ## Run headless logic tests
	$(GODOT) --headless --path . -s tests/run_tests.gd

apk: ## Export a debug APK to build/
	@mkdir -p build
	$(GODOT) --headless --path . --export-debug "Android" $(APK)

install: ## Install build/BabyPurrPal.apk on the connected device
	adb install -r $(APK)

.PHONY: help run import test apk install
