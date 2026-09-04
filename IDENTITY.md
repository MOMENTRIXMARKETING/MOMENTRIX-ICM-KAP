# momentrix-icm-kap-toolkit - Identity

> The toolkit that drops an ICM context layer onto someone else's project. It is the tool, not a workspace built with it.

Layer 0. Read this before anything else, every session.

## Workspace Map

```
momentrix-icm-kap-toolkit/
├── IDENTITY.md              # layer 0, you are here
├── CONTEXT.md               # layer 1: where do I go
├── CLAUDE.md                # adapter, aliases IDENTITY.md
├── BUILD-CONTRACT.md        # layer 3 rule book: the non-negotiables
├── icm.defaults.json        # every budget, glob and section list
├── README.md                # the front door
├── QUICKSTART.md            # the sixty-second path: NEW, OVER, TRANSFER
├── NOTICE.md                # provenance: the three upstreams
├── LICENSE                  # MIT
├── .gitignore               # keeps the toolkit's scratch folder out of git
├── .claude-plugin/          # marketplace.json, plugin.json: the install path
├── scripts/                 # POSIX sh: check, plan, apply, rollback, loop, lib
├── skills/                  # the nine icm-* skills, one SKILL.md each
├── spec/                    # layer 3 rule books: layers, budgets, conventions
├── interview-templates/     # .tmpl material a human fills in; no script reads it
├── docs/                    # methodology, retrofit, deck copy, the paper
├── examples/                # worked examples: the raw and wiki pair, whole trees
├── _log/                    # this repo's own ledger, proposals, index
└── tests/                   # run-tests.sh, the POSIX harness, plus the python one
```

## Layers

| Layer | Where | Question it answers |
|---|---|---|
| 0 | `IDENTITY.md` | Where am I? |
| 1 | `CONTEXT.md` | Where do I go? |
| 2 | a folder's CONTEXT.md, the job card | What do I do here? |
| 3 | rule books | What rules apply? |
| 4a | immutable sources | What is true? |
| 4b | compiled knowledge and output | What do we know, what did we make? |

## Why layers 2, 4a and 4b are absent

The toolkit ships every layer and runs 0, 1, 3 and the loop on itself. No stages, no `raw/`, no `wiki/`: this repo makes a toolkit, not knowledge. `examples/` holds worked trees instead. The checker reports the rest absent rather than failing.

## Rules

1. Every script is POSIX `sh`. No bashisms, no python, no node. `sh -n`, the bashism sweep and the tests gate every change.
2. Numbers live in one file, `icm.defaults.json`. Prose cites it, and never restates a budget, a ceiling or a skip glob as a literal.
3. Rule books are rule books. "Skill" means a SKILL.md under `skills/` and nothing else. A folder's own CONTEXT.md is a job card.
4. A user's file is never rewritten. `CLAUDE.md` and `.gitignore` get a marked block appended, backed up first. Anything else that exists is parked in `.icm/proposed/`.
5. Every path written into a document exists on disk. A path that does not resolve is a failure, not a typo.
6. Test fixtures carry a space in their path on purpose. Quote every path variable, every time.
7. When the map stops matching the disk, the map is wrong. Fix the map.
