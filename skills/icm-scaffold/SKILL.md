---
name: icm-scaffold
description: "This skill should be used when the user asks to 'scaffold ICM', 'set up ICM', 'start a new ICM workspace', 'create IDENTITY.md and CONTEXT.md', 'build me a pipeline workspace', or names 'icm-scaffold'. It runs a ten question setup interview, picks an archetype, writes the layer files from the interview templates, then runs scripts/icm-check.sh on its own output and refuses to report success while the check fails."
user-invocable: true
argument-hint: "quick | full | wiki"
---

# ICM Scaffold

Stand up an Interpretable Context Methodology workspace on ground you are allowed to write on. You run a short interview, pick one archetype, write the layer files from the interview templates, then check your own output with the same script the rest of the toolkit uses.

The framing that makes the output worth having: the model is a **compiler**, not a chatbot. A job card names its inputs, its process and its outputs. The model reads sources and writes structured deliverables to fixed locations. Conversation belongs at review gates, not inside execution.

**This skill is an interview, not a script run.** You write every file here by hand, from a template, with a human answering questions. The archetypes below are decisions you make about what to write. The archetype names match `icm-plan.sh --archetype`, which is the retrofit path, not this one; the scripts play no part in step 4 of this skill. The only script this skill runs is `icm-check.sh`, at the end, to grade what you wrote.

## Use this, or use icm-retrofit

| Situation | Skill |
|---|---|
| Empty folder, or a folder with no `IDENTITY.md` and nothing that would collide | `icm-scaffold` (this one) |
| A live project with its own files, README, `CLAUDE.md`, or existing `CONTEXT.md` | `skills/icm-retrofit/SKILL.md` |
| A messy folder tree that needs pulling into the structure | `skills/icm-retrofit/SKILL.md`, plan mode |

Preflight, before the interview: if `IDENTITY.md` already exists at the target root, stop. Say "this root already has an ICM layer 0. Use `/icm-retrofit plan` instead." Do not scaffold over a workspace that exists.

## Resolve the toolkit first

The templates and the checker live in the toolkit, not in the workspace you are creating. Resolve the root once, then use `$ICM_HOME` for every read and every command.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

Under the plugin install `CLAUDE_PLUGIN_ROOT` is the repo root. Under the manual copy only `skills/icm-*` reaches `~/.claude/skills/`, so the templates and scripts stay in the clone at the path `README.md` documents.

## Read before you write

| File | Why |
|---|---|
| `$ICM_HOME/spec/CLI-CONTRACT.md` | The command names, artifact paths, rule book filenames and vocabulary. Authoritative over this file. |
| `$ICM_HOME/spec/layers.md` | Which layer each written file belongs to. |
| `$ICM_HOME/spec/budgets.md` | Every character budget. Never state a budget as a number in your own prose. |
| `$ICM_HOME/spec/excluded-folders.md` | The human rendering of `excluded_globs`. Never restate the list. |
| `$ICM_HOME/spec/CONVENTIONS.md` | The stage contract shape, one-way cross references, canonical sources. |
| `$ICM_HOME/spec/placeholder-syntax.md` | Placeholder rules and where placeholders may not appear. |
| `$ICM_HOME/spec/authority-model.md` | Which findings you may fix and which you may only report. |
| `$ICM_HOME/icm.defaults.json` | `required_sections`, `frontmatter`, `never_write`, `excluded_globs`. The numbers live here. |

## Step 1: Pick the archetype

The argument answers this. Confirm it against the interview rather than assume it.

| Archetype | You write | Use when |
|---|---|---|
| `quick` | layers 0, 1, 3 only. Routing and rule books. No new folders beyond `_config/` and `_log/`. | Adding ICM to a project that already has a working folder structure. This is the default. Earn complexity before you add it. |
| `full` | quick, plus physical stage folders under `stages/`, each with a job card and an `output/` folder. | A new pipeline built from scratch, where the stages are the folder structure. |
| `wiki` | full, plus the Karpathy compilation layer: `raw/` (immutable), `wiki/` (compiled), `wiki/index.md`, `wiki/log.md`, and the grounding invariant wired into the compile stage. | The work is knowledge compilation: sources in, cited articles out. |

