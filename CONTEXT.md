# momentrix-icm-kap-toolkit - Routing

> Layer 1. You have read `IDENTITY.md`. Find the job, go to the destination, load what the row names.

## Routing

| What you are doing | Go to | Load first |
|---|---|---|
| Changing a script or the shared library | `scripts/` | `spec/CLI-CONTRACT.md`, then `BUILD-CONTRACT.md` |
| Writing or editing a toolkit skill | `skills/` | `docs/skill-authoring.md` |
| Writing a customer-specific skill | `examples/customers/_TEMPLATE/CONTEXT.md` | `spec/CONVENTIONS.md` Pattern 25 |
| Changing a budget, a skip glob or a required section | `icm.defaults.json` | `spec/budgets.md` |
| Editing material a skill fills in with a human | `interview-templates/` | `spec/placeholder-syntax.md` |
| Changing the layer model or the conventions | `spec/` | `spec/layers.md` |
| Changing what counts as evidence | `scripts/check_evidence.py` | `spec/grounding-invariant.md` |
| Explaining the method to a human | `docs/` | `docs/methodology.md` |
| Proving the repo still tells the truth | `tests/run-tests.sh` | `BUILD-CONTRACT.md` |
| Understanding the workspace | `IDENTITY.md` | - |

If the job is not in the table, the table is incomplete. Say so before improvising a row.

## Session Start

1. Read `IDENTITY.md`. That is the map.
2. Read this file and pick the row that matches the job.
3. Read `BUILD-CONTRACT.md` before writing a single file. It binds every path in this repo.
4. Load the rule book in the Load first column and nothing else. Loading more does not make the change better.
5. Do the work.
6. Run both gates from the repo root and read the output: `ICM_HOME=$(pwd)`, then `sh tests/run-tests.sh`, then `sh "$ICM_HOME/scripts/icm-check.sh" .`. Green means the harness passed and the checker reported no FAIL. Anything else is not done.

## Rule Books

A rule book binds. It is reference, not instruction, and it is never called a skill. This repo keeps its rule books at the root and under `spec/`, not in a layer 3 folder, because they govern the toolkit's own source rather than a workspace the toolkit built.

| Rule book | Binds | Pulled when |
|---|---|---|
| `BUILD-CONTRACT.md` | every file in this repo | before writing or editing anything |
| `spec/CLI-CONTRACT.md` | every command name, flag, exit code, artifact path and disposition word | changing a script, a skill, or prose naming one |
| `spec/CONVENTIONS.md` | naming, folder shapes, the twenty-five patterns | creating, moving or renaming a file |
| `spec/layers.md` | the five layers and how they recurse | any change to what a layer means |
| `spec/budgets.md` | ceilings, all of them read from `icm.defaults.json` | writing or growing a layer file |
| `spec/grounding-invariant.md` | anything the evidence half produces | changing `check_evidence.py` |
| `spec/authority-model.md` | what a script may fix, what a human must decide | changing a check or a lint |
| `spec/excluded-folders.md` | the one skip list the walkers obey | changing what a walk sees |
| `spec/placeholder-syntax.md` | the `{{PLACEHOLDER}}` contract | editing anything under `interview-templates/` |

Only a human edits a rule book. There is no forge proposals file here, because this repo has no ledger: a proposal against a rule book is a pull request changing `BUILD-CONTRACT.md` or a file under `spec/`, argued in the description.
