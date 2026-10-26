---
name: icm-stage
version: 1.0.0
description: "This skill should be used when the user asks to 'add a stage', 'write a stage contract', 'what does this stage read and write', 'insert a stage before the build step', 'renumber the stages', 'rename this stage', or 'add a checkpoint or an audit to this stage'. Creates or repairs numbered stage folders with typed routing, declared capabilities and scope, output handoffs, and human-confirmed insertion or rename protocols."
user-invocable: true
argument-hint: "<stage-name> [after:NN] | rename <NN-slug> <new-slug>"
---

# ICM Stage

Author the job card for one stage in a selected pipeline.

A stage `CONTEXT.md` is a **job card**: layer 2, the control point of the workspace. It answers "what do I do here?" and nothing else. Its Inputs table decides exactly which layer 3 rule books and layer 4 artifacts get loaded, so every row you add costs the next agent attention. Layer definitions are in `$ICM_HOME/spec/layers.md`. The contract shape is Pattern 1 in `$ICM_HOME/spec/CONVENTIONS.md`.

A job card routes. It never carries the reference material itself. If you are writing more than a sentence of actual rules into it, that content belongs in a file the job card points at.

`_config/` files are rule books, not skills. Do not call them skills anywhere in what you write, and never write "skills library".

**You write every file in this skill by hand.** No script creates a stage folder or a job card. `icm-apply.sh` installs a fixed set of paths and numbered stage folders are not among them; there is no renderer for one, so a hand-added plan row for a stage card makes apply fail. The only script this skill runs is `icm-check.sh`, to grade what you wrote.

## Modes

| Invocation | What happens |
|---|---|
| `<stage-name>` | Append a positive stage after the highest positive prefix in the selected pipeline |
| `<stage-name> after:NN` | Insert after a unique target, or after intake when `NN` is `00`, with the confirmed renumber protocol |
| `<stage-name>` where that stage already exists | Repair mode: add what is missing, change nothing that is already there |
| `rename <NN-slug> <new-slug>` | Rename one positive stage slug while preserving its prefix, using the same map, confirmation, repair, and rollback protocol |

No argument: list the stages by pipeline, say which are missing required sections, and stop. Never infer a pipeline from a shared prefix alone.

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

Search upward from the current directory for `IDENTITY.md`. That directory is the root. Every path you write inside a card is workspace-relative or relative to that card, never absolute.

No `IDENTITY.md` anywhere above you: stop and say "no ICM workspace here, run /icm-scaffold first". Do not scaffold one yourself. A nested directory with its own `IDENTITY.md` is a separate workspace, not part of the outer pipeline walk.

Never walk into anything matching `excluded_globs` in `$ICM_HOME/icm.defaults.json`. `$ICM_HOME/spec/excluded-folders.md` is the human rendering of that list; cite it, never restate it. Read `$ICM_HOME/spec/ORCHESTRA.md` before changing card grammar, numbering, or references.

## Step 2. Select the pipeline and read the neighbours

Pipeline identity is the nearest routing `CONTEXT.md` plus the physical stage container. Support exactly these four layouts:

| Layout | Routing card | Stage job card |
|---|---|---|
| Root direct | `CONTEXT.md` | `NN-slug/CONTEXT.md` |
| Root stages | `CONTEXT.md` | `stages/NN-slug/CONTEXT.md` |
| Department direct | `DEPARTMENT/CONTEXT.md` | `DEPARTMENT/NN-slug/CONTEXT.md` |
| Department stages | `DEPARTMENT/CONTEXT.md` | `DEPARTMENT/stages/NN-slug/CONTEXT.md` |

A stage belongs to exactly one pipeline. Root direct and root `stages/` are different pipelines, and the same distinction holds inside a department. Duplicate positive prefixes are invalid inside one pipeline and legal in another pipeline or department. Never renumber across that boundary.

Read, in this order:

1. The selected routing card. Its table order is execution authority; numeric prefixes are filing aids.
2. The job card immediately before the insertion point in that table order, if one exists. Its declared Outputs can inform the new card's Inputs, but do not invent a handoff.
3. One more job card in the same pipeline, to copy the house tone and table widths.