If no argument was given, default to `quick` and say so.

## Step 2: The setup interview

Ask all ten in one pass. Accept brief answers. Derive what you can from the disk instead of asking twice. `$ICM_HOME/interview-templates/questionnaire.md.tmpl` is the long form if the user wants to fill it in themselves.

**Required**

1. **What project is this for?** Project name plus one sentence.
2. **Where does the project live?** Absolute root path. Everything you write goes under it.
3. **What does the folder structure look like?** Offer to scan it. If you scan, honour `excluded_globs` and show the user what you found before you use it.
4. **What are the main workflow tasks?** The verbs. "compile docs from source notes", "research, draft, review", "investigate, implement, test".
5. **Does this project compile knowledge?** Raw sources into structured articles. Yes points at the `wiki` archetype even if the argument said otherwise. Say so and let the user decide.
6. **Who reads the outputs?** Engineers, the public, agents, mixed. This sets voice and evidence standard.

**Optional, infer a default rather than block**

7. **What voice do outputs use?** Default: match the existing content in the repo.
8. **Are there existing conventions, glossary or style files?** If yes, the rule book re-exports them. It does not copy them.
9. **Do you want model adapters?** `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.cursorrules`, `.windsurfrules`. Default: none. `IDENTITY.md` works without any of them.
10. **Confirm the archetype.** Quick, full or wiki, per the table above.

Do not proceed on a guess for questions 1 to 4. Those four decide the routing table, and a wrong routing table is worse than no routing table.

## Step 3: Preflight the ground

Before the first write, list every path you intend to create and test it.

1. Any target path inside a `never_write` glob from `icm.defaults.json`: drop it and say why. There is no override.
2. Any target path that already exists: this is a collision. You are a greenfield generator, so a collision means you were pointed at the wrong tool. Stop and hand over to `skills/icm-retrofit/SKILL.md`. Do not write a proposal, do not merge, do not rename around it.
3. Any target path under a folder matching `excluded_globs`: drop it.

Show the user the full list of files you are about to create and get a yes. Creating twenty files is cheap. Creating twenty files in the wrong root is not.

## Step 4: Write the files

Every file comes from a template under `$ICM_HOME/interview-templates/`, filled in from the interview. If the template you need is missing, stop and say which one. Do not improvise a body.

`$ICM_HOME/interview-templates/` is interview material: it carries `{{SCREAMING_SNAKE}}` onboarding placeholders and authoring comments that only a human conversation can resolve. No script reads it as shipped, and no script writes any of the files below. You do.

**Every archetype**

| Output | Template | Layer | Budget key |
|---|---|---|---|
| `IDENTITY.md` | `$ICM_HOME/interview-templates/IDENTITY.md.tmpl` | 0 | `IDENTITY.md` |
| `CONTEXT.md` (root) | `$ICM_HOME/interview-templates/CONTEXT.root.md.tmpl` | 1 | `CONTEXT.root.md` |
| `_config/conventions.md` | `$ICM_HOME/interview-templates/config/conventions.md.tmpl` | 3 | `rulebook.md` |
| `_config/glossary.md` | `$ICM_HOME/interview-templates/config/glossary.md.tmpl` | 3 | `rulebook.md` |
| `_config/voice.md` | `$ICM_HOME/interview-templates/config/voice.md.tmpl` | 3 | `rulebook.md` |
| `_config/style.md` | `$ICM_HOME/interview-templates/config/style.md.tmpl` | 3 | `rulebook.md` |
| `_log/LOOP-LEDGER.md` | `$ICM_HOME/interview-templates/LOOP-LEDGER.md.tmpl` | log | none |
| `_log/FORGE-PROPOSALS.md` | no template. Heading only, empty body | log | none |

