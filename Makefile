SHELL := /bin/bash

PROJECT_PATH ?= /Users/andrew/code/shilling/Shilling/Shilling.xcodeproj
SCHEME ?= Shilling
CONFIGURATION ?= Release
DESTINATION ?= platform=macOS
DERIVED_DATA_PATH ?= /tmp/shilling-deriveddata
CLONED_SOURCE_PACKAGES_DIR_PATH ?= /tmp/shilling-source-packages
ARCHIVE_PATH ?= /tmp/Shilling.xcarchive
INSTALL_DIR ?= $(HOME)/Applications

BUILD_ENV = \
	PROJECT_PATH="$(PROJECT_PATH)" \
	SCHEME="$(SCHEME)" \
	CONFIGURATION="$(CONFIGURATION)" \
	DESTINATION="$(DESTINATION)" \
	DERIVED_DATA_PATH="$(DERIVED_DATA_PATH)" \
	CLONED_SOURCE_PACKAGES_DIR_PATH="$(CLONED_SOURCE_PACKAGES_DIR_PATH)" \
	ARCHIVE_PATH="$(ARCHIVE_PATH)"

.PHONY: app-release app-install app-install-open

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
