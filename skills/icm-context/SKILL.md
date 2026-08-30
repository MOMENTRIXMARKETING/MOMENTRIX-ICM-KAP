---
name: icm-context
description: "This skill should be used when the user asks to 'fill the context gaps', 'which folders are missing a CONTEXT.md', 'add job cards', 'this folder has no context file', 'complete layer 2 coverage', or names 'icm-context'. It walks the tree honouring the excluded globs in icm.defaults.json, finds folders that warrant a job card and lack one, and writes them from the interview templates. It never overwrites an existing CONTEXT.md."
user-invocable: true
argument-hint: "report | create"
---

# ICM Context

Fill the layer 2 gaps. Layer 2 is the job card: the `CONTEXT.md` inside a folder that answers "what do I do here". It is the control point of the whole system, because its Inputs table decides exactly which layer 3 and layer 4 files get loaded. A folder that does real work and has no job card is a folder where every agent that walks in has to guess.

This skill finds those folders and writes the missing cards. It does one thing and it does not do the neighbouring things: it does not repair drift, that is `skills/icm-sync/SKILL.md`, and it does not stand up layers 0, 1 or 3, that is `skills/icm-scaffold/SKILL.md` or `skills/icm-retrofit/SKILL.md`.

**Job cards are written here, by hand, one at a time, with a human.** No script writes one. `icm-apply.sh` installs a fixed set of paths and there is no renderer for `<folder>/CONTEXT.md`; adding a row for one to a plan makes apply fail with `FAIL no renderer for <path>`. Naming a folder honestly is judgment, not classification, which is why it lives in a conversation and not in a script.

| Mode | Behaviour |
|---|---|
| `report` | Walk, decide, list every gap and every skip with its reason. Create nothing. |
| `create` | Everything `report` does, then write the missing cards. |

Default with no argument: `report`. You show the list before you write the files.

## Resolve the toolkit first

The templates and the checker live in the toolkit, not in the workspace you are filling in. Resolve the root once, then use `$ICM_HOME` for every read and every command.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

## Read before you walk

| File | Why |
|---|---|
| `$ICM_HOME/spec/CLI-CONTRACT.md` | The command names, artifact paths and vocabulary. Authoritative over this file. |
| `$ICM_HOME/spec/excluded-folders.md` | The human rendering of `excluded_globs`. This is the only skip list. Never restate it, never extend it inline, cite it. |
| `$ICM_HOME/spec/budgets.md` | The ceilings for `CONTEXT.folder.md` and `CONTEXT.stage.md`. Never state a budget as a number in your prose. |
| `$ICM_HOME/spec/layers.md` | What layer 2 is for, and what belongs in layer 3 instead. |
| `$ICM_HOME/spec/CONVENTIONS.md` | The stage contract shape, one-way cross references, routing not content. |
| `$ICM_HOME/icm.defaults.json` | `required_sections` for `CONTEXT.stage.md`, `excluded_globs`, and `never_write`. |

## Step 1: Find the root

Search upward from the working directory for `IDENTITY.md`. No `IDENTITY.md`: stop and say "no ICM workspace found. Run `/icm-scaffold` on an empty root, or `/icm-retrofit plan` on a live project." Do not create one.

## Step 2: Learn the house style

Read two or three existing `CONTEXT.md` files before writing anything: the root one, and any folder card that already exists. Match what you find. A workspace where half the cards are terse and half are chatty is worse than a workspace with fewer cards.

If the root card is the only one that exists, use the templates as written and keep the tone of `IDENTITY.md`.

## Step 3: Walk the tree

If a retrofit has already run here, `scripts/icm-plan.sh` printed a survey of the same tree and wrote one `SURVEY` row per folder into `.icm/plan.txt`, each carrying a verdict of `has-card`, `staged`, `card` or `none`. Read it if it is there. It is evidence gathered by a script and it saves you a pass, but it decides nothing: the warrant test below is still yours, and a `staged` verdict is a signal that a folder might be a stage, never proof that it is one.

