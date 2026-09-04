# CLI Contract

The single source of truth for what the toolkit's scripts are, what they take, what they
write, and what every skill and every document is allowed to say about them.

This file exists because the repo currently ships three descriptions of one program. The
scripts do one thing, `skills/icm-retrofit/SKILL.md` describes a second thing, and
`docs/retrofit.md` describes a third. Every name in this file is now the only name. Where a
script, a skill or a doc disagrees with this file, that file is the bug.

## Precedence

1. `icm.defaults.json` owns every number, every glob and every required-section list.
2. This file owns every command name, flag, argument, exit code, artifact path, artifact
   format and vocabulary word.
3. `BUILD-CONTRACT.md` owns how the source is written.
4. The rest of `spec/` owns the methodology.

If a number appears here, it is wrong. Cite `icm.defaults.json`. If a command shape appears
in `README.md`, `docs/`, or a `SKILL.md` and differs from this file, this file wins.

## Status of every decision below

Every section is a decision, not a proposal. Sections marked **BUILD** name work that does not
exist yet and must be implemented. Sections marked **DELETE** name text that must be removed.
Sections marked **KEEP** name behaviour that already ships correctly and must not be changed.

---

## 1. The one program

Say this, and nothing else, when describing what the toolkit does to a project.

> The toolkit installs a fixed set of context files into a project and keeps them honest.
> `icm-plan.sh` decides what installing would do and writes one plan file. It also walks your
> tree and reports which folders look like they want a job card. `icm-apply.sh` executes the
> plan and nothing else. `icm-rollback.sh` undoes one apply run. `icm-check.sh` verifies a
> workspace and never writes to it. `icm-loop.sh` counts the ledger into one index file and
> writes nothing else. Job cards for your existing folders are written by `/icm-context`, which
> is a conversation, not a script.

Three consequences that every document must respect.

- **Apply installs a fixed set of paths.** It never invents a path from the tree.
- **Plan surveys the tree.** It scores folders and proposes a mapping. It does not turn that
  survey into writes.
- **The model does the naming.** The script decides what exists. You decide what it means.

---

## 2. Install layout and how a skill finds the scripts

This resolves blocker F1.

### Where the toolkit lives

`scripts/` stays at `<toolkit-root>/scripts/`. It is never copied anywhere else. Neither
install method moves it, and no skill directory ever holds a copy of it.

| Install method | Where the toolkit root is |
|---|---|
| Plugin marketplace | The plugin root. `.claude-plugin/marketplace.json` sets `"source": "./"`, so the whole repo lands and the plugin root is the repo root. `CLAUDE_PLUGIN_ROOT` points at it. |
| Manual copy | The clone directory. `README.md`'s install block already clones the whole repo; only `skills/icm-*` is copied into `~/.claude/skills/`. The scripts stay in the clone. |

**DELETE.** Any suggestion to copy `scripts/`, `spec/`, `interview-templates/` or
`icm.defaults.json` alongside the skills. That produces one drifting copy per skill and breaks
the scripts' own root resolution, because `ICM_HOME=$(cd "$ICM_SELF/.." && pwd)` would then
resolve to the skills directory.

### The resolution preamble

**BUILD.** Every `SKILL.md` that invokes a script or reads a `spec/` file opens its first
command block with this preamble, byte for byte identical across every skill so a test can
assert it:

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

Precedence is deliberate: an operator override wins, then the plugin root, then the documented
clone path.

After the preamble, every invocation is absolute and every path is quoted:

```sh
sh "$ICM_HOME/scripts/icm-plan.sh" .
sh "$ICM_HOME/scripts/icm-apply.sh" .
sh "$ICM_HOME/scripts/icm-rollback.sh" .
sh "$ICM_HOME/scripts/icm-check.sh" .
```

Reads of toolkit material use the same variable: `$ICM_HOME/spec/layers.md`,
`$ICM_HOME/icm.defaults.json`. A bare `spec/budgets.md` in a skill's read table is a defect,
because the model's working directory is the user's project.

**DELETE.** Every bare `sh scripts/icm-*.sh` in `README.md`, `docs/`, and every skill.

**BUILD.** `README.md` gains one sentence that exists nowhere today, immediately after the
install section: where the scripts live after each install method, and the `ICM_HOME` line.

There is no `bin/icm`, no PATH install, and no wrapper. One resolution mechanism, not two.

---

## 3. The scripts

Five scripts. No others. `scripts/icm_lib.sh` is dot-sourced, never executed.
`scripts/check_evidence.py` is optional and is only ever invoked by `icm-check.sh`.

### 3.0 Rules common to all five

- POSIX `sh`. Verified with both `sh -n` and `dash -n`.
- Flags and the positional target may appear in any order. More than one positional target is
  a usage error.
- `-h` and `--help` print usage to stdout and exit 0.
- An unknown `--flag` prints `FAIL unknown flag: <flag>` plus usage to stderr and exits 2.
- The target directory defaults to `.`.
- Every refusal names a command that does work. A refusal that only says no is a defect.
- **BUILD.** Target resolution must fail loudly. `icm_abspath` uses `( cd -- "$1" && pwd -P )`,
  checks the status, and calls `icm_die` (exit 2, `FAIL` line) when it fails. A directory whose
  name starts with `-`, or that cannot be traversed, exits 2 with a named message, never a raw
  shell error and never exit 1.
- **BUILD.** `[ -e "$TARGET/.icm" ] && [ ! -d "$TARGET/.icm" ]` is a preflight refusal, exit 2.

### 3.1 Exit codes

One scheme, all five scripts, documented in `README.md` next to the command list.

| Code | Meaning |
|---|---|
| 0 | Clean. Nothing is waiting on you. |
| 1 | Finished, and a human decision is waiting. Collisions parked, or rollback kept a file you edited. |
| 2 | Refused before anything was written. Usage error, bad target, missing plan, dirty repo. |
| 3 | **BUILD.** Aborted part way through. The target may be half changed. `icm-apply.sh` only. |

Exit 3 exists because a crashed apply currently exits 1, which is indistinguishable from the
ordinary collision outcome, so a wrapper cannot tell a normal day from a half-applied target.

`set -e` alone does not produce exit 3. **BUILD.** `icm-apply.sh` installs an error trap that
prints `FAIL apply aborted after <n> write(s). run: scripts/icm-rollback.sh --stamp <STAMP>`
and exits 3.

### 3.2 `icm-check.sh`

```
usage: icm-check.sh [--only ID]... [--<check>]... [--all] [-h|--help] [target-dir]
```

Report only. Never writes inside the target. **KEEP.**

**Check ids. This is the complete list. There are no others.**

| id | Flag | What it checks |
|---|---|---|
| `self` | `--self` | `sh -n`, the bashism sweep, defaults parse, banned frontmatter keys |
| `frontmatter` | `--frontmatter` | `skills/<name>/SKILL.md` keys and name-equals-dirname |
| `budgets` | `--budgets` | character and line ceilings from `icm.defaults.json` |
| `adapters` | `--adapters` | `CLAUDE.md` aliases `IDENTITY.md` and is not a copy of it |
| `drift` | `--drift` | the workspace map in `IDENTITY.md` against the real tree |
| `sections` | `--sections` | required sections from `icm.defaults.json` |
| `routes` | `--routes` | every routing target inside a `CONTEXT.md` exists on disk |
| `links` | `--links` | **BUILD.** every relative link target in every `.md` under the target exists |
| `fences` | `--fences` | markdown code fences balanced |
| `placeholders` | `--placeholders` | no unfilled double-brace placeholder survives in live prose |
| `evidence` | `--evidence` | the deep grounding sweep, needs `python3` and `wiki/` |

