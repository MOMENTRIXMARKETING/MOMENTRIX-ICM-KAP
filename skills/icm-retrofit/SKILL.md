---
name: icm-retrofit
description: "This skill should be used when the user asks to 'retrofit ICM', 'add ICM to this project', 'drop ICM onto an existing repo', 'tidy this folder tree into stages', 'neaten this mess', 'plan the ICM changes first', or names 'icm-retrofit'. It runs scripts/icm-plan.sh to write .icm/plan.txt, shows the CREATE / ADOPT / COLLIDE / SKIP / REFUSE diff plus the tree survey, waits for an explicit yes, then runs scripts/icm-apply.sh. Collisions are parked in .icm/proposed/ and scripts/icm-rollback.sh undoes one apply run."
user-invocable: true
argument-hint: "plan | apply | rollback"
---

# ICM Retrofit

Drop the Interpretable Context Methodology onto a project that is already alive and already has files in it. This is the headline skill of the toolkit and it exists because the hard case is never the empty folder. The hard case is a working project with four years of history, a `README` somebody trusts, and a folder tree that made sense to one person on one afternoon.

Three rules carry the whole design.

1. **Nothing is written without a plan on disk.** `icm-apply.sh` reads `<target>/.icm/plan.txt`. No plan file, no writes, exit 2.
2. **Nothing you wrote is ever deleted or rewritten.** Most managed paths are only written when nothing exists there. Two of them, `CLAUDE.md` and `.gitignore`, are edited in place, and only between `<!-- icm:begin -->` and `<!-- icm:end -->`. Every byte outside those markers is unchanged, and the pre-image is copied to `.icm/backup/<stamp>/files/` before the edit. Anything else that already exists is a collision: the toolkit's version goes to `.icm/proposed/` with a diff beside it, and your file is not touched.
3. **Every apply is reversible.** Apply records what it did in a manifest. `scripts/icm-rollback.sh` undoes exactly that run and nothing else.

## The three modes

| Mode | Script | Writes to disk |
|---|---|---|
| `plan` | `scripts/icm-plan.sh` classifies every managed path, surveys your tree, and writes exactly one file, `<target>/.icm/plan.txt` | `.icm/plan.txt`, nothing else, ever |
| `apply` | `scripts/icm-apply.sh` executes that plan and nothing else | the managed paths, plus `.icm/backup/` and `.icm/proposed/` |
| `rollback` | `scripts/icm-rollback.sh` reverses one recorded apply run | removes what that run created, restores what it modified |

Default with no argument: `plan`. Planning is free and reversible by construction. Guessing is not.

## Resolve the toolkit first

Every command in this skill runs from the user's project, so `scripts/` is never on a relative path you can reach. Resolve the toolkit root once, in the first command block of the session, and use `$ICM_HOME` from then on.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

The precedence is deliberate: an operator override wins, then the plugin root, then the clone path `README.md` documents. Under the plugin install `CLAUDE_PLUGIN_ROOT` is the repo root, because `.claude-plugin/marketplace.json` sets `"source": "./"`. Under the manual copy only `skills/icm-*` is copied to `~/.claude/skills/`, so the scripts stay in the clone.

## Read before you plan

Every one of these lives in the toolkit, not in the user's project. Read them with `$ICM_HOME` in front.

| File | Why |
|---|---|
| `$ICM_HOME/spec/CLI-CONTRACT.md` | The command names, flags, artifact paths and vocabulary. Where this file and that file disagree, that file wins. |
| `$ICM_HOME/spec/excluded-folders.md` | The human rendering of `excluded_globs`. Never restate the list, cite the file. |
| `$ICM_HOME/spec/budgets.md` | Every character budget for every file kind. |
| `$ICM_HOME/spec/layers.md` | Which layer a candidate file belongs to. |
| `$ICM_HOME/spec/CONVENTIONS.md` | The stage contract shape and the cross reference direction. |
| `$ICM_HOME/spec/authority-model.md` | Safe fix, mechanical report, judgment report. |
| `$ICM_HOME/icm.defaults.json` | `never_write`, `excluded_globs`, `required_sections`, `frontmatter`, budgets, asset extensions. |

## MODE: plan

```sh
sh "$ICM_HOME/scripts/icm-plan.sh" .
```

