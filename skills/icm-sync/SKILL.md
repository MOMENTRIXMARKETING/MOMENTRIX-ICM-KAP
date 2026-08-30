---
name: icm-sync
description: "This skill should be used when the user asks to 'sync ICM', 'lint the workspace', 'check for drift', 'the routing is out of date', 'IDENTITY.md is stale', 'fix the broken links', or names 'icm-sync'. It runs scripts/icm-check.sh, then repairs exactly what the report names: safe fixes applied by you and reported, mechanical findings reported and never fixed, judgment findings proposed."
user-invocable: true
argument-hint: "lint | update"
---

# ICM Sync

Drift repair. A workspace is a description of a project, and projects move. Folders appear, folders die, a file gets renamed and four routing tables go quietly wrong. This skill finds that gap and closes the part of it that is safe to close.

**The script decides what is wrong. You decide how to word the fix.** That split is the whole discipline. `scripts/icm-check.sh` has no taste and no opinions, which is exactly why its verdict is not negotiable. You have taste, which is exactly why you do not get to decide what counts as broken.

| Mode | Behaviour |
|---|---|
| `lint` | Run the check, report everything, change nothing in the project. The only file written is the ledger line that records the run. |
| `update` | Run the check, apply the safe fixes yourself, report the mechanical findings, park the judgment findings as proposals. |

Default with no argument: `lint`. Looking is free.

## Resolve the toolkit first

The checker lives in the toolkit, not in the workspace you are linting. Resolve the root once, then use `$ICM_HOME` for every invocation.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

## Read before you run

| File | Why |
|---|---|
| `$ICM_HOME/spec/authority-model.md` | The three tiers below. Authoritative when this file and that file disagree. |
| `$ICM_HOME/spec/CLI-CONTRACT.md` | The command names, flags and vocabulary every skill is allowed to use. |
| `$ICM_HOME/spec/excluded-folders.md` | The human rendering of `excluded_globs`. Never restate the list. |
| `$ICM_HOME/spec/budgets.md` | Every character budget. Never state one as a number in your prose. |
| `$ICM_HOME/spec/layers.md` | Which layer each file belongs to, and which files may reference which. |
| `$ICM_HOME/icm.defaults.json` | `required_sections`, `frontmatter`, `never_write`, `excluded_globs`, budgets. |

## Step 1: Find the root

Search upward from the working directory for `IDENTITY.md`. That file is layer 0 and it marks the root.

No `IDENTITY.md` anywhere above you: stop and say "no ICM workspace found here. Run `/icm-scaffold` on an empty root, or `/icm-retrofit plan` on a live project." Do not create one. Sync repairs, it does not found.

Then read what the workspace currently claims about itself: `IDENTITY.md`, the root `CONTEXT.md`, every job card, every `_config/` rule book, and any model adapter that exists.

## Step 2: Run the check

```sh
sh "$ICM_HOME/scripts/icm-check.sh" .
```

Exit 0 is clean. Exit 1 means findings. Exit 2 means a usage or environment error, which is a bug in the command you typed, not a finding about the workspace.

Read the report, do not re-derive it. If you disagree with a finding, that disagreement is a judgment report you raise to the user, not a licence to ignore the row.

### Running one check