**BUILD: `--only ID`.** Four skills already document it. Implement it rather than delete it.
`--only` takes exactly one id, may be repeated, and selects that check. An unrecognised id
prints `FAIL unknown check id: <id>` followed by the eleven valid ids, and exits 2. The error
names the id, not the flag.

**BUILD: the `links` check.** `routes` only walks files literally named `CONTEXT.md` and only
extracts routing-table tokens. That leaves `README.md`, every doc, every spec and every
`SKILL.md` files unchecked, which is why `IDENTITY.md` rule 5 has no machine behind it and two
dead links ship today. `links` walks every `.md` under the target, honours `excluded_globs`,
extracts markdown link targets, skips `http*` and anchors, and FAILs on a relative target that
resolves to nothing.

**DELETE from every skill and doc: the check ids `map`, `paths`, `index`, and the id `links`
as a synonym for `routes`.**

| Phantom id | Ruling |
|---|---|
| `map` | Rename every mention to `drift`. It is the same check. |
| `links` | Now real, and it is **not** `routes`. Keep both rows. `routes` is CONTEXT.md routing tables. `links` is every relative link everywhere. |
| `paths` | Delete from every check table. `never_write` and excluded folders are enforced by `icm-plan.sh` and `icm-apply.sh`, never by the checker, which is report-only by contract and never proposes a write. Attribute it to plan and apply, the way `skills/icm-retrofit/SKILL.md` already does. |
| `index` | Delete from every machine-enforced table. Nothing in `scripts/` reads `wiki/index.md`. Move it to the model-performed safe-fix list in `skills/icm-sync/SKILL.md`, citing `spec/authority-model.md`. |

**DELETE: the hedge "if that build of the script does not take `--only`, run the whole thing".**
There is no such build. Once `--only` exists the hedge is noise; until it exists the hedge is
fiction.

### 3.3 `icm-plan.sh`

```
usage: icm-plan.sh [--archetype quick|full|wiki] [--allow-dirty] [--quiet]
                   [-h|--help] [target-dir]
```

Writes exactly one file: `<target>/.icm/plan.txt`. Nothing else in the target is created,
modified or deleted, under any circumstances.

| Flag | Meaning |
|---|---|
| `--archetype ID` | **DONE.** Which install manifest to plan: `quick` (Layers 0/1/3), `full` (adds `output/`), `wiki` (adds `raw/` and `wiki/`). Default `quick`. |
| `--allow-dirty` | **KEEP.** Plan anyway when the target is a git repo with uncommitted work. |
| `--quiet` | **KEEP.** Write the plan, print only the counts. |

Exit: 0 plan written and nothing collides. 1 plan written with collisions to decide. 2 refused.

**BUILD.** Plan's stdout gains a closing note, because the dry run is not as invisible as the
docs claim: `.icm/` is only added to `.gitignore` at apply, so a first plan leaves `?? .icm/`
in `git status`.

```
note plan wrote only .icm/plan.txt. until you run apply, .icm/ is not in your .gitignore,
note so git status will show it as untracked. nothing else in your project changed.
```

**DELETE.** `docs/retrofit.md`'s claim that "a dry run leaves your working tree clean and your
diff empty". Plan must not write `.gitignore`. One file, no exceptions.

### 3.4 `icm-apply.sh`

```
usage: icm-apply.sh [--plan FILE] [--dry-run] [--no-check] [-h|--help] [target-dir]
```

| Flag | Meaning |
|---|---|
| `--plan FILE` | **KEEP.** Use this plan instead of `<target>/.icm/plan.txt`. |
| `--dry-run` | **KEEP.** Say what would happen, write nothing. |
| `--no-check` | **BUILD.** Skip the closing `icm-check.sh` run. |

**There is no `--rollback` flag and there never was.** Rollback is a separate script.

**BUILD.** `--rollback` gets its own case ahead of the unknown-flag catch-all:

```sh
--rollback)
    printf 'FAIL --rollback is not a flag on apply.\n' >&2
    printf 'note to undo an apply, run: scripts/icm-rollback.sh [--stamp STAMP] [target-dir]\n' >&2
    printf 'note run scripts/icm-rollback.sh --help for the options.\n' >&2
    exit 2
    ;;
```

Do not print `"$TARGET"` in that message. The flag loop runs before any positional argument is
consumed and before `icm_abspath`, so `$TARGET` is empty or unresolved at that point.

**BUILD.** `icm-rollback.sh` gets the mirror treatment for `--plan` and `--dry-run`, naming
`icm-apply.sh`.

**BUILD.** Apply's usage block gains one line: `To undo an apply, run scripts/icm-rollback.sh.`

**BUILD.** Apply runs `icm-check.sh` on the result and prints its summary, because two
documents already promise it and the run currently ends with the rollback hint as the only
forward pointer. Rules:

- The check runs after all writes, unless `--no-check`.
- The check's exit status does **not** change apply's exit status.
- Apply prints the check's `-- summary --` line, then a next-steps block, then its own
  `result:` line last:

```
note read IDENTITY.md, then CONTEXT.md. they are the map.
note folders that do real work still have no job card. run /icm-context to write them.
note review the new files, then commit them: git add -A && git status
note undo this exact run with: scripts/icm-rollback.sh --stamp <STAMP> <TARGET>
```

The rollback hint comes last, not first. Undoing itself must not be the only next step the
tool suggests.

**Apply is not a stale-plan gate.** **DELETE** every claim that apply "refuses a plan older
than the tree". There is no mtime comparison and there must not be one, because the model
legitimately writes file bodies between plan and apply. Apply refuses on exactly two things:
no plan file, and a plan whose `# target:` header names a different directory. Everything else
is handled by re-classification: apply re-derives every row's live disposition before writing
and prints `warn <path> changed since the plan was written: plan said X, disk says Y`.

**BUILD: the CR fix.** Read the header with `sed -n 's/^# target: //p' | head -n 1 | tr -d '\r'`
and print both operands bracketed, so an invisible difference is visible:
`FAIL the plan was written for [%s], not [%s]`.

### 3.5 `icm-rollback.sh`

```
usage: icm-rollback.sh [--stamp STAMP] [--list] [--force] [-h|--help] [target-dir]
```

**These are the flag names. `--stamp`, `--list`, `--force`. KEEP all three.** Every skill that
documents rollback must name all three; today `skills/icm-retrofit/SKILL.md` names none of
them while relying on the "newest run" behaviour they control.

| Flag | Meaning |
|---|---|
| `--stamp STAMP` | Roll back this run. `STAMP` is a directory name under `.icm/backup/`. |
| `--list` | List the runs available to roll back, then stop. |
| `--force` | Roll back a run already marked rolled back. |

Exit: 0 fully undone or nothing to undo. 1 something was left alone because you changed it
after apply. 2 refused.

**BUILD.** `--list` must not print `ok <stamp>` for a run with no `manifest.txt`. Print
`warn <stamp> (incomplete run, no manifest, cannot be rolled back)`. Today it advertises
exactly the runs that `--stamp` then refuses with exit 2.

**BUILD.** Distinguish "no runs recorded" from "runs recorded but unusable". The second case is
a `FAIL` with exit 1, never `result: clean`.

