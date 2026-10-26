# Public Workshop Example - Routing

Layer 1. Choose one full job-card path, then load only what that card names.

## Routing

| Job | Where | Load first | Edge |
|---|---|---|---|
| Bound a new workshop request | `00-intake/CONTEXT.md` | - | NEXT |
| Compile the workshop evidence | `01-research/CONTEXT.md` | - | NEXT |
| Draft the orientation report | `02-draft/CONTEXT.md` | - | NEXT |
| Audit and finish the report | `03-review/CONTEXT.md` | - | NEXT |

The rows above are in execution order. The full path, not the numeric prefix alone, identifies each job.

For freshly derived workflow edges, workflow backlinks, knowledge edges, and knowledge backlinks on demand, run `sh "$ICM_HOME/scripts/icm-check.sh" --orchestra-view .` from this workspace root. The view is generated at read time and no graph or backlink file is stored.

## Session Start

1. Read `IDENTITY.md`, then choose exactly one Routing row.
2. Run `sh "$ICM_HOME/scripts/icm-check.sh" --orchestra .` for structural validation.
3. Run literal `--orchestra --job CARD` strict preflight for the selected card. Bind every external input with an already materialised workspace path.
4. Do not start on `MISSING`. On `RUN`, read only the selected card's Inputs and write only its Outputs. `RUN` means ready to start, not complete or externally approved.
5. Keep human approval gates for messages, invitations, bookings, and every other external action.
6. Run Session Close before your last reply.

## Session Close

Before your last reply of any task, do these four, in order. Skipping one is itself a miss, sev 2. Log it.

1. **Miss check.** Did you ask for something already available, get corrected by hand, skip a step in your instructions, ship output that needed rework, or run when you should not have (or not run when you should)? Each one is one miss line in `_log/LOOP-LEDGER.md`, shape in that file. Name the rule book, job card or skill at fault, never a person. Name the mechanism, not the feeling. Grep first: a fault already open on that path is not logged twice. A fault that returns after a patch is logged with `RECURRENCE:` in front. Log it even when you recovered. No misses, write nothing.
2. **Use line.** One per skill or job card this task ran under.
3. **Placement question.** Did this task produce a procedure, rule or fact that nothing on disk holds? Do not create it. Append a proposal of kind `new` to `_log/FORGE-PROPOSALS.md` at the path `_config/conventions.md` gives it under Where A Learned Thing Lives, and stop. A human naming the id is what creates it.
4. **Task line.** Close against the job card, then append the task line and any call lines.

Sub agents carry these four steps too. One that cannot write files reports its lines in its final message and the caller appends them. One ledger per workspace, never one per agent.

## Rule Books

Pull a rule book only when the selected job card names it. A rule book binds and is never called a skill.

| Rule book | Holds | Pulled when |
|---|---|---|
| `_config/conventions.md` | paths, typed handoffs, one home per fact | creating or moving a file |
| `_config/glossary.md` | workspace terms and their single meanings | resolving wording |
| `_config/voice.md` | audience, tone, and claim limits | drafting public prose |
| `_config/style.md` | headings, tables, links, and report shape | formatting an artifact |
| `_config/grounding.md` | raw evidence and wiki compilation | writing into `wiki/` |

Only a human edits a rule book. An agent appends a proposal to `_log/FORGE-PROPOSALS.md` and waits.