Walk from the root, skipping every directory whose name matches an `excluded_globs` entry in `icm.defaults.json`. Excluded folders are not walked, not counted, and not listed as skips beyond a single summary line. They are not part of the workspace.

Collect, for every folder that survives the walk: its path, its depth, its file count, its subfolder count, whether it holds a `CONTEXT.md`, whether it holds another routing convention, and whether `IDENTITY.md` names it.

## Step 4: The warrant test

A folder warrants a job card when it holds work. Both halves of this test must pass.

**It has to earn one.** At least one of:

- `IDENTITY.md` names it in the workspace map.
- It carries a stage marker: a numbered prefix, or a name that reads as a step in the workflow.
- It holds three or more files that are worked on rather than stored.
- It holds subfolders that themselves hold work.
- It has an `output/` of its own, which means something is produced there.
- Its parent card points at it as a destination.

**And it has to be missing one.** All of:

- No `CONTEXT.md` already.
- No other routing convention already doing the job: a `CLAUDE.md`, an `_index.md`, or a `README.md` that genuinely routes rather than describes.
- Its parent's job card does not already describe it completely. A leaf `output/` or `references/` folder under a documented stage does not need its own card. Two cards for one job is drift waiting to happen.

**Never, regardless of the above:**

- Anything under a folder matching `excluded_globs`.
- Anything inside a `never_write` glob from `icm.defaults.json`.
- `raw/`, which is immutable and describes itself by being immutable.
- An empty folder, or a folder holding one file. It is not a project yet.
- A pure asset store: images, exports, binaries, downloads. Nothing is decided there.
- A vendored library or somebody else's repo living inside this one.
- A folder that has its own `IDENTITY.md`. That is a sub-workspace with its own root, and it goes to `skills/icm-retrofit/SKILL.md`, not here.

When the test is genuinely ambiguous, list the folder as **needs classification** and ask. Do not skip it silently and do not invent a purpose for it. Silence is how a folder disappears from a workspace map for a year.

## Step 5: Pick the card kind

| Folder kind | Template | Shape |
|---|---|---|
| Stage folder: numbered, or a named step in the pipeline | `$ICM_HOME/interview-templates/CONTEXT.stage.md.tmpl` | The stage contract. Every heading listed under `required_sections["CONTEXT.stage.md"]` in `icm.defaults.json` is mandatory |
| Working folder: holds real work, is not a pipeline stage | `$ICM_HOME/interview-templates/CONTEXT.folder.md.tmpl` | Purpose, contents, routing |
| Container folder: holds other folders and nothing else | `$ICM_HOME/interview-templates/CONTEXT.folder.md.tmpl`, routing section dropped | Purpose and a contents table. A container that routes is just a duplicate index |
| Reference folder: layer 3 material, ten or more files | `$ICM_HOME/interview-templates/CONTEXT.folder.md.tmpl` | Purpose plus a summary table, one row per file. This is the index that keeps layer 3 cheap to load |

Every card whose filename is `CONTEXT.md` is measured against the stage budget and the stage required sections by the checker, whatever kind you decided it is. If you write a folder card that omits the stage headings, `icm-check.sh --sections` will fail it. Either write the five headings or expect the finding and own it in your report.

## Step 6: Write the card

For each folder that warrants one:

1. **Read what is already there.** `README.md`, any doc that explains the folder, a `package.json`, a `Makefile`. Existing explanations outrank your inference every time.
2. **List the contents from disk.** Not from memory, not from the parent card.
3. **Infer the purpose** from file names, from what `IDENTITY.md` says about it, and from what the parent card expects it to produce.
4. **Fill the template.** Replace every placeholder, then grep for a double open brace. Anything left is a question for the user, not a marker to delete.

**Content rules**

