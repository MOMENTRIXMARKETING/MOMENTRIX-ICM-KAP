# sales

## Purpose

Price hires the same way twice, answer fast, and chase nobody twice in a week.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Company | `../_config/voice.md` | full file | how we sound |
| Department | `_config/quoting.md` | rate card and rules | what a hire costs |
| Last run | `report.md`, then what it names | full file | who is waiting |

## Process

1. Read `report.md` and the report it names. Chase nobody twice in a week.
2. Pick the stage below and do it.
3. Prices come from `_config/quoting.md`. A price not on the card is a question.
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
| Price a hire | `01-quotes/CONTEXT.md` |
| Chase open quotes | `02-follow-up/CONTEXT.md` |
| Asked for a discount | log a call line, hold the price |
| Not a sales job | `../CONTEXT.md` |
