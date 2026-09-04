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
6. Run the Session Close below before your last reply.

## Session Close

Before your last reply of any task, do these four, in order. Skipping one is itself a miss, sev 2. Log it.

1. **Miss check.** Did you ask for something already available, get corrected by hand, skip a step in your instructions, ship output that needed rework, or run when you should not have (or not run when you should)? Each one is one miss line in `_log/LOOP-LEDGER.md`, shape in that file. Name the rule book, job card or skill at fault, never a person. Name the mechanism, not the feeling. Grep first: a fault already open on that path is not logged twice. A fault that returns after a patch is logged with `RECURRENCE:` in front. Log it even when you recovered. No misses, write nothing.
2. **Use line.** One per skill or job card this task ran under.
3. **Placement question.** Did this task produce a procedure, rule or fact that nothing on disk holds? Do not create it. Append a proposal of kind `new` to `_log/FORGE-PROPOSALS.md` at the path `_config/conventions.md` gives it under Where A Learned Thing Lives, and stop. A human naming the id is what creates it.
4. **Task line.** Close against the job card, then append the task line and any call lines.

Sub agents carry these four steps too. One that cannot write files reports its lines in its final message and the caller appends them. One ledger per workspace, never one per agent.

## Rule Books

`_config/` holds the rule books. A rule book says what is true and what is allowed here. It never says what to do next, and it is never called a skill. Pull one only when a job card names it.

| Rule book | Holds | Pulled when |
|---|---|---|
| `_config/conventions.md` | naming, folder shape, the handoff rule | creating or moving any file |
| `_config/glossary.md` | the words this desk uses and the one meaning each carries | any wording decision |
| `_config/voice.md` | who we write for, how narration sounds, what we may not claim | writing anything a viewer hears |
| `_config/style.md` | formatting: headings, tables, timecodes, numbers | writing or editing markdown |

Rule books are edited by a human. An agent proposes a change into `_log/FORGE-PROPOSALS.md` and waits.
