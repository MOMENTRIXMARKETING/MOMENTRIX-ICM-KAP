# momentrix-icm-kap-toolkit - Routing

> Layer 1. Find the job, go to the destination, load what the row names.

## Routing

| What you are doing | Go to | Load first |
|---|---|---|
| Changing a script or the shared library | `scripts/` | `spec/CLI-CONTRACT.md`, then `BUILD-CONTRACT.md` |
| Writing or editing a skill | `skills/` | `docs/skill-authoring.md` |
| Changing a budget, skip glob or required section | `icm.defaults.json` | `spec/budgets.md` |
| Editing interview material | `interview-templates/` | `spec/placeholder-syntax.md` |
| Changing the layer model or conventions | `spec/` | `spec/layers.md` |
| Changing what counts as evidence | `scripts/check_evidence.py` | `spec/grounding-invariant.md` |
| Explaining the method to a human | `docs/` | `docs/methodology.md` |
| Proving the repo tells the truth | `tests/run-tests.sh` | `BUILD-CONTRACT.md` |
| Logging a miss or a use, closing a task | `_log/LOOP-LEDGER.md` | `skills/icm-log/SKILL.md` |
| Running the forge, placing a learned thing | `_log/FORGE-PROPOSALS.md` | `spec/placement.md` |
| Understanding the workspace | `IDENTITY.md` | - |

Job not in the table: say so before improvising a row.

## Session Start

1. Read `IDENTITY.md`. That is the map.
2. Read this file and pick the row that matches the job.
3. Read `BUILD-CONTRACT.md` before writing a single file. It binds every path here.
4. Load the rule book in the Load first column and nothing else.
5. Do the work.
6. Run both gates from the repo root: `ICM_HOME=$(pwd)`, `sh tests/run-tests.sh`, `sh "$ICM_HOME/scripts/icm-check.sh" .`. Harness passed and no FAIL, or it is not done.
7. Run the Session Close below. This repo runs its own loop under `_log/`.

## Session Close

Before your last reply of any task, do these four, in order. Skipping one is itself a miss, sev 2. Log it.

1. **Miss check.** Did you ask for something already available, get corrected by hand, skip a step in your instructions, ship output that needed rework, or run when you should not have (or not run when you should)? Each one is one miss line in `_log/LOOP-LEDGER.md`, shape in that file. Name the rule book, job card or skill at fault, never a person. Name the mechanism, not the feeling. Grep first: a fault already open on that path is not logged twice. A fault that returns after a patch is logged with `RECURRENCE:` in front. Log it even when you recovered. No misses, write nothing.
2. **Use line.** One per skill or job card this task ran under.
3. **Placement question.** Did this task produce a procedure, rule or fact that nothing on disk holds? Do not create it. Append a proposal of kind `new` to `_log/FORGE-PROPOSALS.md` at the path `spec/placement.md` gives it, and stop. A human naming the id is what creates it.
4. **Task line.** Close against the job card, then append the task line and any call lines.

Sub agents carry these four steps too. One that cannot write files reports its lines in its final message and the caller appends them. One ledger per workspace, never one per agent.

## Rule Books

A rule book binds. Reference, not instruction, never a skill. They sit at the root and under `spec/` because they govern the toolkit's own source.

| Rule book | Binds | Pulled when |
|---|---|---|
| `BUILD-CONTRACT.md` | every file in this repo | before writing or editing anything |
| `spec/CLI-CONTRACT.md` | every command, flag, exit code, artifact path, disposition word | changing a script, a skill, or prose naming one |
| `spec/CONVENTIONS.md` | naming, folder shapes, the patterns | creating, moving or renaming a file |
| `spec/layers.md` | the five layers and how they recurse | any change to what a layer means |
| `spec/budgets.md` | ceilings, read from `icm.defaults.json` | writing or growing a layer file |
| `spec/grounding-invariant.md` | the evidence half | changing `check_evidence.py` |
| `spec/authority-model.md` | what a script may fix, what a human must decide | changing a check or a lint |
| `spec/excluded-folders.md` | the one skip list | changing what a walk sees |
| `spec/placeholder-syntax.md` | the `{{PLACEHOLDER}}` contract | editing `interview-templates/` |
| `spec/placement.md` | where a learned thing lives | the placement question at Session Close |

Only a human edits a rule book. The forge proposes against `BUILD-CONTRACT.md` and `spec/`; the approved edit ships as a pull request quoting the proposal id.
