#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/Shilling/Shilling.xcodeproj}"
SCHEME="${SCHEME:-Shilling}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-platform=macOS}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/shilling-deriveddata}"
CLONED_SOURCE_PACKAGES_DIR_PATH="${CLONED_SOURCE_PACKAGES_DIR_PATH:-/tmp/shilling-source-packages}"
ARCHIVE_PATH="${ARCHIVE_PATH:-/tmp/Shilling.xcarchive}"
INSTALL_LOCAL="${INSTALL_LOCAL:-0}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
OPEN_AFTER_INSTALL="${OPEN_AFTER_INSTALL:-0}"

echo "Archiving scheme '$SCHEME' with configuration '$CONFIGURATION'..."
echo "Project: $PROJECT_PATH"
echo "Archive output: $ARCHIVE_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR_PATH" \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -archivePath "$ARCHIVE_PATH" \
  archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: expected app bundle at '$APP_PATH', but it was not found." >&2
  exit 1
fi

echo "Archive complete."
echo "App bundle: $APP_PATH"

if [[ "$INSTALL_LOCAL" == "1" ]]; then
  DEST_APP_PATH="$INSTALL_DIR/$SCHEME.app"
  mkdir -p "$INSTALL_DIR"
  ditto "$APP_PATH" "$DEST_APP_PATH"
  echo "Installed app: $DEST_APP_PATH"

  if [[ "$OPEN_AFTER_INSTALL" == "1" ]]; then
    open "$DEST_APP_PATH"
  fi
fi