`_config/` holds **rule books**. They are not skills and you never call them skills, and you never write "skills library". There is one template per rule book under `$ICM_HOME/interview-templates/config/`; there is no generic rule book template, because a voice rule book and a glossary do not share a shape. `_config/voice.md` and `_config/style.md` cross-reference each other, so write both or neither.

The rule book filenames are the five in `$ICM_HOME/spec/CLI-CONTRACT.md` section 8: `conventions.md`, `glossary.md`, `voice.md`, `style.md` and `grounding.md`. There are no others, and `icm-apply.sh` installs the same five names on the retrofit path, so a scaffolded workspace and a retrofitted one carry the same layer 3 shelf.

**`full` adds**, one block per stage named in answer 4:

| Output | Template | Layer |
|---|---|---|
| `stages/NN-name/CONTEXT.md` | `$ICM_HOME/interview-templates/CONTEXT.stage.md.tmpl` | 2, the job card |
| `stages/NN-name/references/.gitkeep` | none | 3 holding pen |
| `stages/NN-name/output/.gitkeep` | none | 4b |

Stage folders are zero padded and lowercase with hyphens: `01-ingest`, `02-compile`.

**`wiki` adds**

| Output | Template | Layer |
|---|---|---|
| `raw/.gitkeep` | none | 4a, immutable |
| `wiki/index.md` | `$ICM_HOME/interview-templates/wiki/index.md.tmpl` | 4b |
| `wiki/log.md` | `$ICM_HOME/interview-templates/wiki/log.md.tmpl` | 4b |
| `_config/grounding.md` | no rule book template. Write it from `$ICM_HOME/spec/grounding-invariant.md`, and take its "Article shape" section from `$ICM_HOME/interview-templates/wiki/article.md.tmpl` | 3 |

There is no `_config/article-template.md`. The article shape is a section inside `_config/grounding.md` for the workspace, and `$ICM_HOME/interview-templates/wiki/article.md.tmpl` for the interview. A file with "template" in its name does not belong inside `_config/`.

The wiki archetype carries the grounding invariant: every load-bearing fact in a `wiki/` article, meaning every number, date and direct quote, exists verbatim in a `raw/` file that the article links. The compile stage job card must state it. `$ICM_HOME/spec/grounding-invariant.md` is the full text, and `skills/icm-wiki/SKILL.md` runs it.

**Content rules for every file you write**

- Write only what the interview and the disk support. Do not invent a folder, a task, or a status.
- Every folder in the workspace map gets a comment saying what it holds. The map is a fenced block, because `icm-check.sh --drift` reads the first fenced block in `IDENTITY.md` and compares it to the real tree.
- Required headings per file kind are in `icm.defaults.json` under `required_sections`. Missing one is a check failure, not a style choice.
- Character budgets come from `$ICM_HOME/spec/budgets.md`. A file over its ceiling is a failure. Cut the file.
- If canonical content already exists elsewhere in the repo, the rule book re-exports it: canonical path in a blockquote at the top, a short quick reference, then a link. It does not duplicate the content.
- Cross references point outward only. If the target already points back at you, restructure.
- Lowercase folder names. No em dashes.

### Model adapters

Only if answer 9 asked for them. **An adapter is an alias, never a copy.** Copying `IDENTITY.md` into an adapter fails `icm-check.sh --adapters` twice: once for the missing alias marker and once for body duplication.

`CLAUDE.md` takes the strict form. It carries the two references inside the icm markers and nothing else:

```
<!-- icm:begin -->
<!-- Managed by the Momentrix ICM KAP Toolkit. Edit IDENTITY.md, not this block. -->
@IDENTITY.md
@CONTEXT.md

Read IDENTITY.md first, then CONTEXT.md, then the job card in the folder you are working in. Nothing else loads by default. Before your last reply, run the Session Close in CONTEXT.md.
<!-- icm:end -->
```