| Flag | Meaning |
|---|---|
| `--allow-dirty` | Plan anyway when the target is a git repo with uncommitted work |
| `--quiet` | Write the plan, print only the counts |
| `-h`, `--help` | Print usage and exit 0 |

The positional target defaults to `.` and may appear in any order among the flags. Exit 0 means the plan is written and nothing needs a decision. Exit 1 means the plan is written and there are collisions or refusals for a human to decide. Exit 2 means it refused before writing anything: a dirty repo without `--allow-dirty`, a bad target, or a usage error.

### What plan does, and what it leaves to you

Plan does two separate things and it is worth keeping them apart in your head.

**It classifies the fixed install set.** The manifest is compiled into `scripts/icm_lib.sh`. Apply never invents a path from your tree; it writes these and nothing else.

| Path | Role |
|---|---|
| `IDENTITY.md` | create, layer 0 |
| `CONTEXT.md` | create, layer 1 routing |
| `_config/conventions.md` | create, layer 3 rule book |
| `_config/glossary.md` | create, layer 3 rule book |
| `_config/voice.md` | create, layer 3 rule book |
| `_config/style.md` | create, layer 3 rule book |
| `_config/grounding.md` | create, layer 3 rule book |
| `raw/CONTEXT.md` | create, layer 4a job card |
| `wiki/index.md` | create, layer 4b |
| `wiki/log.md` | create, layer 4b |
| `output/CONTEXT.md` | create, layer 4b job card |
| `_log/LOOP-LEDGER.md` | create, the ledger |
| `_log/FORGE-PROPOSALS.md` | create, the proposal queue |
| `CLAUDE.md` | adopt, the adapter |
| `.gitignore` | adopt |

Those five rule book filenames are the whole set. There are no others. Numbered stage folders are not an install row at all; they come from `skills/icm-stage/SKILL.md`.

Note for anyone reading `skills/icm-scaffold/SKILL.md` next: `icm-plan.sh --archetype quick|full|wiki` picks which rows of the table above are written, and the default is `quick`, which writes none of the `raw/`, `wiki/`, `output/` or `_config/grounding.md` rows. `spec/CLI-CONTRACT.md` section 7 owns the three row sets. A retrofit that wants the knowledge pair passes `--archetype wiki`; the scaffold interview is where a human decides which archetype a new workspace gets.

**It surveys your tree, and reports.** Plan walks the target two levels deep, prunes `excluded_globs`, skips the directories the install manifest owns, and emits one `SURVEY` row per surviving folder. `SURVEY` is not a disposition: apply ignores every survey row and never writes a job card. The verdicts are `has-card`, `staged`, `card` and `none`, and the script says out loud what they are worth:

> a verdict is evidence, not a conclusion. a number in a folder name is a signal that it might be a stage; it is not proof that it is one.

Reading those rows and deciding what each folder actually is remains yours. The job cards themselves are written later by `skills/icm-context/SKILL.md`, one at a time, with a human.

### The plan file

One artifact, one name: `<target>/.icm/plan.txt`. That is the only plan file, under any spelling, and there is no separate human readable copy. The human readable form is the script's own stdout, which you captured when you ran it. The only manifest path is `<target>/.icm/backup/<STAMP>/manifest.txt`.

Five tab separated fields. A tab is forbidden inside any field, which is what lets a folder named `01 - research notes/` survive the format.

```
# icm plan
# toolkit: Momentrix ICM KAP Toolkit 1.0.0
# defaults: /abs/path/to/icm.defaults.json
# target: /abs/path/to/project
# generated: 2026-08-30T00:00:00Z
# format: STATUS<TAB>ROLE<TAB>RELPATH<TAB>CANDIDATE-SHA<TAB>REASON
```

`CANDIDATE-SHA` fingerprints the body apply would write, or is `-` where there is none. `REASON` is never empty. If you read the file yourself, set the separator once:

```sh
ICM_TAB=$(printf '\t')
while IFS="$ICM_TAB" read -r P_STATUS P_ROLE P_RP P_SHA P_REASON; do
    printf '%s -> %s (%s)\n' "$P_STATUS" "$P_RP" "$P_REASON"
done < ./.icm/plan.txt
```

### The five dispositions

These five words are the whole vocabulary. There is no `PRESENT`. `SURVEY` is a sixth row kind, not a disposition.