If no stage exists yet, use `$ICM_HOME/interview-templates/CONTEXT.stage.md.tmpl` as the shape. That directory holds interview material a human and a model fill in together; no script reads it and no script writes any file from it.

## Step 3. Decide the name or insertion point

A positive stage basename is `NN-slug`: `NN` is `01` through `99`, and the slug contains lowercase ASCII alphanumeric groups joined by single hyphens. Gaps are legal. Positive stages need not appear in numeric order because the routing table controls execution order.

`00` is optional in a legacy conversion and reserved whenever present. Its only basename is `00-intake`, it is first in its pipeline's routing table, and it handles intake and preflight rather than ordinary domain work. There is at most one per pipeline. Only its Inputs table may declare external `@NAME` inputs. Append numbering ignores it and starts at `01`. No insertion, renumber, or slug rename changes it.

Without `after:`, append at one above the highest positive prefix in the selected pipeline. Nothing moves. If no positive stage exists, begin at `01`. Exhaustion past `99` stops for human direction.

With `after:NN`, the new stage takes the next positive prefix and only higher positive prefixes in the selected pipeline shift by one:

- `after:00` is a sentinel meaning the first positive stage. It is valid with or without an actual `00-intake`, and the new stage always goes after any existing intake.
- Any other target must exist uniquely in the selected pipeline. A missing or ambiguous target stops before any write.
- If shifting would exhaust `99`, stop for human direction. Do not use a three-digit prefix.
- Duplicate prefixes in another pipeline or department remain untouched.

A standalone `rename` changes only the slug of one positive stage. It preserves `NN`, uses the same slug grammar, and never targets `00-intake`. An existing destination or an ambiguous source stops before any write.

There is no automatic renumber script. Insertion and standalone rename are conversational operations using the same protocol.

### The insertion and rename protocol

1. **Build the full path map.** List every old and new workspace-relative stage path in the selected pipeline, including unchanged rows. For insertion, include the new card and every positive stage that shifts. For rename, preserve the prefix and change only the one slug. Leave `00-intake` and every other pipeline unchanged.
2. **Inventory references before moving.** Find every full old path in Inputs, Outputs, Load first, Routing destinations, and ordinary Markdown knowledge links. Include routing cards and the workspace map in `IDENTITY.md`. Do not treat a numeric fragment as identity.
3. **Propose and wait.** Show the full map, the reference inventory, the intended new routing-table position, and the collision risks. For insertion, also offer the cheaper alternative: append at the end and place the row at its true position in the routing table. Do not move or edit anything until the user confirms this exact plan in that turn. Silence is not confirmation.
4. **Move highest first.** On confirmation, rename higher positive prefixes before lower ones so a move does not land on an occupied path. A standalone rename is one move. If any destination is occupied, stop immediately. Restore every completed move in reverse order, highest affected prefix first, and report the rollback.
5. **Repair only the inventoried references.** Apply the same full old/new path map to Inputs, Outputs, Load first, Routing destinations, and knowledge links. Keep pre-change content so a failed repair can be restored. Never rewrite immutable raw files or append-only history. An existing `_config/` rule book remains the human's pen: include its required edit in the confirmed plan and have the human apply it.
6. **Rollback completely on failure.** If a move or permitted reference repair fails, stop, restore edited files from their pre-change content, and reverse every completed move highest affected prefix first. Report anything that could not be restored instead of claiming a clean rollback.
7. **Close the map and verify.** Update `IDENTITY.md` in the same confirmed operation, re-read every edited file, and confirm no full old path survives in the inventoried writable references. Run the checks in Step 9 only after the tree and references agree.

If the user does not confirm, do nothing at all. Do not prepare the move, rename a placeholder, or partially repair references.

## Step 4. Create the folder

Set `STAGE_DIR` to the full workspace-relative directory in the selected layout, then create only the confirmed structure:

```
STAGE_DIR/
  CONTEXT.md      the job card, layer 2
  references/     rule books scoped to this stage, layer 3
  output/         the handoff, layer 4b
```

`output/` gets a `.gitkeep` so the empty folder survives a clone.