- **Do not invent.** Only what exists on disk or is documented nearby. An empty Inputs row is honest. A plausible fabricated one is not.
- **Route, do not teach.** A job card answers what is this folder, what do I load, what is the process. It never holds the reference material itself. No definitions, no rules, no extended examples. If you are writing more than a sentence of explanation, that content belongs in a layer 3 file the card points at.
- **Be specific about sections.** An Inputs row says which part of a file to load, not just the file. "the Voice Rules section of `_config/voice.md`" costs the reader far less than the whole file.
- **Every path in the card must resolve.** `icm-check.sh --routes` reads path-shaped tokens out of every file named `CONTEXT.md` and fails on one that is not on disk. This is the one check that watches job cards closely, so use it.
- **Point outward only.** If the file you are referencing already references this folder, restructure rather than close the loop.
- **Stay under the ceiling** in `$ICM_HOME/spec/budgets.md`. A card over budget is a failing card, and the fix is cutting it, never raising the budget.
- **Three to five routing rows.** Cover the common tasks. A routing table that covers everything covers nothing.
- Lowercase folder names. No em dashes.

## Step 7: Collisions

**This skill never overwrites an existing `CONTEXT.md`. There is no flag, no mode, and no user instruction inside this skill that changes that.**

If a `CONTEXT.md` exists, the folder failed the warrant test at step 4 and you never generated a body for it. If you find one at write time that was not there at walk time, stop, do not write, and report the path.

If the user explicitly wants an existing card replaced, that is a collision and it follows the collision policy in `skills/icm-retrofit/SKILL.md`: your version goes to `.icm/proposed/<relative-path>`, the real file stays untouched, and a human merges after reading the diff. `icm-apply.sh` writes a `.diff` beside a candidate it parks, but you are parking this one by hand, so write the diff yourself:

```sh
diff -u ./drafts/CONTEXT.md ./.icm/proposed/drafts/CONTEXT.md
```

`.icm/` is only added to `.gitignore` by an apply run, so on a workspace that has never been applied to, `git status` will show it as untracked. Say so rather than letting the user find it.

You also never modify any file other than the cards you create. Not the parent card, not `IDENTITY.md`, not an index. If a created card is not reachable from the routing above it, that is a finding you report and hand to `skills/icm-sync/SKILL.md`.

## Step 8: Check what you wrote

In `create` mode, after writing:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" .
```

Exit 0 clean, 1 findings, 2 usage or environment error. To re-verify one fix, pass that check's own flag, for example `--sections` or `--routes`. There is no `--only` flag; passing one exits 2.

Every card you just wrote must pass. A card that fails its own check is a bug, not a warning: fix it and re-run. Findings against files you did not write are open work and you say so explicitly rather than letting them sit in the same list.

One finding you should expect and should not be surprised by: a new job card in a folder the workspace map does not mention makes `--drift` fail, because the map in `IDENTITY.md` must document every folder that holds a card. Adding the folder to the map is a `skills/icm-sync/SKILL.md` fix, not yours, so report it and route it.

## Step 9: Report

```
## ICM Context Report - YYYY-MM-DD
Mode: report | create
Root: <absolute path>
Folders walked: N   Excluded per icm.defaults.json: N

### Created (N)
- <folder>/CONTEXT.md - <kind> - <one line purpose>

### Gaps found, not yet created (N)     [report mode]
- <folder> - <kind it would be> - <why it warrants a card>

### Already routed (N)
- <folder> - has CONTEXT.md | CLAUDE.md | _index.md

### Skipped, no card needed (N)
- <folder> - empty | single file | asset store | covered by parent card | sub-workspace

### Needs classification (N)
- <folder> - <what is in it> - what is this folder for?

### Not reachable from routing (N)
- <folder>/CONTEXT.md - the parent card does not point here. Run /icm-sync update

### Check
sh "$ICM_HOME/scripts/icm-check.sh" . - PASS | N findings, listed above