`icm-check.sh` takes one flag per check, and `--only <id>` selects the same check by its id. These two lines are equivalent:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --routes .
sh "$ICM_HOME/scripts/icm-check.sh" --only routes .
```

`--only` takes exactly one id and may be repeated. An id that is not one of the eleven prints `FAIL unknown check id: <id>`, lists all eleven, and exits 2. Flags can be combined and the positional target can appear in any order.

The report is never writable. `icm-check.sh` writes nothing inside the target, ever, in any mode. Everything in tier 1 below is applied by **you**, with your own edits, and then reported.

`scripts/check_evidence.py` is the optional deep check. `icm-check.sh` runs it under `--evidence` when both `python3` and a `wiki/` directory exist, and reports the skip when either is missing. A skipped evidence check is never presented as a pass, and nothing in this toolkit requires python or node to work.

## Step 3: Sort every finding into one of three tiers

This is the authority model from `$ICM_HOME/spec/authority-model.md`, applied. Every finding goes in exactly one tier, and the tier decides what you are allowed to do about it.

### Tier 1: Safe fixes. Applied by you in `update` mode, then reported.

Deterministic. One correct answer. No content invented. No script applies any of these; you apply them with an ordinary edit and then say you did. That distinction matters: an unwatched model wearing a script's authority is exactly what the authority model warns against.

| Finding | Fix | How you find it |
|---|---|---|
| Internal link whose target is missing, and exactly one file of that name exists elsewhere in the workspace | Repoint the link at the one match | `grep` for the link, `find` for the basename, one match only |
| `See Also` link whose target is missing, and zero files of that name exist anywhere | Remove the link. A dead cross reference is not load-bearing | `find`, zero matches |
| Index entry pointing at a file that no longer exists | Mark the entry `[MISSING]`. Do not delete it. The user decides whether the file or the entry was the mistake | `grep` the index, `[ -f ]` per row |
| File exists but is absent from its index | Add the entry with a `(no summary)` placeholder and the article's own Updated date, falling back to the file's modification date | `find wiki/`, `grep` the index |
| Index entry whose Updated date disagrees with the article's metadata | Set the index to match the article. The article is the source | `grep` both, compare |
| Workspace map in `IDENTITY.md` missing a folder that exists on disk | Add the folder in tree order with a one line comment and its layer annotation | `icm-check.sh --drift` names it |
| Workspace map naming a folder that no longer exists | Annotate it `# [REMOVED - verify]`. Do not delete the line | `icm-check.sh --drift` warns on it |
| `CLAUDE.md` that no longer aliases `IDENTITY.md` | Restore the alias block: the icm markers around `@IDENTITY.md` and `@CONTEXT.md`, nothing else. Never paste the body of `IDENTITY.md` into it | `icm-check.sh --adapters` fails it |
| Trailing whitespace, missing final newline, a heading level that skips a rank | Fix in place | reading the file |

**Two hard exclusions from tier 1, no matter how safe the fix looks:**

1. **Nothing inside `_config/` is ever fixed here.** Rule books are the human's pen. A script may create a rule book that does not exist, once, as part of an install. No script and no agent ever edits one that exists. Every finding against a rule book, even a dead link, becomes a proposal.
2. **Nothing inside `raw/` is ever touched.** `raw/` is immutable by definition. If a raw file is wrong, the fix is a new raw file, not an edit.

### Tier 2: Mechanical reports. Found by a check, never fixed.

A machine is certain something is wrong and equally certain that the repair requires a decision. You report these with the exact path, the exact finding, and a recommendation. You do not act.

| Finding | Why it is not fixed here |
|---|---|
| A file over its ceiling in `$ICM_HOME/spec/budgets.md` | The fix is deciding what to cut, and that is content |
| A required heading from `required_sections` in `icm.defaults.json` is missing | Writing the section body is authorship |
| A banned frontmatter key is present | Renaming a key can change behaviour. Recommend the hyphenated `user-invocable` and let the user confirm |
| `name` in frontmatter not equal to the directory name | Either the name or the directory is wrong, and only the user knows which |
| A shell script that fails `sh -n`, or a bashism the sweep caught | The fix is code, and code is reviewed, not auto-rewritten |
| A link whose target is missing and which has zero or several candidate matches | Guessing between candidates is how a wrong link becomes a confident wrong link |
| A grounding invariant failure from `scripts/check_evidence.py`: a number, date or quote in a `wiki/` article that is not in the linked `raw/` file | A fact mismatch is never a formatting problem. Report the article, the claim, and the raw file it should have come from |
| A raw file with nothing compiled from it and no `No material` disposition in the log | It is a backlog reminder, not an error |
| A surviving double-brace placeholder | Only the user has the value |
| An unbalanced code fence | An odd fence count means a block is open somewhere and only reading tells you where |

Findings that came in from a retrofit `ADOPT` row belong here too. A file you inherited failing a check is open work, not a failure of the sync.

### Tier 3: Judgment reports. Always a proposal.

Your opinion. Sometimes a very good opinion, still an opinion. Write these as proposals with the reasoning visible, and apply nothing until the user says yes.

- A routing table row that points somewhere plausible but wrong for the task named.
- A folder whose purpose text no longer matches what is in it.
- Two articles or two job cards that contradict each other.
- A claim superseded by a newer source but still presented without a Status block.
- An obviously missing cross reference between related documents.
- An orphan page with no inbound links.
- A concept mentioned everywhere with no page of its own. That is a doctrine hole.
- A `_config/` or `references/` folder large enough to need its own `_index.md`.
- A stage whose job card describes a process the outputs say nobody follows.
- Anything at all inside a `_config/` rule book.

