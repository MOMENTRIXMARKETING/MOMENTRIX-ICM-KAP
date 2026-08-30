# Riverbend Supply - Identity

> A three person tool hire business run as a Pattern 24 workspace. The folders are the departments and no process sits above them.

Layer 0. Read this before anything else, every session.

## Workspace Map

```
architect-company/
├── IDENTITY.md              # layer 0, you are here: where am I
├── CONTEXT.md               # layer 1: where do I go
├── CLAUDE.md                # adapter, aliases IDENTITY.md
├── ARCHITECT.md             # layer 2 job card for this root folder
├── status.md                # layer 4b: rollup, one line per department
├── report.md                # pointer at the newest architect report
├── reports/                 # layer 4b: architect reports, one per day
├── _config/                 # layer 3: rate card, voice, reporting, conventions
├── _log/                    # the append only ledger
├── finance/                 # department: money in, money out, month end
│   ├── CONTEXT.md           # layer 2: what finance does
│   ├── status.md            # its one compiled line
│   ├── report.md            # pointer at the newest report
│   ├── reports/             # layer 4b: one per run, append only
│   ├── _config/             # layer 3: rules only finance obeys
│   ├── 01-bookkeeping/      # job card: code and file the week
│   └── 02-month-end/        # job card: close the month, write the report
├── sales/                   # department: quotes, bookings, follow up
│   ├── 01-quotes/           # job card: price one hire
│   └── 02-follow-up/        # job card: chase the open quotes
└── marketing/               # department: listings and the newsletter
    ├── 01-listings/         # job card: keep the hire listings current
    └── 02-newsletter/       # job card: write the monthly newsletter
```

`sales/` and `marketing/` repeat finance's shape: `CONTEXT.md`, `status.md`, `report.md`, `reports/`, `_config/`, then stage folders.

## Layers

Layer 0 is this file. Layer 1 is `CONTEXT.md`. Layer 2 is `ARCHITECT.md` and each folder `CONTEXT.md`. Layer 3 is `_config/`. Layer 4b is `status.md` and `reports/`.

Layers 1 to 3 recurse: a department repeats the shape inside itself. `ARCHITECT.md` is a layer 2 job card for the root folder, not a new layer.

## Rules

1. Agents are ephemeral, reports are files. A worker's last act is one report in `reports/` and one line in `status.md`. A worker that wrote nothing did not finish.
2. Reports are append only. One file per run, under the run date and a slug. A wrong report is corrected by a new report, never by an edit.
3. `status.md` is compiled and never authoritative. If it disagrees with the folder, the folder wins.
4. The architect does no department work above the small task floor. The floor is in `_config/conventions.md`, not re-argued each morning.
5. Messages coordinate, files record. A decision that lives only in a conversation was never made.
6. `_config/` holds rule books. They bind, and no agent edits one.
7. When the map above stops matching the disk, the map is wrong. Fix the map.
