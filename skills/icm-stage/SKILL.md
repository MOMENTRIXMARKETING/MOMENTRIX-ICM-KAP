---
name: icm-stage
description: "This skill should be used when the user asks to 'add a stage', 'write a stage contract', 'what does this stage read and write', 'insert a stage before the build step', 'renumber the stages', or 'add a checkpoint or an audit to this stage'. Creates or repairs a numbered stage folder whose job card carries Purpose, Inputs, Process, Outputs and Routing, with one-way cross references and an output/ handoff, and never reorders existing folders without confirmation."
user-invocable: true
argument-hint: "<stage-name> [after:NN]"
---

# ICM Stage

Author the job card for one numbered stage.

A stage `CONTEXT.md` is a **job card**: layer 2, the control point of the workspace. It answers "what do I do here?" and nothing else. Its Inputs table decides exactly which layer 3 rule books and layer 4 artifacts get loaded, so every row you add costs the next agent attention. Layer definitions are in `$ICM_HOME/spec/layers.md`. The contract shape is Pattern 1 in `$ICM_HOME/spec/CONVENTIONS.md`.

A job card routes. It never carries the reference material itself. If you are writing more than a sentence of actual rules into it, that content belongs in a file the job card points at.

`_config/` files are rule books, not skills. Do not call them skills anywhere in what you write, and never write "skills library".

**You write every file in this skill by hand.** No script creates a stage folder or a job card. `icm-apply.sh` installs a fixed set of paths and numbered stage folders are not among them; there is no renderer for one, so a hand-added plan row for a stage card makes apply fail. The only script this skill runs is `icm-check.sh`, to grade what you wrote.

## Modes

| Invocation | What happens |
|---|---|
| `<stage-name>` | Append a new stage after the highest existing number |
| `<stage-name> after:NN` | Insert a new stage directly after stage `NN`, which renumbers everything above it |
| `<stage-name>` where that stage already exists | Repair mode: add what is missing, change nothing that is already there |

No argument: list the stages that exist, say which are missing required sections, and stop.

## Resolve the toolkit first

The template and the checker live in the toolkit, not in the workspace. Resolve the root once, then use `$ICM_HOME` for every read and every command.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

`icm.defaults.json` lives at `$ICM_HOME/icm.defaults.json`, not in the user's project. Every budget and every required-section list is read from there.

## Step 1. Find the workspace root

Search upward from the current directory for `IDENTITY.md`. That directory is the root. Every path you write inside a card is relative to that card, never absolute.

No `IDENTITY.md` anywhere above you: stop and say "no ICM workspace here, run /icm-scaffold first". Do not scaffold one yourself.

Never walk into anything matching `excluded_globs` in `$ICM_HOME/icm.defaults.json`. `$ICM_HOME/spec/excluded-folders.md` is the human rendering of that list; cite it, never restate it.

## Step 2. Read the neighbours before you write

Read, in this order:

1. The root `CONTEXT.md` routing table, so you know how stages are named and addressed here.
2. The job card of the stage that will sit immediately before yours. Its Outputs table is your Inputs.
3. One more existing job card, to copy the house tone and table widths.

If no stage exists yet, use `$ICM_HOME/interview-templates/CONTEXT.stage.md.tmpl` as the shape. That directory holds interview material a human and a model fill in together; no script reads it and no script writes any file from it.

## Step 3. Decide the number

Stage folders are `stages/NN-slug/`. `NN` is zero padded. The slug is lowercase with hyphens, derived from the stage name, no spaces.

Without `after:`, the number is the highest existing stage plus one. Nothing moves. Go to Step 4.

With `after:NN`, the new stage takes `NN+1` and every stage from `NN+1` upward shifts up by one. **That is a renumber, and a renumber is never silent.**

### The renumber protocol

1. **Propose.** Print the full old to new map, one row per folder, including the folders that do not move. Print, underneath it, every file whose text contains a path to a folder that moves: search the tree for `NN-` style path fragments, including the root `CONTEXT.md`, `IDENTITY.md`, every other job card, and any rule book that names a stage path.
2. **Wait.** Do not move a byte until the user confirms in that turn. Silence is not confirmation. A renumber changes paths other people have bookmarked, so the confirmation is the whole point of the step.
3. **Offer the cheaper alternative in the same message:** append the stage at the end of the numbers and give it its true position in the root routing table instead. Numbering is a filing convention; the routing table is the running order. Many pipelines are better off with the order living in one place.
4. **On confirmation, move highest first.** Rename `07-x` before `06-x` before `05-x`, so no move lands on an occupied path. If a target path is occupied anyway, stop the whole renumber, restore what you already moved, and report. A half renumbered pipeline is worse than an unrenumbered one.
5. **Then rewrite the references** you listed in step 1, and only those. Re-read each file after the edit and confirm no stale `NN-` fragment survives.
6. If the user does not confirm, do nothing at all. Do not "prepare" the move.