**BUILD: the git note.** Only list paths rollback actually removed or restored. Today every
`CREATED` row is appended to the suggestion list before the checksum test, so a file rollback
deliberately kept lands in a `git clean -f --` line printed under the words "verify this
rollback with". Copy-pasting it deletes the edit the tool just protected. Move the appends
inside the success branches, and relabel the block: `git clean` is not verification.

**BUILD.** When a file is kept, name the decision. `note <path> was kept because you edited it.
keep it, or delete it by hand and rerun to close the run.` The current message says "rerun
after you decide" without naming a decision, and rerunning changes nothing.

### 3.6 `icm-loop.sh`

```
usage: icm-loop.sh [--index] [--starve] [--block] [--today YYYY-MM-DD] [-h|--help] [target-dir]
```

The librarian. It counts, it never judges, and it is the half of the weekly cron that needs no
model. **These are the flag names. `--index`, `--starve`, `--block`, `--today`. KEEP all
four.** One mode flag per invocation; two is a usage error, exit 2. No mode flag means
`--index`.

| Flag | Meaning |
|---|---|
| `--index` | Read `log.ledger`, walk the tree for `skills/*/SKILL.md`, `_config/*.md` and every non-root `CONTEXT.md`, write `log.skill_index`, print it. The only mode that writes, and it writes that one file, atomically. |
| `--starve` | Print the starvation check for the `loop.starve_days` window and stop. Writes nothing. |
| `--block` | Print `icm_body_session_close` between `<!-- ICM-LOOP:START -->` and `<!-- ICM-LOOP:END -->` and stop. Needs no target. The only way the block leaves the toolkit. |
| `--today DATE` | Count windows back from `DATE`. For tests and replays. Refused unless it is a calendar date. |

Exit: 0 clean. 1 at least one index row carries a verdict other than `ok` or `unlogged`, or the
window is starved. 2 refused: no ledger at `log.ledger`, bad target, usage error.

**The line shapes it reads** are the ones `skills/icm-log/SKILL.md` and out-of-the-loop's
`references/ledger.md` define. It selects on the literal in column two: `Miss`, `Use`,
`Patched`. Any other line whose column one is a date counts as work done. It never redefines a
shape and a line in a private shape is silently not counted, which is the enforcement.

**The verdict words. This is the complete list. There are no others.** `rewrite`, `hole`,
`ghost`, `uncovered`, `archive`, `check-write-back`, `unlogged`, `ok`. Each is a count over the
ledger against a threshold in the `loop` section of `icm.defaults.json`, and the index it
writes states the count next to the word. Prose never restates the thresholds as literals.

**What it never does.** Read `_log/FORGE-PROPOSALS.md`. Write a proposal. Write to the ledger.
Touch `_config/`, a job card, a skill, or any file other than `log.skill_index`. Move its own
thresholds.

---

## 4. The plan artifact

**One name. `<target>/.icm/plan.txt`.**

**DELETE, everywhere, with no replacement:** `.icm/plan.md`, `.icm/plan.tsv`, `.icm/plan`,
`.icm/applied-<timestamp>.tsv`. No script writes any of them and none will.

There is no separate human-readable plan file. The human-readable diff is the script's stdout.
A skill that wants to show a user the plan shows them the stdout it just captured.

### 4.1 Format

Tab separated. Five columns. A tab is forbidden inside any field.

```
# icm plan
# toolkit: <toolkit name> <version>
# defaults: <absolute path to icm.defaults.json>
# target: <absolute path>
# archetype: quick|full|wiki
# generated: <UTC, YYYY-MM-DDTHH:MM:SSZ>
# format: STATUS<TAB>ROLE<TAB>RELPATH<TAB>CANDIDATE-SHA<TAB>REASON
```

Rows follow. A line whose first field starts with `#` is a comment. A blank line is ignored.

| Column | Values |
|---|---|
| `STATUS` | `CREATE`, `ADOPT`, `COLLIDE`, `SKIP`, `REFUSE`, `SURVEY` |
| `ROLE` | `create`, `adopt`, or `-` for a `SURVEY` row |
| `RELPATH` | Path relative to the target. May contain spaces. A folder ends with `/`. |
| `CANDIDATE-SHA` | Fingerprint of the body apply would write, or `-` where there is none |
| `REASON` | Non-empty. Never `-`. See section 6.2. |

Tab separation is not cosmetic. Space separation cannot carry a reason column and cannot carry
a folder named `01 - research notes/`, and the toolkit's headline case is exactly the tree that
has both.

**BUILD.** Readers set the separator once and read five fields:

```sh
ICM_TAB=$(printf '\t')
while IFS="$ICM_TAB" read -r P_STATUS P_ROLE P_RP P_SHA P_REASON; do
```

**DELETE.** The claim that the format is `ACTION<TAB>TARGET<TAB>SOURCE<TAB>NOTE`. There is no
`SOURCE` column, because after section 9 there is no source other than the built-in body.

---

## 5. The apply manifest, backup and lock

**One name. `<target>/.icm/backup/<STAMP>/manifest.txt`.**

### 5.1 Layout

```
<target>/.icm/
  plan.txt                          the plan, one file, section 4
  lock/                             held for the duration of an apply run
  proposed/<relpath>                a parked collision candidate
  proposed/<relpath>.diff           the unified diff against your file
  backup/<STAMP>/manifest.txt       what this run did
  backup/<STAMP>/COMPLETE           written only after the last row is durable
  backup/<STAMP>/ROLLED-BACK        written when a rollback finishes with nothing left alone
  backup/<STAMP>/files/<relpath>    the pre-image of every file this run modified
```

### 5.2 STAMP

**BUILD.** `STAMP` is `<UTC %Y%m%dT%H%M%SZ>-<pid>`. A whole-second stamp is not unique: two
applies in the same second share one backup directory, and the second run stores the first
run's output as the "pre-image", producing a manifest row whose pre and post hashes are equal.
Rollback then passes every integrity gate, restores the toolkit's own output, and prints
`result: clean` while the user's original bytes exist nowhere.

**BUILD.** Apply refuses if `.icm/backup/$STAMP` already exists. It never merges into one.

### 5.3 The lock

**BUILD.** Apply takes `mkdir "$TARGET/.icm/lock"` as a mutex immediately after the plan-target
check and before `STAMP` is taken, which is before pass 1. A mutex scoped to pass 2 does not
close the race, because pass 2 dispatches on pass 1's verdicts and never re-checks the disk;
the race is between one run's pass 1 and another run's pass 2.

- If the lock exists, exit 2 with `FAIL another apply is running in this target`.
- The lock directory holds a `pid` file with the pid and the UTC start time.
- Release it in the existing trap, not a second bare `trap`, which would replace the cleanup
  handler and leak the work directory:
  `trap 'rmdir "$TARGET/.icm/lock" 2>/dev/null; icm_cleanup' EXIT INT TERM`
- **BUILD.** `--force-unlock` on apply removes a stale lock and says whose pid it was. Without
  it, a killed CI job bricks every future apply.

### 5.4 Signals

**BUILD.** `trap 'icm_cleanup' INT TERM` does not stop the script. A POSIX trap handler that
does not exit returns to the script, so Ctrl-C deletes the work directory and apply keeps
running into a loop iteration whose candidate body has been removed underneath it. Use:

```sh
trap 'icm_cleanup' EXIT
trap 'icm_cleanup; exit 130' INT
trap 'icm_cleanup; exit 143' TERM
```

### 5.5 Manifest format