Rule book proposals go to `_log/FORGE-PROPOSALS.md`, in the format `skills/icm-forge/SKILL.md` defines. Everything else can be proposed in the report. **The forge never edits and the logger never judges.**

## Step 4: Apply, in `update` mode only

1. Apply every tier 1 fix yourself, honouring both exclusions, and record what you changed so you can list it.
2. Write every tier 3 proposal that touches a rule book into `_log/FORGE-PROPOSALS.md`.
3. Touch nothing in tier 2.
4. If a fix would create a file rather than edit one, it is not a sync. Route it: a missing job card goes to `skills/icm-context/SKILL.md`, a missing layer goes to `skills/icm-retrofit/SKILL.md`.
5. Never rewrite a user file wholesale. A sync edit is targeted: one link, one row, one date. If a file needs replacing rather than editing, write the replacement to `.icm/proposed/<relative-path>` and say so. That is a collision, and the collision policy is in `skills/icm-retrofit/SKILL.md`.

In `lint` mode you skip this step entirely and say so plainly: "no files were changed."

## Step 5: Re-run the check

```sh
sh "$ICM_HOME/scripts/icm-check.sh" .
```

Every tier 1 fix must be gone from the second report. A safe fix that did not clear is not safe, so revert it and reclassify the finding as tier 2. Two attempts at the same finding is the ceiling. A third is how a small drift becomes a hardened mistake.

## Step 6: Report

```
## ICM Sync Report - YYYY-MM-DD
Mode: lint | update
Root: <absolute path>
Check: sh "$ICM_HOME/scripts/icm-check.sh" . - N findings

### Safe fixes applied by me (N)
- <path> - <what changed>

### Mechanical reports, not fixed (N)
- <path> - <finding> - <recommended action>

### Judgment proposals (N)
- <path> - <proposal> - <why> - awaiting your yes

### Rule book proposals
- written to _log/FORGE-PROPOSALS.md (N)

### Routed elsewhere
- <folder> - warrants a job card, run /icm-context report

### Skipped checks
- evidence - python3 not present, grounding invariant unverified

### Clean
<if nothing was found, say exactly that and stop>
```

`lint` closes with "no files were changed. Run `/icm-sync update` to apply the safe fixes."
`update` closes with "safe fixes applied by me and listed above. Everything else is waiting on you."

## Step 7: Log

One ledger line through `skills/icm-log/SKILL.md`, in the fixed format from `references/ledger.md` of `out-of-the-loop`:

```
| Date | Task | Tier | Anchor | Verify cycles | Holes: plan/hunt/review/audit | Workarounds | Call fired | Artifact |
```

If the workspace has a `wiki/`, also append the lint line to `wiki/log.md`:

```
## [YYYY-MM-DD] lint | <N> issues found, <M> auto-fixed
```

Do not invent a third log format. Two exist and both are already specified.

## Rules that do not bend

1. The script decides what is wrong. You never downgrade a finding because you disagree with it.
2. Never edit an existing `_config/` rule book. Proposals only.
3. Never edit anything in `raw/`. It is immutable.
4. Never rewrite a user file. Targeted edits only, collisions to `.icm/proposed/`.
5. Never delete a line to make a check pass. Removing the evidence of a problem is not fixing the problem.
6. Never raise a budget to fit a file. Cut the file.
7. Never require python or node. The evidence check is optional and its absence is reported.
8. Two attempts at the same finding, then it goes to the user.
9. Never claim a check exists because it would be useful. Every check id in this file is one `icm-check.sh` accepts today.

## Machine-enforced vs model judgment

Per `$ICM_HOME/spec/authority-model.md`. This is the full check table the rest of the toolkit refers back to, and every row was verified against `scripts/icm-check.sh` in this checkout.

**Machine-enforced.** `scripts/icm-check.sh` finds these. There are eleven check ids and no others. Each one has a flag of the same name, and `--only <id>` selects one by id.