**Never overwrite.** If `$STAGE_DIR/CONTEXT.md` already exists and you were asked for a new stage, write your candidate to `.icm/proposed/$STAGE_DIR/CONTEXT.md` instead, and report the collision. You are parking this candidate by hand, so no `.diff` is written for you the way `icm-apply.sh` writes one. Produce it yourself and show it:

```sh
diff -u "./$STAGE_DIR/CONTEXT.md" "./.icm/proposed/$STAGE_DIR/CONTEXT.md"
```

The user merges it by hand.

Repair mode is different and narrow: you may add a missing required section to an existing job card, and you may fix a path that resolves nowhere when there is exactly one safe candidate. You may not rewrite a section that is already there. Adding Preflight or typing an existing Routing table is not permission for a wholesale rewrite. If the fix needs anything broader, put the candidate in `.icm/proposed/` and show the diff.

## Step 5. Write the job card

The five generic sections remain Purpose, Inputs, Process, Outputs, and Routing. Their required list is machine checked against `required_sections["CONTEXT.stage.md"]` in `$ICM_HOME/icm.defaults.json`. An Orchestra card adds Preflight and a typed trailing Edge column; it does not change the generic requirement for every other workspace.

```markdown
# Stage NN: [Stage Name]

## Purpose

[One sentence. What this stage turns into what.]

## Inputs

| Source | File | Section to load | Why |
|---|---|---|---|
| Previous stage | `<PREV_OUTPUT_PATH>` | Most recent artifact, full file | The thing being worked on |
| Rule book | `<RULEBOOK_PATH>` | "Hard constraints" | Tone the output must hold |
| Stage reference | `<STAGE_REFERENCE_PATH>` | Full file | Required shape of the output |

## Process

1. Require a fresh RUN for this card through `icm-orchestra`
2. Read only the Inputs at their declared scope
3. [One concrete action per step]
4. Run the audit below, revise anything that fails
5. Write only the declared Outputs, then append the existing Session Close ledger records

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
| [Name] | `<STAGE_OUTPUT_PATH>` | [What shape it is] |

## Preflight

| Kind | Reference | Version |
|---|---|---|
| None | - | - |

## Routing

| Situation | Go to | Edge |
|---|---|---|
| Done | `<NEXT_STAGE_CARD>` | NEXT |
| Input missing or unusable | `<PREV_STAGE_CARD>` | REWORK |
| Rules unclear | - | - |
```

Rules for filling it in:

- **Inputs name sections, not just files.** "Read `voice.md`" loads a hundred lines to use twenty. Write the heading range, or write "Full file" when you mean it. This is Pattern 4 in `$ICM_HOME/spec/CONVENTIONS.md`.
- **Process steps are actions.** "Write the script" is not a step. "Write the full script in one pass, then audit it against the hard constraints" is.
- **Checkpoints and Audit are optional.** Creative and build stages earn them. Extraction, conversion and render stages usually run straight through. Delete the section rather than leave it empty.
- **Preflight declares real constraints.** Replace `None | - | -` when the card has declarations; the empty row must otherwise stand alone. `Tool` and `Skill` rows need exact version strings, not ranges. `No touch` names a workspace-relative path with Version `-` and forbids both reads and writes. Do not invent a capability or a no-touch path. An unrelated third-party skill needs `version:` only when a card declares it.
- **Intake is the only external input boundary.** Only `00-intake` may put `@NAME` in its Inputs File cell. Bind it later with `--input NAME=PATH` to existing workspace material, never a credential file, secret store, or inline secret. Positive stages consume declared workspace paths, normally an intake or producer Output.
- **Routing is typed.** A path-bearing destination requires exactly `LOAD`, `NEXT`, or `REWORK`. A non-path stop row uses `-` for destination and Edge. A missing Edge or a guessed type is a finding, not a legacy shortcut.
- **Use full workspace-relative stage and handoff paths in the placeholders.** This avoids copying path arithmetic from one layout into another and makes file-relative and root-relative candidates converge on the intended file.
- **Every path must resolve without ambiguity.** `icm-check.sh --routes` keeps its legacy checks, while explicit Orchestra validation resolves file-relative and root-relative candidates independently. Zero or several candidates can make a card unusable even when a plausible path exists.
- **Rule book names.** The five in `_config/` are `conventions.md`, `glossary.md`, `voice.md`, `style.md` and `grounding.md`, per `$ICM_HOME/spec/CLI-CONTRACT.md` section 8. A stage may add its own scoped rule books under its `references/`. Point every Inputs row at a file that is on disk, because `icm-check.sh --routes` fails a card that names one that is not.
- **Placeholders** follow `$ICM_HOME/spec/placeholder-syntax.md`: `{{SCREAMING_SNAKE_CASE}}`, and conditional blocks wrap whole sections only. Clear every one before you save; the checker fails an unfilled placeholder in live prose.