Tab separated. Five columns. Written durably as the run proceeds, never assembled in the
temporary directory and copied at the end.

```
# icm apply manifest
# stamp: <STAMP>
# applied: <UTC ISO>
# target: <absolute path>
# toolkit: <toolkit name> <version>
# sha-mode: shasum|sha256sum|degraded
# format: ACTION<TAB>RELPATH<TAB>PRE-SHA<TAB>POST-SHA<TAB>MODE
```

| ACTION | Meaning |
|---|---|
| `MKDIR` | This run created this directory. `PRE-SHA`, `POST-SHA`, `MODE` are `-`. |
| `CREATED` | This run wrote a file where nothing existed. `PRE-SHA` is `-`. |
| `MODIFIED` | This run rewrote the managed block of an existing file. The pre-image is under `files/`. |
| `PARKED` | This run wrote a candidate and its diff into `proposed/`. Your file was not touched. |
| `SKIPPED` | Already identical. Nothing happened. |

The manifest action words are deliberately different from the plan disposition words. A plan
row says what apply intends. A manifest row says what apply did. Reusing `COLLIDE` for both
was one of the ways the three programs blurred together.

**BUILD: durability.** Create `backup/$STAMP/manifest.txt` with its header before the write
loop. Append each row immediately after the write it describes. Write `backup/$STAMP/COMPLETE`
after the last row. Delete the temporary-manifest path entirely. Today the manifest is copied
into place only after the loop, so any error, Ctrl-C or full disk destroys the only index that
makes the pre-images reachable, and rollback then reports `every recorded run is already rolled
back / result: clean` while every change is still on disk.

**BUILD: rollback reads COMPLETE.** A run directory with a manifest and no `COMPLETE` is an
interrupted run. Rollback replays it and says so. It is never treated as a run that does not
exist.

**BUILD: MODE.** Record the destination's mode. `icm_atomic_write` writes a fresh temp file
under the caller's umask and renames over the destination, so a mode 600 file is silently
widened to 644 and a mode 444 file is rewritten without a word. Capture the existing mode
before the write, `chmod` the temp file to it before the rename, record it, and have rollback
restore it.

**BUILD: no clobber.** Refuse when `backup/$STAMP/files/$RELPATH` already exists. A duplicated
`ADOPT` row in a hand-edited plan currently overwrites the true pre-image with the post-apply
file.

**BUILD: reject duplicate paths.** Before pass 2, refuse a plan that names the same `RELPATH`
twice: `FAIL the plan lists the same path twice: <path>`, exit 2.

**BUILD: rollback refuses PRE == POST.** A `MODIFIED` row whose pre and post hashes are equal
can never be produced by a correct single run. Refuse it, do not restore from it. This is the
highest-value single guard in this section and it is unconditionally safe: `icm_classify`
returns `SKIP` whenever the candidate equals the file, so `ADOPT` is only reachable when the
content differs.

**BUILD: rollback aborts on the first FAIL for a path.** It must not go on to process a later
row for the same path. A manifest with two rows for one path is corrupt.

**BUILD: prune only what you made.** Rollback removes a directory only when a `MKDIR` row names
it, in reverse order. Delete the blind parent `rmdir`, which currently deletes a user's own
pre-existing empty `wiki/`, `raw/` or `output/` and reports `result: clean`.

---

## 6. The disposition vocabulary

**Five words. There are no others.**

`CREATE` `ADOPT` `COLLIDE` `SKIP` `REFUSE`

`SURVEY` is a sixth `STATUS` value in the plan file. It is **not** a disposition. It carries
the tree walk's findings, apply ignores it entirely, and it never causes a write. It is
defined in section 11.

**DELETE `PRESENT` from every file in the repo.** It appears in `docs/retrofit.md` and
`docs/deck-boards.md` and in no script. The word for "the file exists and already does the job"
is `ADOPT` when the toolkit owns a block inside it, and `SKIP` when the file already holds
exactly what apply would write.

### 6.1 What each word means

| Word | Condition | What apply does |
|---|---|---|
| `CREATE` | Nothing exists at the path. Not a file, not a directory, not a symlink, not a broken symlink. | Writes the whole file. Records a `CREATED` row and a `MKDIR` row for each directory it had to make. |
| `ADOPT` | The path is a regular file, its role is `adopt`, it carries a well-formed managed block or none, and its content differs from the candidate. | Backs up the pre-image, then rewrites **only** the text between the markers. Records `MODIFIED`. |
| `COLLIDE` | The path exists and apply must not write it. See the four sub-cases below. | Writes the candidate to `.icm/proposed/<relpath>` and a unified diff to `.icm/proposed/<relpath>.diff`. Your file is not read-modify-written, not renamed, not moved. Records `PARKED`. |
| `SKIP` | The path already holds exactly what apply would write, byte for byte. | Nothing. Records `SKIPPED`. |
| `REFUSE` | The path matches a `never_write` glob from `icm.defaults.json`, or resolves outside the target. | Nothing at all. No candidate, no proposal, no diff, no suggestion of how it could be done. |

`SKIP` means **already installed and identical**. It has never meant "excluded folder" and it
never will. An excluded folder is never a candidate, so it can never be a `SKIP` row.

**DELETE.** `docs/retrofit.md`'s `SKIP node_modules/ excluded glob`, `SKIP dist/`, `SKIP .git/`
and `SKIP assets/ no candidate files` example rows, and
`skills/icm-retrofit/SKILL.md`'s definition of `SKIP` as "Excluded folder, a `never_write` glob,
an empty or asset-only folder, or a target whose content already matches".

### 6.2 The four COLLIDE sub-cases

**BUILD.** `icm_classify` must return `COLLIDE` for all four. Today only the first is handled.

1. **Different content, create role.** The path is a regular file, its role is `create`, and it
   differs from the candidate. This ships correctly today.
2. **Not a regular file.** Anything at a managed path that is a symlink, a directory, a FIFO, a
   socket or a device. The guard must sit **ahead of** the create test and ahead of the adopt
   test, and it must test `-L` in its own right, because `-e` is false for a dangling symlink:

   ```sh
   if [ -L "$_cl_file" ] || { [ -e "$_cl_file" ] && [ ! -f "$_cl_file" ]; }; then
       printf 'COLLIDE\n'
       return 0
   fi
   ```

   Without this a broken symlink is classified `CREATE`, replaced with no backup at all, and
   then deleted outright by rollback. A live symlink is converted to a regular file and the
   link is never restored. A directory or a FIFO at a managed path aborts apply part way
   through, and a FIFO blocks forever.
3. **Malformed managed block.** An adopt-role file whose marker set is not exactly one
   `<!-- icm:begin -->` followed by exactly one `<!-- icm:end -->`, both outside any code
   fence. Count the markers before splicing. `icm_splice` starts skipping at the begin marker
   and only stops at the end marker, so a missing end marker silently deletes the rest of the
   user's file, and a lone end marker in prose is silently deleted.
4. **Existing rule book.** Any `_config/*.md` that already exists is a `COLLIDE`, always, even
   when it looks stale. Rule books are the human's pen.

**BUILD: containment.** Before every write, resolve the destination's parent physically and
refuse unless it is the target or below it:

```sh
_dest_dir=$(cd "$(dirname "$DEST")" 2>/dev/null && pwd -P) || _dest_dir=""
```