| Word | Condition | What apply does |
|---|---|---|
| `CREATE` | Nothing exists at the path | Writes the whole file from the body compiled into `scripts/icm_lib.sh`, plus a `MKDIR` row for each directory it had to make |
| `ADOPT` | The path is a regular file, its role is `adopt`, it carries a well-formed managed block or none, and it differs from the candidate | Copies the pre-image to `.icm/backup/<stamp>/files/`, then rewrites only the text between the icm markers. Records `MODIFIED` |
| `COLLIDE` | The path exists and apply must not write it | Writes the candidate to `.icm/proposed/<relpath>` and a unified diff to `.icm/proposed/<relpath>.diff`. Your file is not read-modify-written, not renamed, not moved. Records `PARKED` |
| `SKIP` | The path already holds exactly what apply would write, byte for byte | Nothing. Records `SKIPPED` |
| `REFUSE` | The path matches a `never_write` glob, or resolves outside the target | Nothing at all. No candidate, no proposal, no workaround |

`SKIP` means **already installed and identical**. It has never meant "excluded folder" and it never will. An excluded folder is never a candidate, so it can never be a `SKIP` row.

Four different things produce a `COLLIDE`, and it is worth naming which one you are looking at when you report it: the file exists and differs; the path is not a regular file, meaning a symlink, a directory, a FIFO or a device; an adopt-role file whose marker set is malformed; or a `_config/` rule book that already exists. A rule book that already exists is always a collision, even when it looks stale, because rule books are the human's pen.

The manifest action words are deliberately different from the plan disposition words. A plan row says what apply intends. A manifest row says what apply did.

### Presenting the diff

Show the user the script's own output, grouped and complete, never a sample. Plan prints the path and its reason on the same line, then the survey, then the counts:

```
CREATE - absent, apply would write these
  IDENTITY.md                        layer 0 identity, absent
  _config/voice.md                   layer 3 rule book, absent

COLLIDE - apply parks a candidate and touches nothing
  IDENTITY.md                        exists and differs, candidate parked

ADOPT - your file is kept, apply appends a marked icm block and backs up the original first
  CLAUDE.md                          adapter, icm block will be appended

SURVEY - folders in your tree, and whether they look like they want a job card

| Folder                         | Verdict  | Files | Stage signal | Suggested next step
| 01 - research notes/           | staged   |     3 | yes          | /icm-context one "01 - research notes"
| assets/                        | none     |     1 | no           | asset-only, nothing to route

ok   CREATE 14   COLLIDE 0   ADOPT 1   SKIP 0   REFUSE 0   SURVEY 2
```

Say plainly that `ADOPT` is not a no-op: those files are edited in place, inside the markers, after a backup. Plan's closing note already tells the user that `.icm/` is not in `.gitignore` until apply runs, so do not contradict it.

### The confirmation gate

`apply` does not run until the user says yes in their own words to this specific plan. Not implied by the fact that they asked for a retrofit. Not carried over from a previous plan.

Frame it as a decision, not a status update: here is the plan, here is the recommendation, here is what happens if you do nothing. If the user asks for changes, re-run plan, re-present, ask again.

## MODE: apply

```sh
sh "$ICM_HOME/scripts/icm-apply.sh" .
```

| Flag | Meaning |
|---|---|
| `--plan FILE` | Use this plan instead of `<target>/.icm/plan.txt` |
| `--dry-run` | Say what would happen, write nothing at all |
| `--no-check` | Skip the closing `icm-check.sh` run |
| `--force-unlock` | Remove a lock left behind by a killed run, and say whose it was |
| `-h`, `--help` | Print usage and exit 0 |

**There is no `--rollback` flag on apply.** Passing it exits 2 and points you at the real script. Rollback is a separate script.

| Exit | Meaning |
|---|---|
| 0 | Applied clean, or nothing to do |
| 1 | Applied, and a human decision is waiting: something was parked or refused |
| 2 | Refused before anything was written |
| 3 | Aborted part way through. The target may be half changed, and the message names the rollback command |

Exit 3 is the one to key a wrapper on. A crashed apply is not the same day as an ordinary collision, and the exit code now says so.

### What apply refuses, and what it does not

Apply refuses on: no plan file, a plan whose `# target:` header names a different directory, a plan with no rows, a plan that lists the same path twice, and a lock held by another run in the same target.

