# ADR 0002: Swift Package + Xcode App Project Structure

## Status
Accepted

## Context
The app needs a shared core (models, services) consumed by both a macOS SwiftUI app and a CLI tool.

Options considered:
1. **Local Swift Package (ShillingCore) + Xcode project for the app** — the core is a library package, the app is an Xcode project that depends on it, the CLI is an executable target in the package.
2. **Monolithic Xcode project** — everything in one Xcode project with multiple targets.
3. **Pure SPM** — everything as SPM targets including the SwiftUI app.

## Decision
Option 1: Local Swift Package for the core, Xcode project for the macOS app.

## Rationale
- Clean separation between domain logic (no UI dependencies) and presentation.
- The Swift Package is independently testable without Xcode project overhead.
- The CLI target lives in the same package, sharing models and services directly.
- The Xcode project handles app-specific concerns (entitlements, signing, asset catalogs).
- Pure SPM for a macOS app is possible but awkward for app lifecycle, resources, and distribution.