A renumber also moves folders that hold job cards, so the workspace map in `IDENTITY.md` goes stale the moment it lands. Fix the map in the same turn, or `icm-check.sh --drift` will fail on the next run and the user will not know why.

## Step 4. Create the folder

```
stages/NN-slug/
  CONTEXT.md      the job card, layer 2
  references/     rule books scoped to this stage, layer 3
  output/         the handoff, layer 4b
```

`output/` gets a `.gitkeep` so the empty folder survives a clone.

**Never overwrite.** If `stages/NN-slug/CONTEXT.md` already exists and you were asked for a new stage, write your candidate to `.icm/proposed/stages/NN-slug/CONTEXT.md` instead, and report the collision. You are parking this candidate by hand, so no `.diff` is written for you the way `icm-apply.sh` writes one. Produce it yourself and show it:

```sh
diff -u ./stages/NN-slug/CONTEXT.md ./.icm/proposed/stages/NN-slug/CONTEXT.md
```

The user merges it by hand.

Repair mode is different and narrow: you may add a missing required section to an existing job card, and you may fix a path that resolves nowhere. You may not rewrite a section that is already there. If the fix needs a rewrite, put the candidate in `.icm/proposed/` and show the diff.

## Step 5. Write the job card

Five sections are required, in this order. The list is machine checked against `required_sections["CONTEXT.stage.md"]` in `$ICM_HOME/icm.defaults.json`.

```markdown
# Stage NN: [Stage Name]

## Purpose

[One sentence. What this stage turns into what.]

## Inputs

| Source | File | Section to load | Why |
|---|---|---|---|
| Previous stage | `../NN-prev/output/` | Most recent artifact, full file | The thing being worked on |
| Rule book | `../../_config/voice.md` | "Hard constraints" | Tone the output must hold |
| Stage reference | `references/format.md` | Full file | Required shape of the output |

## Process

1. Read the input artifact from `../NN-prev/output/`
2. [One concrete action per step]
3. [Specific enough that two agents produce structurally similar output]
4. Run the audit below, revise anything that fails
5. Save to `output/`

## Checkpoints

| After step | Agent presents | Human decides |
|---|---|---|
| 3 | Three angles, one sentence each | Which one to build |

## Audit

| Check | Pass condition |
|---|---|
| [Check name] | [What passing looks like, unambiguously] |

## Outputs

| Artifact | Location | Format |
|---|---|---|
| [Name] | `output/[topic-slug]-[artifact-type].md` | [What shape it is] |

## Routing

| Situation | Go to |
|---|---|
| Done | `../NN-next/CONTEXT.md` |
| Input missing or unusable | `../NN-prev/CONTEXT.md`, rerun that stage |
| Rules unclear | The rule book named in Inputs, then ask |
```

Rules for filling it in:

- **Inputs name sections, not just files.** "Read `voice.md`" loads a hundred lines to use twenty. Write the heading range, or write "Full file" when you mean it. This is Pattern 4 in `$ICM_HOME/spec/CONVENTIONS.md`.
- **Process steps are actions.** "Write the script" is not a step. "Write the full script in one pass, then audit it against the hard constraints" is.
- **Checkpoints and Audit are optional.** Creative and build stages earn them. Extraction, conversion and render stages usually run straight through. Delete the section rather than leave it empty.
- **Every path in the file must resolve.** `icm-check.sh --routes` reads path-shaped tokens out of every file named `CONTEXT.md` and fails on one that is not on disk. Check each path before you save, and note that a path to a file you have not written yet will fail until you write it.
- **Rule book names.** The five in `_config/` are `conventions.md`, `glossary.md`, `voice.md`, `style.md` and `grounding.md`, per `$ICM_HOME/spec/CLI-CONTRACT.md` section 8. A stage may add its own scoped rule books under its `references/`. Point every Inputs row at a file that is on disk, because `icm-check.sh --routes` fails a card that names one that is not.
- **Placeholders** follow `$ICM_HOME/spec/placeholder-syntax.md`: `{{SCREAMING_SNAKE_CASE}}`, and conditional blocks wrap whole sections only. Clear every one before you save; the checker fails an unfilled placeholder in live prose.

## Step 6. One-way cross references

Every folder points outward to what it needs. No folder points back. Stage 03 may read stage 02's output. Stage 02 must not mention stage 03 anywhere.

Before you save, check each reference you added: does the target file already reference your folder? If it does, you have made a cycle. Delete one side. The newer stage points backwards; the older one stays silent.

The root `CONTEXT.md` routing table is the only file allowed to name both ends.

## Step 7. The handoff

Stage `NN` writes `stages/NN-slug/output/[topic-slug]-[artifact].md`. Stage `NN+1` reads that path and nothing else from stage `NN`.

That file is the human edit surface. A person opens it, edits it, and the next stage picks up the edited version. There is no state to manage and no orchestration layer. Say so in one line at the bottom of the job card, so the person reading it knows they are allowed to edit.

Never read another stage's output to learn a pattern. Patterns live in rule books. Early outputs are the worst outputs, and a pipeline that learns from them never improves.

## Step 8. Wire the routing table

