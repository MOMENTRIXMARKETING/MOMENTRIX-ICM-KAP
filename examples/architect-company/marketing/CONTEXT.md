# marketing

## Purpose

Keep the listings honest and send one newsletter a month a busy customer finishes.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Company | `../_config/voice.md` | full file | how we sound |
| Department | `_config/listings.md` | full file | what a listing must say |
| Last run | `report.md`, then what it names | full file | what is drafted |

## Process

1. Read `report.md` and the report it names. Send nothing twice.
2. Pick the stage below and do it.
3. Every price shown comes from the sales rate card, never an old listing.
4. Write the report into `reports/`, run date and slug. Never overwrite.
5. Point `report.md` at it, write `status.md`, append the ledger row.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Run report | `reports/` | five parts, `../_config/reporting.md` |
| Pointer | `report.md` | one link, newest report |
| Rollup line | `status.md` | one line, read upward |

## Routing

| When | Go to |
|---|---|
| A listing is wrong or stale | `01-listings/CONTEXT.md` |
| Monthly newsletter | `02-newsletter/CONTEXT.md` |
| A price looks wrong | ask sales, change no listing |
| Not a marketing job | `../CONTEXT.md` |