**It is not a stale-plan gate.** There is no mtime comparison and there must not be one, because you legitimately write file bodies between plan and apply. Instead, apply re-derives every row's live disposition before writing and prints

```
warn <path> changed since the plan was written: plan said CREATE, disk says COLLIDE
```

Treat that warn as a stop sign in your report, not as noise. If the disk moved under the plan the user approved, re-plan and get a fresh yes rather than proceeding on a warning.

### What apply does, in order

1. Reads the plan and runs the refusals above.
2. Takes `.icm/lock/` as a mutex for the whole run, then takes the stamp.
3. Pass one: re-classifies every row live and decides which rows need a write. No writes happen in this pass. It also counts the survey rows and says it will not act on them.
4. Pass two: writes the manifest header, then walks the rows, appending each manifest row immediately after the write it describes. `MKDIR`, `CREATED`, `MODIFIED`, `PARKED` and `SKIPPED` are the five action words.
5. Writes `COMPLETE` in the backup directory after the last row.
6. Runs `icm-check.sh` on the result unless `--no-check`, prints its summary line, and says explicitly that the check does not change apply's exit status.
7. Prints the next-steps block, with the rollback hint last.

The manifest is `<target>/.icm/backup/<STAMP>/manifest.txt`, tab separated, header `# format: ACTION<TAB>RELPATH<TAB>PRE-SHA<TAB>POST-SHA<TAB>MODE`. `STAMP` is a UTC timestamp plus the pid, so two runs in the same second cannot share a backup directory. The backup holds the pre-image of every `MODIFIED` row plus `manifest.txt` and `COMPLETE`. `CREATED` rows get no pre-image, because there was nothing there. The plan is not copied into the backup.

### What you add to apply's own report

Apply already runs the checker and prints the four next-steps lines. Your job is the part it cannot do: name the count of created files, name the modified files explicitly, and name every parked collision with its path in `.icm/proposed/` and the command to read it:

```sh
diff -u ./IDENTITY.md ./.icm/proposed/IDENTITY.md
```

Apply writes that diff for you at `.icm/proposed/<relpath>.diff`, so point the user at whichever they prefer. A user who runs `git status` after an apply and sees entries they were never told to expect has been surprised by a tool that promised no surprises.

## MODE: rollback

```sh
sh "$ICM_HOME/scripts/icm-rollback.sh" --list .
sh "$ICM_HOME/scripts/icm-rollback.sh" --stamp 20260830T000000Z-1234 .
```

| Flag | Meaning |
|---|---|
| `--stamp STAMP` | Roll back this run. `STAMP` is a directory name under `.icm/backup/` |
| `--list` | List the runs available to roll back, then stop |
| `--force` | Roll back a run already marked rolled back |
| `-h`, `--help` | Print usage and exit 0 |

With no `--stamp` it takes the newest run that has not already been rolled back. Exit 0 fully undone or nothing to undo. Exit 1 something was left alone because you changed it after apply. Exit 2 refused: no backup, bad stamp, usage error.

What it reverses, per manifest row:

- `MODIFIED` is restored from the stored pre-image, with its recorded mode, but only while the file still holds the bytes apply left. Changed since apply means a human has been in there: it is reported and left alone. Their edit outranks your undo.
- `CREATED` is deleted, but only while still byte identical to what apply wrote.
- `PARKED` removes the candidate and its `.diff` under `.icm/proposed/`. Your file was never touched, so there is nothing to restore.
- `MKDIR` directories this run made are removed, in reverse order. A directory that was already yours is never pruned.

Running it twice is a no-op. Rollback never touches a path with no row in the manifest, and `git clean` is not a verification step. If the user wants a wider undo than the manifest covers, that is a git operation and you say so rather than improvising one.

## The collision policy, in full

This is the part of the toolkit that earns trust, so it is written out rather than summarised.

**A file that exists is never rewritten. The only in-place edits are the two `adopt` rows, inside the markers, after a backup.**