The current guard is textual only (`case "$P_RP" in /*|*..*)`), so a managed folder that is a
symlink to a shared docs tree makes apply write outside the target while the plan names the
path as `wiki/index.md`. Refuse a managed directory that is a symlink and report it as a
`REFUSE` row in the plan, so the operator sees it before apply.

### 6.3 The REASON column is mandatory

Every plan row carries a non-empty reason. This is the whole point of the diff. Today plan
prints `awk '{ print "  " $3 }'` and a user facing a collision is shown one bare filename and
must work out unaided why their file collided and what to do about it.

Reason strings are short, lowercase, and start with a fixed prefix so they can be tested.

| Prefix | Used for | Example |
|---|---|---|
| `layer 0` … `layer 4b` | An install path, naming its layer | `layer 3 rule book, absent` |
| `adapter` | `CLAUDE.md` and friends | `adapter, icm block will be appended` |
| `gitignore` | `.gitignore` | `gitignore, icm block will be appended` |
| `exists and differs` | Collide case 1 | `exists and differs, candidate parked` |
| `not a regular file` | Collide case 2 | `not a regular file (symlink), candidate parked` |
| `malformed icm block` | Collide case 3 | `malformed icm block (no end marker), candidate parked` |
| `rule book exists` | Collide case 4 | `rule book exists, candidate parked` |
| `identical` | Skip | `identical, nothing to do` |
| `never_write` | Refuse | `never_write glob in icm.defaults.json` |
| `outside target` | Refuse | `outside target after resolving symlinks` |
| `survey` | Survey rows | `survey: 34 files, no job card, numeric prefix` |

**BUILD.** Plan's report prints the reason on the same line as the path, and prints one line
under the `COLLIDE` section naming the command that resolves it:

```
COLLIDE - exists and differs, apply parks a candidate and touches nothing
  IDENTITY.md                       exists and differs, candidate parked
  _config/voice.md                  rule book exists, candidate parked
note diff each one with: diff -u <path> .icm/proposed/<path>
note or read the prepared diff at: .icm/proposed/<path>.diff
```

**BUILD: the diff file.** `skills/icm-retrofit/SKILL.md` already tells the model to announce
`.icm/proposed/<relpath>.diff` to the user. It has never been written. Write it in apply's
collide branch. `diff` exits 1 on a difference, so guard it under `set -e`:

```sh
diff -u "$DEST" "$PROPOSED/$P_RP" > "$PROPOSED/$P_RP.diff" 2>/dev/null || true
```

Rollback's collide branch removes the `.diff` alongside the candidate.

---

## 7. The managed path set and archetypes

**BUILD.** `icm_manifest` takes an archetype and emits the rows for it. Installing an empty
knowledge-base scaffold into every project, including a project that will never compile
knowledge, is the fastest way to convince a first-time user the tool did not read their
project.

The archetype names match `skills/icm-scaffold/SKILL.md` exactly. There are three.

| Path | Role | quick | full | wiki |
|---|---|---|---|---|
| `IDENTITY.md` | create | yes | yes | yes |
| `CONTEXT.md` | create | yes | yes | yes |
| `_config/conventions.md` | create | yes | yes | yes |
| `_config/glossary.md` | create | yes | yes | yes |
| `_config/voice.md` | create | yes | yes | yes |
| `_config/style.md` | create | yes | yes | yes |
| `_log/LOOP-LEDGER.md` | create | yes | yes | yes |
| `_log/FORGE-PROPOSALS.md` | create | yes | yes | yes |
| `CLAUDE.md` | adopt | yes | yes | yes |
| `.gitignore` | adopt | yes | yes | yes |
| `output/CONTEXT.md` | create | no | yes | yes |
| `raw/CONTEXT.md` | create | no | no | yes |
| `wiki/index.md` | create | no | no | yes |
| `wiki/log.md` | create | no | no | yes |
| `_config/grounding.md` | create | no | no | yes |

Numbered stage folders are **not** an install row. They are created by `/icm-stage add`.

**BUILD.** The root `CONTEXT.md` routing table contains only rows whose destination exists in
the chosen archetype. A routing table that points at `raw/CONTEXT.md` in a `quick` install is a
route-check failure on a tree the toolkit generated seconds earlier.

**DELETE.** `README.md`'s "What lands in your project" block is wrong twice: it omits `output/`
and it promises a `01_.../` stage folder that never appears. Rewrite it against this table and
mark stage folders as "only via `/icm-stage add`".

---

## 8. Rule book filenames

**Five names. There are no others.** `templates/config/` and the built-in bodies currently
install disjoint sets, and the two names the scripts install
(`_config/writing-rules.md`, `_config/grounding-rules.md`) appear in zero markdown files
anywhere in the repo.

| Canonical path | Archetype | Binds |
|---|---|---|
| `_config/conventions.md` | all | naming, folder shapes, layer discipline |
| `_config/glossary.md` | all | this project's terms and the one meaning each carries |
| `_config/voice.md` | all | audience, tone, vocabulary, evidence standard |
| `_config/style.md` | all | formatting mechanics: headings, tables, links, dates, numbers |
| `_config/grounding.md` | wiki | anything written into `wiki/`; the grounding invariant applied |

**Decision and rationale.** The four-name set wins over the two-name set because it is the set
the entire documentation surface already teaches: `spec/layers.md`, `spec/CONVENTIONS.md`,
`skills/icm-scaffold/SKILL.md`, `skills/icm-stage/SKILL.md`, `skills/icm-log/SKILL.md`,
`skills/icm-forge/SKILL.md` and `interview-templates/config/`. `_config/voice.md` is the worked
example in six places. Renaming the docs to match two shell functions would be renaming the
teaching to match the implementation, which is backwards. `grounding.md` is added as a fifth
because the grounding rule book is real content the wiki archetype needs and folding it into
`conventions.md` would bury the one invariant the toolkit is built on.

**BUILD.** Write five `icm_body_*` functions and five `icm_render` case arms:
`icm_body_conventions`, `icm_body_glossary`, `icm_body_voice`, `icm_body_style`,
`icm_body_grounding`.

**BUILD.** Migrate the existing prose rather than throwing it away:

| Existing body | Section | Goes to |
|---|---|---|
| `icm_body_writing_rules` | Voice | `_config/voice.md` |
| `icm_body_writing_rules` | Structure | `_config/style.md` |
| `icm_body_writing_rules` | Honesty | `_config/voice.md`, except rule 14 which goes to `_config/conventions.md` |
| `icm_body_grounding_rules` | all | `_config/grounding.md` |

`_config/conventions.md` and `_config/glossary.md` are new bodies. Seed their prose from
`interview-templates/config/conventions.md.tmpl` and
`interview-templates/config/glossary.md.tmpl`, with every double-brace placeholder replaced by
a workspace-neutral sentence. A body must never carry a placeholder.

**DELETE `_config/article-template.md`** from `skills/icm-scaffold/SKILL.md`. It is a sixth
name, it puts the word "template" inside `_config/`, and the article shape belongs in
`interview-templates/wiki/article.md.tmpl` for the interview and in `_config/grounding.md`'s
"Article shape" section for the workspace.

**BUILD: settle the "no script writes to `_config/`" contradiction.** `spec/layers.md` and
`spec/CONVENTIONS.md` both say no script writes to `_config/`, while the install manifest
creates files there. Both files adopt this exact wording:

> A script may create a rule book that does not exist, once, as part of an install. No script
> and no agent ever edits a rule book that exists. An existing rule book is always a `COLLIDE`:
> the toolkit's version goes to `.icm/proposed/` and a human decides.