### No gaps found
<if layer 2 coverage is already complete, say exactly that and stop>
```

`report` closes with "no files were changed. Run `/icm-context create` to write these."
`create` closes with "job cards written. Nothing existing was touched."

## Step 10: Log

One ledger line through `skills/icm-log/SKILL.md`, in the fixed format from `references/ledger.md` of `out-of-the-loop`:

```
| Date | Task | Tier | Anchor | Verify cycles | Holes: plan/hunt/review/audit | Workarounds | Call fired | Artifact |
```

Cards created goes in the artifact column. Needs-classification folders are holes, and they belong in the holes column, because a folder nobody can name is exactly the kind of gap that is cheap now and expensive later.

## Rules that do not bend

1. Never overwrite an existing `CONTEXT.md`. No exceptions, no flags.
2. Never modify a file other than the cards you create.
3. Never invent a purpose, an input, or a process. Unknown is a valid answer and a fabricated one is not.
4. Never write inside a folder matching `excluded_globs` or `never_write`.
5. Never put reference material in a job card. Layer 2 routes, layer 3 holds.
6. Never exceed the ceiling in `$ICM_HOME/spec/budgets.md`. Cut the card.
7. Never require python or node.
8. A folder you cannot classify gets asked about, never guessed at.
9. Never name a script flag or a check id that does not exist. Every one in this file was verified against the scripts in this checkout.

## Machine-enforced vs model judgment

Per `$ICM_HOME/spec/authority-model.md`. Every row below was verified against `scripts/icm-check.sh` in this checkout. Each check has a flag of the same name, and there is no `--only`.

**Machine-enforced.** `scripts/icm-check.sh` decides, and its verdict on a card you wrote is final.

| Check | check-id | What it actually verifies, for a job card |
|---|---|---|
| Required sections | `sections` | Every file named `CONTEXT.md` other than the root one carries the headings listed under `required_sections["CONTEXT.stage.md"]` in `icm.defaults.json` |
| Character budgets | `budgets` | Every non-root `CONTEXT.md` against the `CONTEXT.stage.md` character ceiling and line ceiling in `icm.defaults.json`. Over target warns, over ceiling fails |
| Routing targets | `routes` | Every path-shaped token, backticked or in a markdown link, inside every `CONTEXT.md`, resolves relative to the card or to the root |
| Placeholders | `placeholders` | No unfilled double-brace placeholder survives in live prose, outside any `*.tmpl` file and outside code fences and backticks |
| Code fences | `fences` | The card's backtick and tilde fence counts are even |
| Workspace map drift | `drift` | Every folder that holds a job card is named in the fenced workspace map in `IDENTITY.md` |

**Not checked by anything.** The overwrite ban is one of these, so state it as instruction and not as machinery.

- The ban on overwriting an existing `CONTEXT.md` is enforced by this file and by your own step 7 refusal. No script stands between you and that file, because no script writes job cards at all.
- A dead relative link outside a `CONTEXT.md`. `routes` only walks files named `CONTEXT.md`.
- A write proposed inside a `never_write` glob or an excluded folder. That refusal lives in `icm-plan.sh` and `icm-apply.sh`, never in the checker, which is report-only and never proposes a write. Your step 4 exclusions are the enforcement here.

**Model judgment.** No script can answer these. They are yours, and the ambiguous ones become questions rather than decisions.

- Whether a folder holds work or just holds bytes. That is the warrant test, and it is a reading, not a measurement.
- Whether a folder is a pipeline stage or just a folder with a number in its name.
- Whether an existing `README.md` genuinely routes, which makes the card unnecessary, or merely describes, which does not.
- Whether the parent card already covers this folder well enough.
- What the folder is actually for, when nothing on disk says.
- Which three to five tasks belong in the routing table.
- Which section of a referenced file the Inputs row should name.
- Every word you write.

**Neither.** You do not decide that an existing card is bad and replace it. That is a collision, it goes to `.icm/proposed/`, and a human merges it.