| Case | Policy |
|---|---|
| Target does not exist | `CREATE`. Free. |
| Target exists, byte-identical to the candidate | `SKIP`. Nothing to do, and saying nothing happened is honest. |
| Target is `CLAUDE.md` or `.gitignore` and differs, markers well formed | `ADOPT`. Pre-image backed up, then only the text between the icm markers is rewritten. |
| Target exists, role is `create`, and differs | `COLLIDE`. The candidate and its diff go to `.icm/proposed/`. Your file stays exactly as it is. |
| Target is not a regular file: a symlink, a directory, a FIFO, a device | `COLLIDE`. The inode is not touched. |
| Target is an adopt-role file with a malformed marker set | `COLLIDE`. Splicing into it would silently delete part of the file. |
| Target is a `_config/` rule book that already exists | `COLLIDE`, always, even if it looks stale. Rule books are the human's pen. |
| Target matches a `never_write` glob, at any depth, or resolves outside the target | `REFUSE`. No candidate, no proposal, no note about how it could be done. |

**Resolving a collision** is a separate, later, human-led act. You may offer to walk the diff and merge by hand with the user watching. You may never merge because it seemed obvious. A doctrine change to a rule book goes to `_log/FORGE-PROPOSALS.md` through `skills/icm-forge/SKILL.md`.

## The case the user actually cares about: the messy tree

Point this at an un-neatened folder tree and the goal is to make it legible. Be clear about who does what: the script reports and you decide.

Plan's survey gives you the evidence. It records, per folder, the direct file count, the subfolder count, whether a `CONTEXT.md` is already there, whether the name carries a leading number, and whether an output-like child exists. Then it assigns one of four verdicts.

| Verdict | Condition |
|---|---|
| `has-card` | The folder already holds a `CONTEXT.md` |
| `staged` | Warrants a card, and carries a stage signal: a leading number in the name, or an output-like child |
| `card` | Warrants a card: two or more direct files, no `CONTEXT.md`, not asset-only |
| `none` | Empty, one file, asset-only, or a vendor drop |

Three rules govern what you do with that table, and they are yours, not the script's.

1. **Nothing moves by default.** The default action is a job card in place. The folder keeps its name, its path and its history. The tree stops being messy because it becomes legible, not because it was rearranged. This is almost always the right answer and it is the one you recommend.
2. **Moving is opt-in, per row, and needs its own yes** after the plan is already approved. Check the working tree is clean under version control first, and say plainly that moving files rewrites paths other things may point at.
3. **Unclear stays unclear.** A folder the survey called `none` that you cannot classify is listed as needs classification, never quietly dropped and never guessed into a stage. Ask. The user knows what `misc/` was.

A `staged` verdict means the folder looks like a pipeline stage. It does not mean it is one. A set of date-ordered folders under one parent is usually runs rather than stages, and the script cannot tell the difference.

### Who produces what

| Artifact | Produced by |
|---|---|
| `IDENTITY.md` and its workspace map | `icm-apply.sh`, from the built-in body |
| The root `CONTEXT.md` routing table | `icm-apply.sh`, from the built-in body |
| The survey and its four verdicts | `icm-plan.sh`, as evidence |
| A job card inside an existing folder | `/icm-context`, one at a time, with a human |
| The needs-classification list | You, reading the survey |
| Files moved | Nobody, unless the user asked for it row by row |

That is the whole trick: the structure is a description of the project, not a replacement for it.

## After any apply

1. Read the check summary apply printed. If you want the full report, run `sh "$ICM_HOME/scripts/icm-check.sh" .` and report it honestly. Findings against files you adopted are open work, not failures of the retrofit, and you say which is which.
2. Route the leftovers:
   - Folders the survey called `card` or `staged` and that still lack one: `skills/icm-context/SKILL.md`.
   - Drift between the routing files and the disk: `skills/icm-sync/SKILL.md`.
   - Rule book doctrine changes: `skills/icm-forge/SKILL.md`, which proposes and never edits.
3. Append one ledger line via `skills/icm-log/SKILL.md`, in the fixed format from `references/ledger.md` of `out-of-the-loop`:

```
| Date | Task | Tier | Anchor | Verify cycles | Holes: plan/hunt/review/audit | Workarounds | Call fired | Artifact |
```

Record the collision count in the artifact column. A retrofit with many collisions is not a bad retrofit. It is a project with a lot of existing thinking in it, which is the case this skill was built for.

## Machine-enforced vs model judgment

Per `$ICM_HOME/spec/authority-model.md`. Every row below was verified against the scripts in this checkout. Nothing is claimed that no script does.

