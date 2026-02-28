# ADR 0001: Use SwiftData for Persistence

## Status
Accepted

## Context
We need a persistence layer that works in both a SwiftUI macOS app and a CLI tool, all targeting macOS 14+.

Options considered:
1. **SwiftData** — Apple's native persistence framework, built on Core Data / SQLite
2. **GRDB** — third-party Swift SQLite library with full SQL control
3. **Core Data** — predecessor to SwiftData, more verbose but battle-tested

## Decision
Use SwiftData.

## Rationale
- We are targeting macOS only (14+), so SwiftData availability is not a concern.
- SwiftData integrates natively with SwiftUI (`@Query`, `@Environment(\.modelContext)`), reducing boilerplate.
- `@Model` macro gives us a clean, declarative schema definition.
- `ModelContainer` can be created programmatically for the CLI target.
- In-memory containers simplify testing.
- GRDB would give more SQL control but adds a third-party dependency and loses the native SwiftUI integration.
- If we hit SwiftData limitations later, we can drop down to the underlying Core Data stack or migrate — but start with the simpler option.
