# Architect - Job Card

Layer 2. This is the job card for the root folder. It is not a new layer, and the stack is still 0, 1, 2, 3, 4a, 4b.

## Purpose

Read the rollup, decide which departments work today, spawn one agent per department, and stay out of the work itself except below the small task floor.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Rollup | `status.md` | full file | where to look first |
| Department reports | `finance/report.md`, `sales/report.md`, `marketing/report.md` | the pointer, then the newest report | what actually happened |
| Rule book | `_config/conventions.md` | "The small task floor" | whether to spawn or to do it here |
| Rule book | `_config/reporting.md` | full file | what a finished run owes |

Read reports, not conversations. Not transcripts, not scrollback, not what you remember deciding yesterday. Reports are the interface between a dead agent and a live one.

## Process

1. Read `status.md`. Treat it as an index, never as the truth. Any line that matters, confirm in the department folder.
2. For each department whose line says attention, open its `report.md`, then the report it points at.
3. Decide the day's work. Write the decision down before acting on it.
4. For each job above the small task floor, spawn an agent into the department folder and give it nothing but the folder path. The folder tells it everything else.
5. For each job below the floor, do it yourself and write what you did into today's report. Doing it and not logging it is the failure mode this rule exists to stop.
6. Write today's report to `reports/` under today's date and a slug. Never write over an older report.
7. Update `report.md` to point at it. Append one line to `_log/LOOP-LEDGER.md`.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Architect report | `reports/` under today's date and a slug | the shape in `_config/reporting.md` |
| Pointer | `report.md` | one link at the newest report |
| Ledger line | `_log/LOOP-LEDGER.md` | one appended row |

The architect never writes a department's `status.md` line. The worker that did the run writes it.

## Routing

| When | Go to |
|---|---|
| A department needs work above the floor | that department's `CONTEXT.md` |
| A job is below the floor | do it here, then log it in today's report |
| `status.md` disagrees with a folder | trust the folder, then correct `status.md` |
| A rule book looks wrong | log a call line in `_log/LOOP-LEDGER.md`, change nothing |
