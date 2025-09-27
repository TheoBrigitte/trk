# This Makefile provides targets for building, linting and testing.

# Variables
PROJECT_NAME := trk
BUILD_DIR := build

# Build informations
VERSION := $(shell git describe --always --long --dirty || date)

# Default target
.DEFAULT_GOAL := build

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

##@ Building
.PHONY: build
build: TMPDIR := $(shell mktemp -d -t $(PROJECT_NAME).XXXXXX)
build: ## Package the application
	mkdir -p $(BUILD_DIR)
	cp -r bin lib $(TMPDIR)/
	sed -i 's/^VERSION=.*/VERSION="$(VERSION)"/' $(TMPDIR)/bin/$(PROJECT_NAME)
	tar --create --gzip --file $(BUILD_DIR)/$(PROJECT_NAME).tar.gz -C $(TMPDIR) bin lib
	rm -rf $(TMPDIR)

.PHONY: install
install: build ## Install the application to ~/.local
	@printf "$(CYAN)Installing application to ~/.local ...$(RESET)\n"
	mkdir -p ~/.local
	tar --extract --gzip --file $(BUILD_DIR)/$(PROJECT_NAME).tar.gz -C ~/.local
	@printf "$(GREEN)Installed application to ~/.local$(RESET)\n"

.PHONY: clean
clean: ## Clean build artifacts and Docker images
	@printf "$(CYAN)Cleaning build artifacts...$(RESET)\n"
	rm -rf $(BUILD_DIR)
	@printf "$(GREEN)Cleanup completed$(RESET)\n"

##@ Code Quality

.PHONY: shellcheck
shellcheck:
	@printf "$(CYAN)Running shellcheck...$(RESET)\n"
	shellcheck bin/* lib/*

.PHONY: lint
lint: shellcheck ## Run all code quality checks

##@ Help

.PHONY: help
help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(CYAN)Usage:$(RESET)\n  make $(YELLOW)<target>$(RESET)\n"} /^[a-zA-Z_0-9-]+.*?##/ { printf "  $(YELLOW)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(CYAN)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@printf "\n"
	@printf "$(CYAN)Examples:$(RESET)\n"
	@printf "  make install                        # Install to ~/.local/bin\n"
	@printf "  make build                          # Build the binary\n"
	@printf "  make lint                           # Run all code quality checks\n"
	@printf "  make clean                          # Clean all artifacts\n"