---

## 9. Template policy

**Decision: adopt REC-UNIFY. The built-in shell bodies in `scripts/icm_lib.sh` are the single
source of truth for every byte any script writes. The template directory is demoted to
interview reference, renamed, and never read by any script.**

### 9.1 What is deleted

**DELETE.** `icm_template_for` in `scripts/icm_lib.sh`, in full.

**DELETE.** The template branch of `icm_render`. `icm_render` becomes a pure `case` dispatch
over the managed relpaths, with the existing `*) icm_die "no renderer for $1"` arm kept as the
closed-set guard.

**DELETE.** The three template assertions and the synthetic fixture in `tests/run-tests.sh`.

This is behaviour-preserving. Applying with the template directory present and with it deleted
produces byte-identical workspaces today, because the lookup is blind to the `.tmpl` suffix and
every shipped template carries it, so the branch has never fired once in any shipped
configuration.

### 9.2 What is renamed

**BUILD.** `templates/` becomes `interview-templates/`.

The rename is the point. A directory called `templates/` sitting next to a renderer invites
exactly the precedence mechanism that produced this defect class, and a code comment saying
"scripts do not read this" is a comment nobody opens. The name now states the contract. Update
`IDENTITY.md`'s workspace map, `CONTEXT.md`'s routing row, `spec/placeholder-syntax.md`,
`skills/icm-scaffold/SKILL.md`, `skills/icm-context/SKILL.md`, `skills/icm-stage/SKILL.md`,
`skills/icm-wiki/SKILL.md`, and `icm-check.sh`'s placeholder exemption
(`templates/*) continue ;;` becomes `interview-templates/*) continue ;;`).

`interview-templates/` holds material a skill fills in **in conversation with a human** and
then writes into the workspace itself. It carries `{{SCREAMING_SNAKE}}` onboarding
placeholders, single-brace model-fill instructions, and leading HTML authoring comments. None
of that is safe for a script to stamp out, and no script will be able to.

### 9.3 Why this kills TPL-1

TPL-1 is an empty or truncated template winning the precedence contest and shipping a
zero-byte file that plan, apply and check all call clean. With no precedence contest there is
no winner. The only body any script can write is a heredoc compiled into `icm_lib.sh`, which
cannot be empty without the file failing `sh -n`.

**BUILD: belt and braces anyway.** `icm_render` validates before it emits. It refuses, with
exit 2 and a `FAIL` line naming the relpath, when the rendered body:

- is empty, or
- contains a double-brace placeholder, or
- is missing any section listed for its kind under `required_sections` in
  `icm.defaults.json`.

**BUILD.** Add `required_sections` entries for the managed files that have none today, so the
third test has something to check on more than three files. Without an entry, an eighteen-byte
body passes every gate. The files needing entries are `wiki/index.md`, `wiki/log.md`,
`_log/LOOP-LEDGER.md`, `_log/FORGE-PROPOSALS.md`, and each of the five rule books. The section
names go in `icm.defaults.json`; do not restate them here.

### 9.4 Why this kills the "two sources" class entirely

The class is "the same fact is authoritative in two files". After this change:

- One renderer, one body per managed path, compiled into one file.
- The interview directory is a different kind of artifact with a different consumer, a
  different name, and no code path connecting it to a script.
- The single-brace hole, the `templates/log/` directory that never existed, the unreadable
  template that aborted plan with a bare awk error, and the never-firing `_config/*` lookup
  branch all disappear with the mechanism rather than needing four separate fixes.

**BUILD: two closure tests**, which are the durable part:

1. No file under `scripts/` mentions `interview-templates`. This makes the demotion
   self-enforcing.
2. Every routing target emitted by `icm_body_context_root` for a given archetype appears as a
   `RELPATH` in that archetype's manifest, or exists on disk. This is the real agreement check:
   it does not compare two sources, it asserts the one remaining source is internally closed.

### 9.5 What the skills may say

**DELETE.** `skills/icm-retrofit/SKILL.md`'s `CREATE` row saying apply "Writes the file from
`templates/`". It writes from the built-in body. Say so.

**DELETE.** `docs/retrofit.md`'s example row `CREATE _config/voice.md layer 3 rule book, from
template`.

**BUILD.** `skills/icm-scaffold/SKILL.md`'s rule "Every emitted file comes from a template. If
a template file is missing, stop and say which one. Do not improvise a body." stays true, and
is now unambiguous, because scaffold is an interview: it fills
`interview-templates/` by hand and writes the result. It no longer contradicts a renderer that
falls back silently, because that renderer no longer exists.

---

## 10. What "never overwrites" means

The current wording is false and it is the promise the whole toolkit is sold on. Apply modifies
`CLAUDE.md` and `.gitignore` in place and reports `modified 2`.

### 10.1 The mandated wording

This paragraph, or a faithful shortening of it, is the only form the promise may take. It goes
in `README.md`, `docs/retrofit.md`, `skills/icm-retrofit/SKILL.md` and
`skills/icm-scaffold/SKILL.md`.

> Nothing you wrote is ever deleted or rewritten. Most managed paths are only written when
> nothing exists there. Two of them, `CLAUDE.md` and `.gitignore`, are edited in place, and
> only between `<!-- icm:begin -->` and `<!-- icm:end -->`. Every byte outside those markers is
> unchanged, and the pre-image is copied to `.icm/backup/<stamp>/files/` before the edit.
> Anything else that already exists is a collision: the toolkit's version goes to
> `.icm/proposed/` with a diff beside it, and your file is not touched.

The one-line form, for a table cell or a bullet:

> Your files are never rewritten. `CLAUDE.md` and `.gitignore` get a marked block appended,
> backed up first. Everything else that exists is parked in `.icm/proposed/` for you.

### 10.2 Banned sentences

These must not appear anywhere in the repo. Each is false.

- "Never overwrites a file."
- "it never overwrites a file you wrote"
- "apply only creates files that did not exist"
- "Since `apply` only creates files that did not exist, the backup is usually small."
- "In normal operation this backup is empty, because apply only creates."
- "An existing file is never modified and never replaced."
- "ADOPT ... Nothing. The file is registered in the routing and left exactly as it is."
- "Leaves every ADOPT and SKIP row alone."
- "The backup holds a copy of every file the plan touches in any way, plus the plan itself."

### 10.3 The plan section header

**BUILD.** Rename the plan's `ADOPT` section header so the diff cannot be misread as a no-op.
"Adopt" is a passive word and the skill uses it for "left exactly as it is".

```
ADOPT - your file is kept, apply appends a marked icm block and backs up the original first
```

### 10.4 The backup's real contents

**BUILD.** State it accurately wherever it is described: the backup holds the pre-image of
every `MODIFIED` row, plus `manifest.txt`, plus `COMPLETE`. `CREATED` rows get no pre-image,
because there was nothing there. The plan is not copied into the backup.

---

## 11. The TRANSFER contract

This resolves blockers F3 and `plan-does-not-walk-the-tree`.

### 11.1 What is true today and what is false

Plan iterates a fixed twelve-row manifest and classifies each row. It does walk and prune the
tree, but only as a side effect of building the workspace map inside `IDENTITY.md`. It scores
nothing, proposes nothing, and prints nothing about the user's folders. On a ten-year shared
drive it prints the same rows it prints on an empty directory.

`README.md` and `docs/retrofit.md` are already correct about the workflow: plan, then
`/icm-context`, then `/icm-sync lint`. Do not delete those sections.
`skills/icm-retrofit/SKILL.md` is the file that folds step two into the script and then
misdescribes the script.

### 11.2 The decision

**Plan walks and proposes. Apply installs and nothing more.**

- **BUILD.** Plan performs a real survey walk and emits `SURVEY` rows into `plan.txt` and a
  survey section plus a proposed-mapping table on stdout.
- **KEEP.** Apply executes only the five dispositions. It never writes a job card. There is no
  renderer for `<folder>/CONTEXT.md` and one must not be added, because naming a folder
  honestly is judgment, not classification.
- **KEEP.** Job cards are written by `/icm-context`, from `interview-templates/`, one at a
  time, with a human.

### 11.3 The walk

- Root is the target. Depth is fixed at two: top-level entries and one level of subfolders.
  There is no depth flag.
- Prune every directory whose basename matches an `excluded_globs` entry in
  `icm.defaults.json`.
- Skip directories that the install manifest owns: `_config/`, `_log/`, `raw/`, `wiki/`,
  `output/`, `.icm/`.
- For each surviving directory, record: direct file count, subdirectory count, whether it
  already holds a `CONTEXT.md`, whether its name carries a leading number, and whether it holds
  a child named `output`, `out`, `final`, `exports` or `dist`.

### 11.4 The verdict

Exactly four verdicts. The script assigns them. The model reads them.

| Verdict | Condition |
|---|---|
| `has-card` | The folder already holds a `CONTEXT.md`. |
| `staged` | Warrants a card, and carries a stage signal: a leading number in the name, or an output-like child. |
| `card` | Warrants a card: two or more direct files, no `CONTEXT.md`, not asset-only. |
| `none` | Empty, one file, asset-only, or a vendor drop. |

Asset-only means every direct file's extension is in a fixed asset list held in
`icm.defaults.json` under a new `asset_extensions` key. Do not restate the list in prose.

The verdict is evidence, never a conclusion. `staged` means the folder looks like a pipeline
stage. It does not mean it is one. Numbers in folder names are a signal, not a fact, and a set
of date-ordered folders under one parent is usually runs rather than stages.

### 11.5 The SURVEY row

```
SURVEY<TAB>-<TAB><relpath>/<TAB>-<TAB>survey: <verdict>; files=<n> subfolders=<n> stage-signal=<yes|no>
```

Apply ignores every `SURVEY` row. **BUILD.** Apply counts them and prints one line:
`note the plan also carries <n> survey row(s). apply does not act on them; run /icm-context.`

### 11.6 The proposed mapping table

**BUILD.** Plan prints this from the survey rows. It is real output, not an invented example.

```
SURVEY - folders in your tree, and whether they look like they want a job card

