# finance

## Purpose

Code the week, close the month, hand up a line the company trusts.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Company | `../_config/reporting.md` | full file | what a run owes |
| Department | `_config/accounts.md` | the code list | where a line is coded |
| Last run | `report.md`, then what it names | full file | what is open |

## Process

1. Read `report.md` and the report it names. Start from what is open.
2. Pick the stage below and do it.
3. Every figure comes from an invoice, a bank line or the diary. Say which.
4. Write the report into `reports/`, run date and slug. Never overwrite.
5. Point `report.md` at it, write the `status.md` line, append to `../_log/LOOP-LEDGER.md`.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Run report | `reports/` | five parts, `../_config/reporting.md` |
| Pointer | `report.md` | one link, newest report |
| Rollup line | `status.md` | one line, read upward |

## Routing

| When | Go to |
|---|---|
| Weekly coding | `01-bookkeeping/CONTEXT.md` |
| Month end | `02-month-end/CONTEXT.md` |
| A figure will not reconcile | leave it open in the report |
| Not a finance job | `../CONTEXT.md` |