That block is the one `icm_body_claude_block` in `scripts/icm_lib.sh` writes; copy it from there, not from here, if the two ever differ. The last sentence is the write-back obligation, and the root `CONTEXT.md` you scaffold from `interview-templates/CONTEXT.root.md.tmpl` carries the matching `## Session Close` section, which `icm-check.sh --sections` requires.

`AGENTS.md`, `GEMINI.md`, `.cursorrules` and `.windsurfrules` take the loose form: the checker only requires that they mention `IDENTITY.md` somewhere. One sentence pointing the reader at `IDENTITY.md` and then at `CONTEXT.md` is enough, and it is the whole file. Never paste the body of `IDENTITY.md` into any of them; a second source of truth is exactly the failure the layer 0 file exists to prevent.

## Step 5: Clear the placeholders

The templates ship `{{PLACEHOLDER}}` markers. Replace every one from the interview answers, then grep the written set for a double open brace. Anything left is unfinished work: ask the user for the missing value rather than deleting the marker. Rules and the conditional block syntax are in `$ICM_HOME/spec/placeholder-syntax.md`.

The checker exempts a placeholder inside a code fence or inside backticks, because that is documentation quoting the syntax. It does not exempt one in live prose, and neither should you.

## Step 6: Check your own work

From the project root you just wrote into:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" .
```

Exit 0 clean, 1 findings, 2 usage or environment error. To re-verify a single fix, pass that check's own flag, for example `--sections` or `--adapters`, or select it by id with `--only sections`.

**A scaffold that fails its own check is a bug, not a warning.** Do not report success with findings attached. Fix what you wrote, re-run, and only then report. The fix direction is fixed:

- Budget breach: cut the file. Never raise the budget.
- Missing required section: write the section. Never delete the check.
- Frontmatter finding: fix the key. The hyphenated `user-invocable` is required, the underscored spelling is banned, and `name` equals the directory name.
- Adapter finding: make the adapter an alias. Never satisfy it by copying more.
- Drift finding: the workspace map is missing something that is on disk. Add it to the map.
- Route finding: a `CONTEXT.md` points at a path that does not exist. Fix the path or write the file.

Exactly two findings may survive into your report, and both must be named as open work rather than buried:

1. A mechanical report against a pre-existing user file you did not write.
2. The evidence check skipped because `python3` is absent, or because the workspace has no `wiki/`. `scripts/check_evidence.py` is optional. Nothing in this toolkit requires python or node.

Anything else, you loop until the check is clean.

## Step 7: Report

```
## ICM Scaffold Report - YYYY-MM-DD

Archetype: quick | full | wiki
Root: <absolute path>

### Created
- <path> - <one line purpose>

### Check result
sh "$ICM_HOME/scripts/icm-check.sh" . - PASS
(or: PASS with N open items, each listed and owned)

### Not automated
- <what the user still has to fill in, per file>