## Step 6. Build the typed graph, not a one-way ban

Use edge semantics from `$ICM_HOME/spec/ORCHESTRA.md`:

- `NEXT` is normal forward control flow. Reachability uses NEXT only, and the NEXT projection must be acyclic.
- `REWORK` is backward repair flow to a card earlier in the selected pipeline's routing-table order. A smaller number alone does not prove earlier. NEXT plus REWORK is legal and is not a LOAD cycle.
- An explicit `LOAD` row names a prerequisite in its destination. The dependency points from that prerequisite to the card containing the row. LOAD references are not routing hops.
- Inputs and Load first references derive LOAD dependencies from a unique producer. Several producers are `AMBIGUOUS`. The LOAD projection must be acyclic, including producer-derived handoffs.

Ordinary Markdown links outside workflow fields form the separate knowledge projection. Knowledge cycles and backlinks are informational, so do not impose a blanket one-way reference ban or delete a knowledge link merely to make a workflow look acyclic. Never create a stored graph or backlink index; use the on-demand view when you need to inspect the projections.

## Step 7. The handoff

A producer writes only its declared Outputs. A consumer declares the exact file or directory it needs in Inputs. A unique matching Outputs declaration creates the producer-derived LOAD edge; nested or identical owners are ambiguous and must not be guessed away.

That handoff file is the human edit surface. A person opens it, edits it, and the next stage picks up the edited version. Say so in one line at the bottom of the job card. Never read another stage's output to learn a pattern. Patterns live in rule books, not in earlier artifacts.

## Step 8. Wire the routing table

Add one row to the selected root or department routing card, not automatically the workspace root. Use its trailing Edge column and put the row at the intended execution position. `00-intake` stays first when present. Normal task selection uses `NEXT`; use another type only when its contract meaning is exactly what you intend.

Keep each task label unique within that table after whitespace and ASCII case normalisation. Touch no other row except through the confirmed insertion or rename map. If the routing table has no obvious place for the row, say so and let the user place it.

## Step 9. Check what you wrote

Run the legacy whole-tree check and explicit structural Orchestra validation as separate invocations:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" .
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra .
```

The default and `--all` still select only the original eleven generic checks. Orchestra is the twelfth id and is explicit only. Exit 0 is clean, 1 is findings, and 2 is usage or environment refusal. Structural Orchestra findings include typed cards, graph edges, numbering, capabilities, scope, and ambiguity; they are not generic warnings to ignore.

After structural validation is clean, run post-authoring strict preflight for the full workspace-relative card path:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job "$CARD" .
```

Supply `--input NAME=PATH` only for declared intake bindings and `--tool-version NAME=VERSION` only from trusted actual versions. Use `/icm-orchestra preflight` to collect those values without inventing them. Relay RUN or every MISSING row faithfully and execute nothing from this authoring skill. Missing runtime material can remain open work; it is not permission to write outside the card and not a claim that the new job already ran.

