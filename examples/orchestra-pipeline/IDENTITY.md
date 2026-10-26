# Public Workshop Example - Identity

> A public-safe workspace that turns one fictional workshop request into an evidence-based orientation report through intake, research, draft, and review.

Layer 0. Read this before anything else, every session.

## Workspace Map

```
orchestra-pipeline/
├── IDENTITY.md              # layer 0, you are here
├── CONTEXT.md               # layer 1, typed routing and session rules
├── CLAUDE.md                # adapter, aliases IDENTITY.md
├── _config/                 # layer 3, five human-owned rule books
├── _log/                    # central ledger and forge proposals
├── raw/                     # layer 4a, immutable public-safe captures
│   └── workshop/            # source notes for the fictional workshop
├── wiki/                    # layer 4b, compiled knowledge and its logs
│   ├── index.md             # one row for the compiled article
│   ├── log.md               # append-only knowledge operations
│   └── workshop/            # evidence-linked articles
├── 00-intake/               # reserved intake and external input binding
│   ├── CONTEXT.md           # layer 2 job card
│   └── output/              # materialised request and intake brief
├── 01-research/             # evidence compilation
│   ├── CONTEXT.md
│   └── output/              # evidence brief
├── 02-draft/                # report drafting
│   ├── CONTEXT.md
│   └── output/              # draft report
└── 03-review/               # evidence audit and final report
    ├── CONTEXT.md
    └── output/              # final report
```

## Rules

1. Full workspace-relative paths are identity. Numeric prefixes are filing aids, and routing-table order is execution authority.
2. `LOAD` is a prerequisite, `NEXT` is forward control flow, and `REWORK` is backward repair. Do not infer one edge type from another.
3. `00-intake` only bounds the request. External `@NAME` inputs belong there, never in a positive stage.
4. Inputs define read scope and Outputs define write scope. `No touch` forbids both. Start a job only after strict preflight returns `RUN`.
5. Orchestra checks are report-only. They do not execute a job, create a graph file, or approve an external action.
6. `raw/` is immutable. Every load-bearing wiki fact must appear verbatim in a raw file linked by the article's `Raw:` field.
7. Keep this workspace self-contained. Git may distribute the same files, but no export, mirror, second brain, or cloud service is required.
8. Append task and skill lines to `_log/LOOP-LEDGER.md` at Session Close. Never rewrite log history.
9. When the map stops matching the disk, fix the map.
