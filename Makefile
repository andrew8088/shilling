SHELL := /bin/bash

REPO_ROOT ?= $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_PATH ?= $(REPO_ROOT)/Shilling/Shilling.xcodeproj
SCHEME ?= Shilling
CONFIGURATION ?= Release
DESTINATION ?= platform=macOS
DERIVED_DATA_PATH ?= /tmp/shilling-deriveddata
CLONED_SOURCE_PACKAGES_DIR_PATH ?= /tmp/shilling-source-packages
ARCHIVE_PATH ?= /tmp/Shilling.xcarchive
INSTALL_DIR ?= $(HOME)/Applications
LEGACY_MIGRATION_SQLITE ?= /tmp/legacy-migration.sqlite
LEGACY_FAMILY_ID ?=

BUILD_ENV = \
	PROJECT_PATH="$(PROJECT_PATH)" \
	SCHEME="$(SCHEME)" \
	CONFIGURATION="$(CONFIGURATION)" \
	DESTINATION="$(DESTINATION)" \
	DERIVED_DATA_PATH="$(DERIVED_DATA_PATH)" \
	CLONED_SOURCE_PACKAGES_DIR_PATH="$(CLONED_SOURCE_PACKAGES_DIR_PATH)" \
	ARCHIVE_PATH="$(ARCHIVE_PATH)"

.PHONY: app-release app-install app-install-open export-legacy-migration-sqlite

app-release:
	$(BUILD_ENV) ./scripts/build-macos-app.sh

app-install:
	$(BUILD_ENV) \
	INSTALL_LOCAL=1 \
	INSTALL_DIR="$(INSTALL_DIR)" \
	./scripts/build-macos-app.sh

app-install-open:
	$(BUILD_ENV) \
	INSTALL_LOCAL=1 \
	INSTALL_DIR="$(INSTALL_DIR)" \
	OPEN_AFTER_INSTALL=1 \
	./scripts/build-macos-app.sh

export-legacy-migration-sqlite:
	@if [ -z "$(LEGACY_PG_DB)" ]; then \
		echo "LEGACY_PG_DB is required (example: make export-legacy-migration-sqlite LEGACY_PG_DB=mydb)"; \
		exit 2; \
	fi
	python3 ./scripts/export-legacy-postgres-to-migration-sqlite.py \
		--source-db "$(LEGACY_PG_DB)" \
		--output "$(LEGACY_MIGRATION_SQLITE)" \
		--overwrite \
		$(if $(LEGACY_FAMILY_ID),--family-id "$(LEGACY_FAMILY_ID)")