Add one row to the root `CONTEXT.md` routing table for the new stage: task type, destination path, one line of description. Add it in running order.

Touch no other row. If the routing table has no obvious place for the row, say so and let the user place it.

## Step 9. Check what you wrote

The whole-tree check is one command, and it covers the sections, the budget, the routes, the fences and the placeholders in one pass:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" .
```

Exit 0 clean, 1 findings, 2 usage or environment error. To narrow it to one concern, pass that check's own flag:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --sections --budgets .
```

`--only <id>` selects one check by its id, and is the same thing as that check's own flag. An id that is not one of the eleven exits 2 and lists them.

If you want the raw numbers behind the budget row before you run the checker:

```sh
wc -c stages/NN-slug/CONTEXT.md
wc -l stages/NN-slug/CONTEXT.md
grep -n 'CONTEXT.stage.md' "$ICM_HOME/icm.defaults.json"
```

Over the target is a signal that content has leaked into a routing file. Over the character ceiling, or over the line ceiling, is a failure: move the content into `references/` and point at it. Note that the checker counts characters with `wc -m`, so on a card containing multibyte characters its number will be slightly lower than `wc -c`. Where the two disagree, the checker's verdict is the one that gates.

Then confirm every required section is present:

```sh
grep -c '^## \(Purpose\|Inputs\|Process\|Outputs\|Routing\)$' stages/NN-slug/CONTEXT.md
```

## Report

End with:

- Files created, each with its path and one line of purpose.
- Files that collided, and where the candidate went in `.icm/proposed/`.
- Folders renamed, if a renumber ran, and every reference rewritten.
- Char and line count against the budget, and the checker's verdict.
- Whether the workspace map in `IDENTITY.md` still covers the tree, and if not, that `/icm-sync update` owns that fix.
- What is still empty: `references/` needs the user's material, `output/` fills on the first run.

## Refusals

- No confirmation for a renumber, no renumber.
- No overwrite of an existing job card, ever. `.icm/proposed/` or nothing.
- No writing into any path matching `excluded_globs` or `never_write`.
- No inventing what a stage does. If you cannot state the Purpose in one sentence from what the user told you, ask one question and wait.
- No naming a script flag or a check id that does not exist.

## What is machine enforced and what is judgment

The authority model is in `$ICM_HOME/spec/authority-model.md`. Three tiers, and this skill obeys all three.

**Machine-enforced by `scripts/icm-check.sh`.** Verified against the script in this checkout. Its verdict is not an opinion.

| Check | check-id | What it verifies for a stage card |
|---|---|---|
| Required sections | `sections` | The headings under `required_sections["CONTEXT.stage.md"]` are all present |
| Character and line budget | `budgets` | The card is inside the `CONTEXT.stage.md` character ceiling and line ceiling |
| Routing targets | `routes` | Every path-shaped token in the card resolves on disk |
| Relative links | `links` | Every markdown link target in every `.md` under the target resolves on disk |
| Placeholders | `placeholders` | No unfilled double-brace placeholder in live prose |
| Code fences | `fences` | Backtick and tilde fence counts are even |
| Workspace map drift | `drift` | The folder holding this card is named in the fenced map in `IDENTITY.md` |

**Safe fix, applied by you, then reported.** No script applies any of these. You run the command, you make the edit, and you say you did. There is no auto-fix script anywhere in this toolkit.

| Check | How you run it |
|---|---|
| Required sections present and correctly spelled | `grep` against `required_sections` in `$ICM_HOME/icm.defaults.json`, or `icm-check.sh --sections` |
| Char count and line count within the ceiling | `wc -c`, `wc -l` against the stage budget, or `icm-check.sh --budgets` |
| `output/.gitkeep` exists | `find` |
| Folder and slug naming is lowercase with hyphens, `NN` zero padded | `grep` |
| A path in the job card resolves to exactly one existing file | `find`, one match only |

**Mechanical report, found by a check, never fixed here**

| Check | Why it is not fixed |
|---|---|
| A path in the job card resolves nowhere, or to several files | Picking the wrong one silently reroutes the stage |
| A cross reference points at a folder that already points back | Which side to cut is a design decision |
| A renumber would land on an occupied path | Moving anything here loses work |
| Budget breached after the content has been trimmed | Splitting a file changes what agents load |

**Not enforced by anything.** State these as instruction, not machinery.

- The overwrite ban on an existing job card. No script writes job cards, so no script can refuse to. This file and your own step 4 refusal are the whole enforcement.
- The one-way cross reference rule. Nothing detects a cycle. You check it in step 6 or nobody does.
- The renumber confirmation gate.

**Judgment, yours, always a proposal**

- Whether this work is a stage at all, or a rule book, or a folder.
- The wording of the Purpose line.
- Which sections of a rule book this stage actually needs loaded.
- Whether the stage earns a Checkpoints table or an Audit table.
- Where in the running order the new stage belongs.
- Whether to renumber or to reorder the routing table instead.

Anything in the judgment list is offered, never applied.