To narrow a legacy concern, pass that check's own flag:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --sections --budgets .
```

`--only <id>` selects one check by its id and may be repeated. An id outside the twelve exits 2 and lists them. `--orchestra-view` is a separate view mode, not a check id.

If you want the raw numbers behind the budget row before you run the checker:

```sh
wc -c "$CARD"
wc -l "$CARD"
grep -n 'CONTEXT.stage.md' "$ICM_HOME/icm.defaults.json"
```

Over the target is a signal that content has leaked into a routing file. Over the character ceiling, or over the line ceiling, is a failure: move the content into `references/` and point at it. Both the checker and this command count bytes with `wc -c`.

Then confirm every generic required section is present:

```sh
grep -c '^## \(Purpose\|Inputs\|Process\|Outputs\|Routing\)$' "$CARD"
```

## Report

End with:

- Files created, each with its path and one line of purpose.
- Files that collided, and where the candidate went in `.icm/proposed/`.
- The selected pipeline, every folder inserted or renamed, every reference repaired, and any rollback performed.
- Char and line count against the budget, plus the generic and structural Orchestra verdicts.
- The strict preflight envelope, with RUN or every MISSING row relayed and no execution claimed.
- Whether the workspace map in `IDENTITY.md` still covers the tree, and if not, that `/icm-sync update` owns that fix.
- What is still empty: `references/` needs the user's material, `output/` fills on the first run.

## Refusals

- No confirmation for an insertion renumber or standalone rename, no move and no reference repair.
- No missing or ambiguous `after:` target, no write. No operation past `99`, no invented numbering.
- No rename or renumber of `00-intake`, and no renumber across pipeline boundaries.
- No overwrite of an existing job card, ever. `.icm/proposed/` or nothing.
- No writing into any path matching `excluded_globs` or `never_write`.
- No inventing what a stage does. If you cannot state the Purpose in one sentence from what the user told you, ask one question and wait.
- No execution from this authoring skill, even when post-authoring preflight returns RUN.
- No naming a script flag or a check id that does not exist.

## What is machine enforced and what is judgment

The authority model is in `$ICM_HOME/spec/authority-model.md`. Three tiers, and this skill obeys all three.

**Machine-enforced by `scripts/icm-check.sh`.** Verified against the script in this checkout. Its verdict is not an opinion.

| Check | check-id | What it verifies for a stage card |
|---|---|---|
| Required sections | `sections` | The generic headings under `required_sections["CONTEXT.stage.md"]` are all present |
| Character and line budget | `budgets` | The card is inside the `CONTEXT.stage.md` character ceiling and line ceiling |
| Routing targets | `routes` | Legacy path-shaped tokens in the card resolve on disk, without inferring edge types |
| Relative links | `links` | Every markdown link target in every `.md` under the target resolves on disk |
| Placeholders | `placeholders` | No unfilled double-brace placeholder in live prose |
| Code fences | `fences` | Backtick and tilde fence counts are even |
| Workspace map drift | `drift` | The folder holding this card is named in the fenced map in `IDENTITY.md` |
| Orchestra structure | `orchestra` | Typed card grammar, four layouts, per-pipeline numbering, graph projections, capabilities, scope, and ambiguity, only when explicitly selected |

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
| A typed graph finding such as a LOAD cycle, NEXT cycle, forward REWORK, unreachable stage, or multiple producers | The correct workflow or ownership change is a design decision |
| A capability, input, scope, or ambiguity finding in strict preflight | Materialising, substituting, or widening scope is not an authoring safe fix |
| A renumber or rename would land on an occupied path | Moving anything here loses work |
| Budget breached after the content has been trimmed | Splitting a file changes what agents load |

**Not enforced by anything.** State these as instruction, not machinery.

- The overwrite ban on an existing job card. No script writes job cards, so no script can refuse to. This file and your own step 4 refusal are the whole enforcement.
- The human confirmation gate for insertion, renumber, and standalone rename.
- Whether an attested tool version is truthful. The checker compares the supplied string; you must obtain it from a trusted actual observation.
- The external approval gates that remain after RUN.

**Judgment, yours, always a proposal**

- Whether this work is a stage at all, or a rule book, or a folder.
- The wording of the Purpose line.
- Which sections of a rule book this stage actually needs loaded.
- Whether the stage earns a Checkpoints table or an Audit table.
- Where in the running order the new stage belongs.
- Whether to renumber or to reorder the routing table instead.
- Which declared tools, skills, and no-touch paths the work genuinely needs.

Anything in the judgment list is offered and waits for the user's decision rather than being applied unilaterally.