### Next
- Review IDENTITY.md. Does the workspace map match your mental model?
- Review the routing table in CONTEXT.md. Does every common task have a row?
- Review _config/. Do the rule books match how you actually work?
- Full or wiki: run the pipeline once on a small case before using it at scale.
```

## Step 8: Log

Append one ledger line to `_log/LOOP-LEDGER.md` through `skills/icm-log/SKILL.md`. The format is fixed by `references/ledger.md` of the `out-of-the-loop` skill:

```
| Date | Task | Tier | Anchor | Verify cycles | Holes: plan/hunt/review/audit | Workarounds | Call fired | Artifact |
```

Do not invent a different shape. Verify cycles is how many times you had to re-run `icm-check.sh` before it came back clean, and that number is the honest measure of this skill.

## Rules that do not bend

1. Never overwrite a user file. A greenfield generator that meets an existing file has met the wrong job. Hand over to `icm-retrofit`.
2. Never restructure folders that already exist. ICM layers are additive.
3. Never duplicate content that has a canonical home. Point at it. That applies to adapters most of all.
4. Never write a generic rule. "Write clean code" belongs to nobody. Only workspace specific rules earn a line.
5. Keep the job cards small. They route, they do not teach. Reference material lives in layer 3, not in a `CONTEXT.md`.
6. Never require python or node. Every path through this skill works with POSIX `sh` and nothing else.
7. Never name a script flag or a check id that does not exist. Every one in this file was verified against the scripts in this checkout.

## Machine-enforced vs model judgment

Per `$ICM_HOME/spec/authority-model.md`. Know which half of this list you are allowed to argue with.

**Machine-enforced.** `scripts/icm-check.sh` decides. Its verdict is not an opinion and you do not talk it down. Every row below was verified against the script; each check has a flag of the same name, and `--only <id>` selects one by id. There are eleven ids and no others.

| Check | check-id | What it actually verifies |
|---|---|---|
| Frontmatter keys | `frontmatter` | For each `skills/<name>/SKILL.md`: required keys present and non-empty, no banned key, `name` equals the directory name |
| Required sections | `sections` | `IDENTITY.md`, the root `CONTEXT.md` and every other `CONTEXT.md` carry the headings listed for their kind under `required_sections` |
| Character budgets | `budgets` | `IDENTITY.md`, both kinds of `CONTEXT.md`, every `_config/*.md`, and every wiki article, against the ceilings in `icm.defaults.json` |
| Adapter shape | `adapters` | `CLAUDE.md` contains `@IDENTITY.md` and is not a copy of the `IDENTITY.md` body; the four loose adapters are warned about if they exist and never mention `IDENTITY.md` |
| Workspace map drift | `drift` | Every top-level entry on disk, and every job card folder, appears in the fenced map in `IDENTITY.md` |
| Routing targets | `routes` | Inside files named `CONTEXT.md` only, every path-shaped token resolves on disk |
| Relative links | `links` | Every `.md` under the target: every markdown link target that is not `http`, `mailto` or a bare anchor resolves on disk |
| Placeholders | `placeholders` | No unfilled double-brace placeholder in live prose, outside any `*.tmpl` file and outside code fences and backticks |
| Code fences | `fences` | Backtick and tilde fence counts are even in every `.md` |
| Shell and defaults self-test | `self` | Defaults parse, every `.sh` passes `sh -n`, the bashism sweep is clean, no `.md` carries a banned frontmatter key |
| Grounding invariant, optional | `evidence` | Runs `scripts/check_evidence.py` when `python3` and `wiki/` both exist. Skipped otherwise, and the skip is reported, never hidden |

**Not checked by anything.** Do not describe these as machine-enforced.

- A dead relative link written inside a code fence or inline backticks. `links` skips both on purpose, because a backticked link is documentation quoting the syntax.
- A write proposed inside a `never_write` glob or an excluded folder. That refusal lives in `icm-plan.sh` and `icm-apply.sh`. The checker never proposes a write, so it cannot refuse one. Your step 3 preflight is the enforcement here.
- Whether `wiki/index.md` agrees with the files on disk. Nothing in `scripts/` reads it.

**Model judgment.** No script can see these. You own them, and you report them as findings rather than silently acting.

- Whether the routing table covers the tasks the user actually does.
- Whether a stage split is the right split, or one stage doing two jobs.
- Whether a rule book should re-export an existing file instead of holding its own copy.
- Whether the workspace map matches the user's mental model, which only the user can confirm.
- Whether the archetype is right. Answer 5 saying yes to knowledge compilation while the argument said `quick` is a judgment call you surface, not one you make alone.
- Voice, tone, and whether a rule is specific enough to be worth a line.

**Neither.** You never edit a `_config/` rule book that already exists. A rule book may be created once, as part of standing the workspace up; after that the human holds the pen, and changes are proposals into `_log/FORGE-PROPOSALS.md`.
