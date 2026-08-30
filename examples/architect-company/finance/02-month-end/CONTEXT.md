# 02 month end

## Purpose

Close the month: reconcile, list what is open, write the line the company reads.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Prior stage | `../01-bookkeeping/CONTEXT.md` | Outputs | where week reports land |
| Department | `../_config/accounts.md` | full file | the coding this rests on |
| Company | `../../_config/reporting.md` | full file | what a run owes |

## Process

1. Read the month's week reports in `../reports/`.
2. Reconcile bank to coded lines. Name any difference, never absorb it.
3. List every uncoded line and who can answer it.
4. Write the month report into `../reports/`, run date and slug.
5. Point `../report.md` at it, write `../status.md`, append the ledger row.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Month report | `../reports/` | five parts |
| Pointer and rollup | `../report.md`, `../status.md` | one link, one line |
| Ledger line | `../../_log/LOOP-LEDGER.md` | one appended row |

## Routing

| When | Go to |
|---|---|
| Closed | `../../ARCHITECT.md` reads next |
| Bank will not reconcile | report the difference, change no figure |
| Coding looks wrong | log a call line, edit no rule book |
