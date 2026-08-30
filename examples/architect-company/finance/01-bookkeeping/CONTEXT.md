# 01 bookkeeping

## Purpose

Code one week of money in and out so the month end has nothing to guess.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Department | `../_config/accounts.md` | the code list | where each line goes |
| Last run | `../report.md`, then what it names | open items | what is unfinished |
| Company | `../../_config/reporting.md` | "What a report contains" | the report shape |

## Process

1. Pull the week's bank lines and the matching invoices.
2. Code each line against `../_config/accounts.md`. One line, one code.
3. A line you cannot code stays uncoded and goes in the report by name.
4. Deposits stay put until the tool is back and checked.
5. Write the report into `../reports/`, run date and slug.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Week report | `../reports/` | five parts |
| Pointer | `../report.md` | one link |
| Ledger line | `../../_log/LOOP-LEDGER.md` | one appended row |

## Routing

| When | Go to |
|---|---|
| Week coded, month is over | `../02-month-end/CONTEXT.md` |
| A line will not code | leave it uncoded, name it in the report |
| Not a finance job | `../../CONTEXT.md` |
