# Explainer Desk - Identity

> A two person desk that turns one reader question into a five minute narrated explainer video. Research, script, production, in that order, handing off through files.

Layer 0. Read this before anything else, every session.

## Workspace Map

```
content-pipeline/
├── IDENTITY.md              # layer 0, you are here: where am I
├── CONTEXT.md               # layer 1: where do I go
├── CLAUDE.md                # adapter, aliases IDENTITY.md
├── _config/                 # layer 3 rule books: conventions, glossary, voice, style
├── _log/                    # layer 4b: the ledger and the forge proposals
├── 01-research/             # stage 1: the question becomes a sourced brief
│   ├── CONTEXT.md           # layer 2 job card
│   └── output/              # layer 4b: the brief this stage produced
├── 02-script/               # stage 2: the brief becomes narration
│   ├── CONTEXT.md
│   └── output/
├── 03-production/           # stage 3: the narration becomes a shot list
│   ├── CONTEXT.md
│   └── output/
└── output/                  # layer 4b: the finished package a human receives
    └── CONTEXT.md           # layer 2 job card for the delivery folder
```

## Layers

Layer 0 is this file. Layer 1 is `CONTEXT.md`. Layer 2 is each stage `CONTEXT.md`, the job card. Layer 3 is `_config/`. Layer 4b is every `output/` folder.

There is no layer 4a here. This workspace has no `raw/`, so it cites its sources inside the brief instead of holding them. Add `raw/` and `wiki/` by re-planning with the wiki archetype when the desk starts keeping what it learns.

## Rules

1. One stage, one job. The stage that researches does not write narration. The stage that writes narration does not plan shots.
2. A stage reads the previous stage's `output/` and nothing further back. If it needs something older, the handoff is wrong and the fix is upstream.
3. Every stage output is a human edit surface. Open it, change it, save it. The next stage picks up whatever is in the file, not what the last agent believed.
4. Never write a number, name or date the brief does not carry. Unsourced claims are cut, not softened.
5. `_config/` holds rule books. They bind, and no agent edits one. Proposals go to `_log/FORGE-PROPOSALS.md`.
6. Append one line to `_log/LOOP-LEDGER.md` when a stage closes. Never rewrite history there.
7. When the map above stops matching the disk, the map is wrong. Fix the map.
