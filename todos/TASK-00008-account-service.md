---
status: ready
created: 2026-02-28
---

# Account Service

Service for managing the chart of accounts.

## Work
- Create account (name, type, optional parent)
- Edit account (rename, reparent, archive)
- Prevent deleting accounts that have entries (archive instead)
- List accounts by type, with hierarchy
- Validate: no duplicate names within same parent

## Acceptance Criteria
- CRUD operations tested
- Cannot delete account with entries (returns error suggesting archive)
- Duplicate name validation tested
