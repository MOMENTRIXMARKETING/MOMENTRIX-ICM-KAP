# Riverbend Supply - Routing

Layer 1. Find the job, go to the folder, load only what that folder names.

## Routing

| Job | Where | Load first |
|---|---|---|
| Run the day, decide who works | `ARCHITECT.md` | `status.md` |
| Anything about money or invoices | `finance/CONTEXT.md` | `_config/conventions.md` |
| Anything about a quote or a customer reply | `sales/CONTEXT.md` | `_config/voice.md` |
| Anything about listings or the newsletter | `marketing/CONTEXT.md` | `_config/voice.md` |
| Find out what happened last week | `status.md`, then the department `reports/` | - |
| Check what a hire costs | `_config/rate-card.md` | - |
| Check how a report must be written | `_config/reporting.md` | - |
| Understand the workspace | `IDENTITY.md` | - |

If the job is not in the table, the table is incomplete. Say so before improvising a row.

## Session Start

1. Read `IDENTITY.md`. That is the map.
2. Read this file and pick the row that matches the job.
3. Open the folder that row names and read its `CONTEXT.md`.
4. Load exactly what its Inputs table names. Nothing else.
5. Do the work. Write the report into that folder's `reports/`, then update its `status.md` line and its `report.md` pointer.
6. Run the Session Close below before your last reply.

Any model that opens this folder and reads `IDENTITY.md`, this file, `ARCHITECT.md` and `status.md` is the lead architect. There is no appointment and no handover meeting. The handover is the filesystem.

## Session Close

Before your last reply of any task, do these four, in order. Skipping one is itself a miss, sev 2. Log it.

1. **Miss check.** Did you ask for something already available, get corrected by hand, skip a step in your instructions, ship output that needed rework, or run when you should not have (or not run when you should)? Each one is one miss line in `_log/LOOP-LEDGER.md`, shape in that file. Name the rule book, job card or skill at fault, never a person. Name the mechanism, not the feeling. Grep first: a fault already open on that path is not logged twice. A fault that returns after a patch is logged with `RECURRENCE:` in front. Log it even when you recovered. No misses, write nothing.
2. **Use line.** One per skill or job card this task ran under.
3. **Placement question.** Did this task produce a procedure, rule or fact that nothing on disk holds? Do not create it. Append a proposal of kind `new` to `_log/FORGE-PROPOSALS.md` at the path `_config/conventions.md` gives it under Where A Learned Thing Lives, and stop. A human naming the id is what creates it.
4. **Task line.** Close against the job card, then append the task line and any call lines.

Sub agents carry these four steps too. One that cannot write files reports its lines in its final message and the caller appends them. One ledger per workspace, never one per agent.

## Rule Books

`_config/` holds the rule books. A rule book says what is true and what is allowed here. It never says what to do next, and it is never called a skill. A department may add its own rule books in its own `_config/`, and those bind only inside that department.

| Rule book | Holds | Pulled when |
|---|---|---|
| `_config/conventions.md` | naming, folder shape, the small task floor | creating or moving any file, deciding whether to spawn |
| `_config/rate-card.md` | what a hire costs, and who may change it | quoting, or showing a price anywhere |
| `_config/voice.md` | how we write to a customer and to each other | writing anything a human will read |
| `_config/reporting.md` | what a report must contain before it counts as done | closing any run |

Rule books are edited by a human. An agent proposes a change into `_log/LOOP-LEDGER.md` as a call line and waits.