| Check | check-id | What the script actually verifies | Tier of the fix |
|---|---|---|---|
| Shell and defaults self-test | `self` | `icm.defaults.json` parses and its `excluded_globs` and `never_write` lists are non-empty; every `.sh` under the target passes `sh -n`; the bashism sweep is clean; no `.md` under the target carries a banned frontmatter key | 2, mechanical |
| Frontmatter keys | `frontmatter` | For every `skills/<name>/SKILL.md`: the required keys are present and non-empty, no banned key appears, and `name` equals the directory name. Missing `user-invocable` or `argument-hint` is a warn, not a fail | 2, mechanical |
| Character budgets | `budgets` | `IDENTITY.md`, the root `CONTEXT.md`, every other `CONTEXT.md` as a stage card, every `_config/*.md` as a rule book, and every `wiki/*.md` article except `index.md` and `log.md`, against the ceilings in `icm.defaults.json`. Over target is a warn, over ceiling is a fail | 2, mechanical |
| Adapter shape | `adapters` | `CLAUDE.md` contains `@IDENTITY.md`, and is not a copy of the `IDENTITY.md` body. `AGENTS.md`, `GEMINI.md`, `.cursorrules` and `.windsurfrules` are warned about only if they exist and never mention `IDENTITY.md` | 1, safe |
| Workspace map drift | `drift` | Every top-level entry on disk, and every folder holding a job card, appears in the fenced workspace map in `IDENTITY.md`. A mapped path that is not on disk is a warn | 1, safe |
| Required sections | `sections` | `IDENTITY.md`, the root `CONTEXT.md` and every other `CONTEXT.md` carry the headings listed for their kind under `required_sections` in `icm.defaults.json` | 2, mechanical |
| Routing targets | `routes` | Inside files literally named `CONTEXT.md` only: every backticked token and every markdown link target that looks like a path resolves on disk, relative to the file or to the root | 1 when exactly one match exists, 2 otherwise |
| Relative links | `links` | Every `.md` under the target, not just `CONTEXT.md`: every markdown link target that is not `http`, `mailto` or a bare anchor resolves on disk. A `*.tmpl` file is exempt, and so is a link inside a code fence or inline backticks, which is documentation quoting the syntax | 1 when exactly one match exists, 2 otherwise |
| Code fences | `fences` | Every `.md` under the target has an even number of backtick fence lines and an even number of tilde fence lines | 2, mechanical |
| Placeholders | `placeholders` | No unfilled double-brace placeholder survives in live prose in any `.md` under the target. Any `*.tmpl` file is exempt, because it is interview material a human fills in, and so is anything inside a code fence or backticks, which is documentation quoting the syntax | 2, mechanical |
| Grounding invariant, optional | `evidence` | Runs `scripts/check_evidence.py` when both `python3` and a `wiki/` directory exist, and relays its report. Skipped otherwise, and the skip is always printed rather than counted as a pass | 2, mechanical |

**Named by no script.** These are real concerns and the toolkit has no machine for them. Do not file them under machine-enforced, and do not name a check id for them, because none exists.

| Concern | Who actually covers it |
|---|---|
| A dead relative link inside a code fence or inline backticks | Nobody, deliberately. `links` skips both, because a backticked `[Title](wiki/topic/article.md)` is documentation quoting the syntax, not a claim that the path exists. If you meant it as a real link, unquote it and `links` will grade it. |
| A write proposed inside a `never_write` glob or an excluded folder | `scripts/icm-plan.sh` and `scripts/icm-apply.sh`, never the checker. `icm-check.sh` is report-only by contract and never proposes a write, so it cannot have an opinion about one. |
| `wiki/index.md` disagreeing with the files on disk | You, in tier 1 above. Nothing in `scripts/` reads `wiki/index.md`, and `check_evidence.py` deliberately skips `index.md` and `log.md`. |
| Whether an applied plan was stale | Nobody. `icm-apply.sh` re-classifies and warns; it does not refuse. |

**Model judgment.** No script sees these. You raise them, you never act on them alone.

- Whether a routing row sends the reader to the right place for the task it names.
- Whether a folder's stated purpose still matches its contents.
- Whether two documents contradict each other, and which one is now wrong.
- Whether a missing cross reference is genuinely missing or deliberately absent.
- Whether a concept mentioned often enough to be doctrine deserves a page.
- Whether a `_config/` folder has grown past the point where an index pays for itself.
- The wording of every fix you apply and every proposal you write.

**Neither.** Rule book content, and the definition of done for the workspace. Those belong to the human. The logger never judges, the forge never edits, and sync never writes doctrine.
