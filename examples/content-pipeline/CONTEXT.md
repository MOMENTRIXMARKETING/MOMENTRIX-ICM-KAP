# Explainer Desk - Routing

Layer 1. Find the job, go to the stage, load only what that stage's job card names.

## Routing

| Job | Where | Load first |
|---|---|---|
| A new question to answer | `01-research/CONTEXT.md` | `_config/conventions.md` |
| Turn a brief into narration | `02-script/CONTEXT.md` | `_config/voice.md` |
| Turn narration into a shot list | `03-production/CONTEXT.md` | `_config/style.md` |
| Assemble what the client receives | `output/CONTEXT.md` | `_config/style.md` |
| Check what a word means here | `_config/glossary.md` | - |
| Close a task | `_log/LOOP-LEDGER.md` | - |
| Propose a rule change | `_log/FORGE-PROPOSALS.md` | - |
| Understand the workspace | `IDENTITY.md` | - |

If the job is not in the table, the table is incomplete. Say so before improvising a row.

## Pipeline

Each stage takes named inputs and writes one named artifact. Conversation belongs at a checkpoint inside a stage, never between them.

```
01-research -> 02-script -> 03-production -> output
```

| Stage | Job card | Reads | Writes |
|---|---|---|---|
| 01 research | `01-research/CONTEXT.md` | the question, the sources it finds | `01-research/output/` |
| 02 script | `02-script/CONTEXT.md` | `01-research/output/` | `02-script/output/` |
| 03 production | `03-production/CONTEXT.md` | `02-script/output/` | `03-production/output/` |
| delivery | `output/CONTEXT.md` | all three stage outputs | `output/` |

A stage hands off through files. A human can open a stage output, edit it, and the next stage picks up the edit. There is no other state.

## Session Start

1. Read `IDENTITY.md`. That is the map.
2. Read this file and pick the row that matches the job.
3. Open the job card that row names and read its Inputs table.
4. Load exactly what the Inputs table names, at the scope it names. Nothing else.
5. Do the work. Write to the paths in the job card's Outputs table.
6. Append one line to `_log/LOOP-LEDGER.md`.

## Rule Books

`_config/` holds the rule books. A rule book says what is true and what is allowed here. It never says what to do next, and it is never called a skill. Pull one only when a job card names it.

| Rule book | Holds | Pulled when |
|---|---|---|
| `_config/conventions.md` | naming, folder shape, the handoff rule | creating or moving any file |
| `_config/glossary.md` | the words this desk uses and the one meaning each carries | any wording decision |
| `_config/voice.md` | who we write for, how narration sounds, what we may not claim | writing anything a viewer hears |
| `_config/style.md` | formatting: headings, tables, timecodes, numbers | writing or editing markdown |

Rule books are edited by a human. An agent proposes a change into `_log/FORGE-PROPOSALS.md` and waits.
