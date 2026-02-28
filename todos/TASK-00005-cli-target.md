---
status: complete
completed: 2026-02-28
created: 2026-02-28
---

# Set Up CLI Executable Target

Create the CLI binary target in the ShillingCore package.

## Work
- Implement root command using swift-argument-parser
- Set up ModelContainer pointing to the default data store location
  - Default: `~/Library/Application Support/Shilling/shilling.store`
  - Allow override via `--data-dir` flag
- Implement basic subcommands:
  - `shilling accounts list` — list all accounts
  - `shilling version` — print version
- Support `--json` output flag for scripting

## Acceptance Criteria
- `swift run ShillingCLI accounts list` works (shows empty list)
- `swift run ShillingCLI version` prints version
- `--json` flag produces valid JSON output
- CLI reads from the same data store as the macOS app