**Machine-enforced.** Scripts decide. You report the verdict, you do not negotiate it.

| Rule | Enforced by | Fails when |
|---|---|---|
| No write without a plan on disk | `scripts/icm-apply.sh`, exit 2 when `<target>/.icm/plan.txt` is absent | the plan file is missing |
| A plan cannot be applied to a different project | `scripts/icm-apply.sh`, comparing the plan's `# target:` header to the resolved target | the two differ, exit 2 |
| One apply at a time per target | `scripts/icm-apply.sh`, which takes `.icm/lock/` before pass one | a second run starts, exit 2. `--force-unlock` clears a lock a killed run left |
| A plan may not name the same path twice | `scripts/icm-apply.sh`, before pass two | a hand-edited plan duplicates a row, exit 2 |
| `never_write` globs are refused at any depth | `scripts/icm-plan.sh` and `scripts/icm-apply.sh`, reading `icm.defaults.json` | a managed path resolves inside one |
| A write must land inside the target | `scripts/icm-apply.sh`, resolving the destination's parent physically before every write | a managed directory is a symlink out of the tree |
| Collision detection, all four sub-cases | `scripts/icm_lib.sh` `icm_classify`, called by both plan and apply | the path exists and apply must not write it |
| Live re-classification before every write | `scripts/icm-apply.sh` pass one, printing `warn <path> changed since the plan was written` | the disk moved between plan and apply |
| A half-applied target is distinguishable | `scripts/icm-apply.sh` error trap, exit 3 with the rollback command | apply aborts part way through |
| Rollback fidelity | `scripts/icm-rollback.sh`, comparing the recorded hash against the file before removing or restoring it | a file changed after apply, in which case it is kept and reported |
| The workspace is checked after apply | `scripts/icm-apply.sh`, which runs `scripts/icm-check.sh` unless `--no-check` | never; the check's status deliberately does not change apply's exit status |
| Frontmatter, sections, budgets, adapters, drift, routes, fences, placeholders | `scripts/icm-check.sh` | see `skills/icm-sync/SKILL.md` for the full table and what each check really covers |
| Grounding invariant, optional | `scripts/check_evidence.py`, run by `scripts/icm-check.sh` when `python3` and `wiki/` both exist | a wiki fact is absent from its linked raw. Skipped otherwise, and the skip is reported, never hidden |

**Not enforced by any script, whatever other documents imply.** Say so rather than implying a machine is watching.

- Apply does **not** refuse a stale plan. There is no mtime comparison. It warns and proceeds.
- `icm-check.sh` has **no** check for `never_write` or excluded folders. That enforcement lives in plan and apply only, because the checker is report-only and never proposes a write.
- `icm-check.sh` has two link checks and they are not the same one. `routes` walks only files literally named `CONTEXT.md` and grades its routing tables. `links` walks every `.md` under the target and grades every markdown link target in it.
- `icm-check.sh` takes `--only <id>` as well as each check's own flag. There are eleven ids; an id outside that set exits 2 and lists them.
- Nothing reads `wiki/index.md`. Index and disk agreeing is a model-performed safe fix, in `skills/icm-sync/SKILL.md`.

**Model judgment.** No script can settle these. They are yours, and every one of them is a proposal to the user rather than an action.

- Which existing folder is which stage. A survey verdict is evidence, not a conclusion.
- Whether a numbered folder set is stages or dated runs.
- Whether an existing `CONTEXT.md` genuinely does the job. The script can check headings and size. Only you can read whether the content routes.
- What a folder is for, when the folder name is `misc/`, `stuff/` or `temp/`. When you cannot tell, needs classification is the correct answer, not a guess.
- Whether a rule book should re-export an existing conventions file or hold its own.
- Whether the routing table covers the work the user actually does.
- The wording of every file you write by hand.

**Neither, and this is the important one.** Some things are nobody's to automate.

- Moving or renaming a user's folders. That needs its own explicit yes, per row, after the plan is already approved.
- Editing a `_config/` rule book. A script may create a rule book that does not exist, once, as part of an install. No script and no agent ever edits a rule book that exists. An existing rule book is always a `COLLIDE`: the toolkit's version goes to `.icm/proposed/` and a human decides.
- Resolving a collision. The candidate sits in `.icm/proposed/` until a human merges it.
