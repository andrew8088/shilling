# Shilling — Project Overview

A self-hostable personal budgeting and expense tracking application for macOS.

## Goals

- Native macOS app (SwiftUI) for day-to-day use
- CLI tool for scripting, automation, and power users
- Shared core library (`ShillingCore`) consumed by both
- Double-entry bookkeeping with opening balances
- Monthly budget targets for spending categories
- Mortgage tracking (payment splits: principal vs interest)
- CSV import for bank statements
- Single-currency, single-household (no authentication)

## Stack

- **Language**: Swift (macOS 14+)
- **UI**: SwiftUI
- **Persistence**: SwiftData (backed by SQLite)
- **CLI**: swift-argument-parser
- **Package management**: Swift Package Manager
- **Testing**: XCTest / Swift Testing

## Reporting (future)

- Monthly budget vs actual
- Net worth over time
- Cash flow
- Balance sheet

## Verification

Local deterministic verification commands:

```bash
# ShillingCore (uses ShillingCore/Package.resolved)
cd ShillingCore
swift package resolve
swift test --disable-automatic-resolution

# App build (uses Xcode workspace Package.resolved)
xcodebuild \
  -project /Users/andrew/code/shilling/Shilling/Shilling.xcodeproj \
  -scheme Shilling \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/shilling-deriveddata \
  -clonedSourcePackagesDirPath /tmp/shilling-source-packages \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  build
```

CI verification is defined in `.github/workflows/ci.yml` and runs the same checks on pull requests and pushes to `main`.

## Local Release Build Automation

Use the repository build automation to produce a local release archive and app bundle:

```bash
# Archive release build to /tmp/Shilling.xcarchive
make app-release

# Archive and install to ~/Applications/Shilling.app
make app-install

# Archive, install, and open the app
make app-install-open
```

The app bundle produced by the archive flow is at:
`/tmp/Shilling.xcarchive/Products/Applications/Shilling.app`

All targets call `scripts/build-macos-app.sh`, which supports env overrides (for example `ARCHIVE_PATH`, `DERIVED_DATA_PATH`, `INSTALL_DIR`).

## Legacy Migration Export

Export legacy Postgres data into a migration SQLite file (raw + target-shaped tables):

```bash
make export-legacy-migration-sqlite LEGACY_PG_DB=<source-db>
```

Overrides:

```bash
make export-legacy-migration-sqlite \
  LEGACY_PG_DB=<source-db> \
  LEGACY_MIGRATION_SQLITE=/tmp/legacy-migration.sqlite \
  LEGACY_FAMILY_ID=<family-uuid>
```

Detailed format and validation docs:
- `docs/legacy-postgres-migration-sqlite-format.md`