| Folder                | Verdict  | Files | Stage signal | Suggested next step |
|-----------------------|----------|-------|--------------|---------------------|
| 01 - research notes/  | staged   | 34    | yes          | /icm-context one "01 - research notes" |
| drafts/               | card     | 12    | no           | /icm-context one drafts |
| FINAL FINAL v3/       | card     | 6     | no           | /icm-context one "FINAL FINAL v3" |
| misc/                 | none     | 41    | no           | needs classification, ask the user |
| assets/               | none     | 210   | no           | asset-only, nothing to route |

note nothing above is written by apply. job cards are written one at a time with /icm-context.
```

Three rules govern the model's use of this table, and they stay in
`skills/icm-retrofit/SKILL.md` where they belong, attributed to the model rather than to the
script.

1. **Nothing moves by default.** The default action is a job card in place. The folder keeps
   its name, its path and its history. The tree stops being messy because it becomes legible,
   not because it was rearranged.
2. **Moving is opt-in, per row, and needs its own yes** after the plan is already approved.
   Check the working tree is clean under version control first, and say plainly that moving
   files rewrites paths other things may point at.
3. **Unclear stays unclear.** A folder the survey called `none` and you cannot classify is
   listed as "needs classification". Ask. Never guess it into a stage.

### 11.7 What must be deleted from the retrofit skill

**DELETE** from `skills/icm-retrofit/SKILL.md`: every sentence attributing the walk, the
scoring, the mapping table or the job cards to `scripts/icm-plan.sh` writing them. After this
change the script does walk and does score, so those sentences become true only if they say
the script **reports** and the model **decides**. Rewrite, do not just re-point.

**DELETE** the `CREATE stages/02-compile/CONTEXT.md` example row. No renderer can produce it.

**DELETE** "what a messy-tree retrofit produces" as a description of apply's output. Attribute
each item to the step that produces it: the map to apply, the job cards to `/icm-context`, the
needs-classification list to the survey.

---

## 12. Settled ambiguities

Short rulings on facts that two files currently claim differently.

| Question | Ruling |
|---|---|
| How is a character counted for a budget? | `wc -c`. It is byte exact and locale independent. `spec/budgets.md` and `spec/authority-model.md` already say so. **BUILD:** change `icm_chars` from `wc -m` to `wc -c` and delete the code comment claiming `wc -m` is the conservative direction. In a UTF-8 locale it is the permissive one, and every generated `IDENTITY.md` contains multibyte box-drawing characters. |
| Where does the exclusion list come from at runtime? | `icm.defaults.json`, keys `excluded_globs` and `never_write`. `spec/excluded-folders.md` is the human rendering of those keys. **DELETE** every claim that a script reads `spec/excluded-folders.md`; no script does. |
| Does `never_write` match at any depth? | Yes. **BUILD:** `icm_never_write_ok` wraps the candidate in slashes and tests `case "/$1/" in */"$_w_g"/*) return 1 ;;`, still reading the globs from the JSON. It matches only the first component today, so `docs/sub/node_modules/x.md` passes. |
| Does any script auto-apply a lint finding? | No. There is no `icm-sync.sh` and there will not be one. **BUILD:** rename `spec/authority-model.md`'s "Auto applied" column to "Applied by", with values `script` and `model, then reported`, and mark every safe-fix row `model, then reported`. Change the four skill headings from "Safe fix, applied without asking" to "Safe fix, applied by you, then reported". An unwatched model wearing a script's authority is exactly what that spec warns against. |
| What does `scripts/check_evidence.py` need? | `python3` 3.10 or newer. It is optional. Its own tests are stdlib `unittest`, run with `python3 tests/test_check_evidence.py`. **DELETE** `spec/grounding-invariant.md`'s claim that they need `pytest`. |
| What is the real tool list? | Three tiers, not one flat list. **BUILD** in `README.md` and `BUILD-CONTRACT.md`: (1) always required and POSIX, which must add `basename`, `dirname`, `tr`, `rmdir`, `cmp` and `ls` to the current list; (2) hashing, first found of `shasum` then `sha256sum` then a size-plus-mtime fallback, neither hasher POSIX, and say plainly that the fallback weakens rollback's tamper detection only and not apply's never-overwrite, which is a byte compare; (3) optional and guarded, `git` and `python3`. |
| How many patterns are in `spec/CONVENTIONS.md`? | Twenty-three. **BUILD:** fix `README.md` and `CONTEXT.md`, which both say fifteen. Leave the attribution lines alone; "the fifteen conventions" is correct as an upstream boundary. |
| Does the retrofit walkthrough's drift triage stand? | No. **DELETE** "If it flags drift on a tree that was generated ninety seconds ago, your skip list is wrong." A drift warning on a freshly generated tree is a checker bug, not a skip-list problem, and no amount of editing the skip list clears it. **BUILD:** widen the documented-path capture in `icm-check.sh` while keeping the top-level anchor, using space-only strip patterns and never a bracket expression, which would trip the toolkit's own bashism sweep. |

---

## 13. Conformance

### 13.1 What every document must now agree on

Before any doc, skill or script is called done, these must all be true.

1. Every script invocation in prose is `sh "$ICM_HOME/scripts/<name>.sh"`, preceded by the
   resolution preamble in section 2.
2. The only plan path named anywhere is `.icm/plan.txt`.
3. The only manifest path named anywhere is `.icm/backup/<STAMP>/manifest.txt`.
4. The only disposition words used are `CREATE`, `ADOPT`, `COLLIDE`, `SKIP`, `REFUSE`, plus
   `SURVEY` as a non-disposition row kind.
5. The only rule book filenames used are the five in section 8.
6. The only check ids used are the eleven in section 3.2.
7. The only flags named per script are the ones in section 3.
8. The only verdict words used for the index are the eight in section 3.6, and the only
   proposal kinds are `edit`, `new`, `archive` and `rewrite`.
9. The never-overwrite promise uses the wording in section 10.1, and none of the banned
   sentences in section 10.2 appear.
10. No prose says a script writes from `templates/`, and no prose says `templates/` exists.
11. The Session Close body exists once, in `icm_body_session_close` in `scripts/icm_lib.sh`.
    Every generated root `CONTEXT.md` carries it under `## Session Close`, `icm-loop.sh --block`
    prints it, and no `.md` or `.tmpl` restates it.

### 13.2 Tests that enforce it

**BUILD** these in `tests/run-tests.sh`. They are what stop the three programs from growing
back.

| Test | Asserts |
|---|---|
| plan artifact name | No `.md`, `.tmpl` or `.sh` file in the repo names `.icm/plan.` followed by anything other than `txt`. |
| manifest path | No file names `.icm/applied-`. |
| disposition vocabulary | Every uppercase status token in `docs/retrofit.md`, `docs/deck-boards.md` and every `SKILL.md` is one of the six in section 6. |
| check ids | Every backticked check id in every `SKILL.md` is accepted by `icm-check.sh --only <id>` with an exit status of 0 or 1, never 2. |
| flag existence | Every `--flag` shown for an icm script in any `.md` file is accepted by that script, tested by running it with `--help` and grepping the usage block. |
| rollback redirect | `icm-apply.sh --rollback` exits 2 and its stderr contains `icm-rollback.sh`. |
| script resolution | Every `SKILL.md` that names a `scripts/icm-` path also contains the `ICM_HOME=` preamble line, byte for byte. |
| no bare invocation | No `.md` file contains `sh scripts/icm-` without a `$ICM_HOME` prefix. |
| template demotion | No file under `scripts/` contains the string `interview-templates`. |
| routing closure | Every routing target in each archetype's generated root `CONTEXT.md` is a `RELPATH` in that archetype's manifest, or exists on disk. |
| rule book agreement | Every `create _config/...` row in every archetype's manifest has an `icm_render` case arm and an `icm_body_*` function. |
| spaces inside the workspace | A fixture containing a folder named `01 - research notes` **inside** the workspace produces zero drift warns, a top-level `notes.txt` is not reported, and no nested tree row is reported as a top-level path. The existing spaces test only puts a space in the fixture root. |
| non-regular files | A dangling symlink, a live symlink, a directory and a FIFO at a managed path each classify `COLLIDE`, leave the inode untouched, produce a manifest, and park a candidate. |
| malformed block | A `CLAUDE.md` missing its end marker classifies `COLLIDE` and loses no lines. |
| never_write depth | `docs/sub/node_modules/x.md` and `a/.git/config` are both refused. |
| byte count | The checker's reported count for a multibyte fixture equals `wc -c`. |
| adapter shape | The adapter that `skills/icm-scaffold/SKILL.md` documents passes `icm-check.sh --adapters`. |
| the loop | A fresh apply installs a ledger with `## Lines` and a `CONTEXT.md` with `## Session Close` that passes `--sections`. A fixture ledger produces the pinned verdict words `hole`, `rewrite`, `uncovered`, `ghost`, `unlogged`, `ok` and `archive`, the index run changes no file but the index, `--starve` exits 1 on work with no misses and 0 otherwise, `--block` prints the same bytes as the installed Session Close, no ledger exits 2, two modes exit 2, a non-date `--today` exits 2. |

### 13.3 The scaffold adapter rule

**BUILD.** `skills/icm-scaffold/SKILL.md` currently tells the model to copy `IDENTITY.md` into
the adapter file. `icm-check.sh --adapters` fails exactly that shape twice, in a skill whose
frontmatter promises it refuses to report success while the check fails. Rewrite the rule to
match `icm_body_claude_block`: `CLAUDE.md` is an alias, not a copy. It carries `@IDENTITY.md`
and `@CONTEXT.md` inside the icm markers and nothing else. The looser adapters, `AGENTS.md`,
`GEMINI.md`, `.cursorrules` and `.windsurfrules`, need only mention `IDENTITY.md`; say which
form each takes.

---

## 14. Summary of everything deleted

For the agent doing the doc pass, in one list.

| Deleted | From |
|---|---|
| `.icm/plan.md`, `.icm/plan.tsv`, `.icm/plan` | `skills/icm-retrofit/SKILL.md`, `README.md` |
| `.icm/applied-<timestamp>.tsv` | `skills/icm-retrofit/SKILL.md` |
| `ACTION<TAB>TARGET<TAB>SOURCE<TAB>NOTE` | `skills/icm-retrofit/SKILL.md` |
| `sh scripts/icm-apply.sh --rollback` | `skills/icm-retrofit/SKILL.md` |
| The staleness guarantee | `skills/icm-retrofit/SKILL.md` |
| `PRESENT` | `docs/retrofit.md`, `docs/deck-boards.md` |
| `SKIP` meaning excluded or asset-only | `docs/retrofit.md`, `skills/icm-retrofit/SKILL.md` |
| Check ids `map`, `paths`, `index`, and `links` as a synonym for `routes` | four `SKILL.md` files |
| The "that build of the script" hedge | `skills/icm-sync/SKILL.md`, `skills/icm-scaffold/SKILL.md` |
| `_config/writing-rules.md`, `_config/grounding-rules.md`, `_config/article-template.md` | `scripts/icm_lib.sh`, `skills/icm-scaffold/SKILL.md` |
| "Writes the file from `templates/`", "from template" | `skills/icm-retrofit/SKILL.md`, `docs/retrofit.md` |
| `icm_template_for` and the template branch of `icm_render` | `scripts/icm_lib.sh` |
| The nine banned never-overwrite sentences | `README.md`, `docs/retrofit.md`, `skills/icm-retrofit/SKILL.md` |
| "a dry run leaves your working tree clean" | `docs/retrofit.md` |
| "your skip list is wrong" as drift triage | `docs/retrofit.md` |
| "plan walks the tree and scores every folder" as a claim about what the script decides | `README.md`, `skills/icm-retrofit/SKILL.md`, `docs/retrofit.md` |
| The `01_.../` stage folder in "What lands in your project" | `README.md` |
| "patterns 1 to 15", "the fifteen patterns" | `README.md`, `CONTEXT.md` |
| The `pytest` claim | `spec/grounding-invariant.md` |
| The hand-written `case` fragment presented as the one place `never_write` names live in shell logic | `spec/excluded-folders.md` |
