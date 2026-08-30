# 02 follow up

## Purpose

Sweep the open quotes on the rule book schedule, and stop when it says stop.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Prior stage | `../01-quotes/CONTEXT.md` | Outputs | where quotes land |
| Department | `../_config/quoting.md` | "Chasing", the 14 day rule | when to write, when to stop |
| Last run | `../report.md`, then what it names | open items | who was chased |

## Process

1. List every quote with no reply and the date it was sent.
2. Three days out, one follow up. Seven days out, one more.
3. Past seven days with two sent, stop. Leave it open and report it.
4. Past 14 days, requote. Never extend.
5. Write the report into `../reports/`, then the pointer and the rollup line.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Sweep report | `../reports/` | five parts |
| Pointer, rollup | `../report.md`, `../status.md` | one link, one line |
| Ledger line | `../../_log/LOOP-LEDGER.md` | one appended row |

## Routing

| When | Go to |
|---|---|
| Quote accepted | tell finance, the deposit codes to 110 |
| Two chases, no reply | stop, report it open |
| Asked for a discount | hold the price, log a call line |
