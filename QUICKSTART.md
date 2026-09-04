# Quickstart

Sixty seconds to a working context layer. Pick the section that matches what you are standing
in front of, paste the commands, read the output.

| You have | Go to |
|---|---|
| An empty folder, or a project with no context files | [NEW](#new-scaffold-a-fresh-project) |
| A working repo full of files you cannot afford to break | [OVER](#over-drop-it-on-a-live-project) |
| Years of folders that hold real work and nothing is routed | [TRANSFER](#transfer-pull-a-messy-tree-into-line) |

Every output block below was captured from a real run of these commands against a throwaway
fixture. Two strings are substituted so the blocks read cleanly: the fixture's parent directory
appears as `/home/you`, and the toolkit's own clone path in the `defaults:` line appears as
`~/src/momentrix-icm-kap-toolkit`. Nothing else was edited, including the timestamps and the
counts.

---

## Before the first command

Install the toolkit first. Both methods are in [`README.md`](README.md#install): the plugin
marketplace, or a clone plus a copy of `skills/icm-*`.

Then resolve the toolkit root once per shell. Your working directory is your own project, never
the toolkit, so every invocation is absolute and every path is quoted.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

Five scripts, and there are no others. All five take the target directory as a positional
argument, defaulting to `.`, and all five answer `--help`.

```sh
sh "$ICM_HOME/scripts/icm-plan.sh" .       # dry run, writes .icm/plan.txt and nothing else
sh "$ICM_HOME/scripts/icm-apply.sh" .      # executes that plan and nothing else
sh "$ICM_HOME/scripts/icm-rollback.sh" .   # undoes one apply run
sh "$ICM_HOME/scripts/icm-check.sh" .      # reports only, writes nothing
sh "$ICM_HOME/scripts/icm-loop.sh" .       # compiles the skill index from the ledger, writes that one file
```

Exit codes are one scheme across all five, and they are listed in
[`README.md`](README.md#zero-dependencies). The short version: 0 clean, 1 a human decision is
waiting, 2 refused before writing anything, 3 aborted part way through.

---

## NEW: scaffold a fresh project

An empty folder, or a project that has no context files at all.

There are two ways in and you pick one, not both. The scripted path below installs the layer
files from the bodies compiled into the toolkit, in two commands. `/icm-scaffold` instead runs a
ten question interview and writes the same layers in your words; it refuses to run once
`IDENTITY.md` exists, so run it on the empty folder rather than after an apply.

```sh
cd /home/you/new-project
sh "$ICM_HOME/scripts/icm-plan.sh" .
```

`plan` writes exactly one file, `.icm/plan.txt`, and prints the diff it would execute.

```
# icm-plan (dry run, nothing was changed)
target:   /home/you/new-project
defaults: ~/src/momentrix-icm-kap-toolkit/icm.defaults.json
plan:     /home/you/new-project/.icm/plan.txt

CREATE - absent, apply would write these
  IDENTITY.md                        layer 0 identity, absent
  CONTEXT.md                         layer 1 routing, absent
  _config/conventions.md             layer 3 rule book, absent
  _config/glossary.md                layer 3 rule book, absent
  _config/voice.md                   layer 3 rule book, absent
  _config/style.md                   layer 3 rule book, absent
  _log/LOOP-LEDGER.md                ledger and proposals, absent
  _log/FORGE-PROPOSALS.md            ledger and proposals, absent
  CLAUDE.md                          adapter, icm block will be appended
  .gitignore                         gitignore, icm block will be appended

COLLIDE - apply parks a candidate and touches nothing
  (none)

ADOPT - your file is kept, apply appends a marked icm block and backs up the original first
  (none)

SKIP - already installed and identical, apply would do nothing
  (none)

SURVEY - folders in your tree, and whether they look like they want a job card

  (no folders of your own to survey)

ok   plan written: /home/you/new-project/.icm/plan.txt
ok   CREATE 10   COLLIDE 0   ADOPT 0   SKIP 0   REFUSE 0   SURVEY 0
note plan wrote only .icm/plan.txt. until you run apply, .icm/ is not in your
note .gitignore, so git status will show it as untracked. nothing else in your
note project changed.
result: clean
```

Read those ten rows. Then execute them.

```sh
sh "$ICM_HOME/scripts/icm-apply.sh" .
```

```
# icm-apply
target:   /home/you/new-project
plan:     /home/you/new-project/.icm/plan.txt
stamp:    20260830T055152Z-51685

ok   created  IDENTITY.md
ok   created  CONTEXT.md
ok   created  _config/conventions.md
ok   created  _config/glossary.md
ok   created  _config/voice.md
ok   created  _config/style.md
ok   created  _log/LOOP-LEDGER.md
ok   created  _log/FORGE-PROPOSALS.md
ok   created  CLAUDE.md
ok   created  .gitignore

ok   created 10   modified 0   parked 0   skipped 0
ok   manifest: /home/you/new-project/.icm/backup/20260830T055152Z-51685/manifest.txt

ok   icm-check.sh ran on the result:
     -- summary --
     ok 18   warn 0   FAIL 0
     result: clean
note the check does not change this run status. read the full report with:
note   scripts/icm-check.sh /home/you/new-project

note read IDENTITY.md, then CONTEXT.md. they are the map.
note folders that do real work still have no job card. run /icm-context to write them.
note review the new files, then commit them: git add -A && git status
note undo this exact run with: scripts/icm-rollback.sh --stamp 20260830T055152Z-51685 /home/you/new-project
result: clean
```

That is the whole workspace, on disk:

```
.
./_config
./_config/conventions.md
./_config/glossary.md
./_config/style.md
./_config/voice.md
./_log
./_log/FORGE-PROPOSALS.md
./_log/LOOP-LEDGER.md
./.gitignore
./CLAUDE.md
./CONTEXT.md
./IDENTITY.md
```

Ten paths, the `quick` archetype. Pass `--archetype full` for `output/`, or `--archetype wiki`
for `raw/`, `wiki/` and the grounding rule book, on the **plan** command. What each archetype
installs is in [`README.md`](README.md#the-archetypes).

Next: open `IDENTITY.md` and put your project in it, then `CONTEXT.md`. They are generated
starting points, not the finished article, and they are yours to edit.

---

## OVER: drop it on a live project

A working repo with its own `README.md`, its own `CLAUDE.md`, its own `.gitignore`, and files
you cannot afford to break.

```sh
cd /home/you/acme-api
sh "$ICM_HOME/scripts/icm-plan.sh" .
```

```
# icm-plan (dry run, nothing was changed)
target:   /home/you/acme-api
defaults: ~/src/momentrix-icm-kap-toolkit/icm.defaults.json
plan:     /home/you/acme-api/.icm/plan.txt

CREATE - absent, apply would write these
  IDENTITY.md                        layer 0 identity, absent
  _config/conventions.md             layer 3 rule book, absent
  _config/glossary.md                layer 3 rule book, absent
  _config/voice.md                   layer 3 rule book, absent
  _config/style.md                   layer 3 rule book, absent
  _log/LOOP-LEDGER.md                ledger and proposals, absent
  _log/FORGE-PROPOSALS.md            ledger and proposals, absent

COLLIDE - apply parks a candidate and touches nothing
  CONTEXT.md                         exists and differs, candidate parked
note diff each one with: diff -u <path> .icm/proposed/<path>
note or read the prepared diff at: .icm/proposed/<path>.diff

ADOPT - your file is kept, apply appends a marked icm block and backs up the original first
  CLAUDE.md                          adapter, icm block will be appended
  .gitignore                         gitignore, icm block will be appended

SKIP - already installed and identical, apply would do nothing
  (none)

SURVEY - folders in your tree, and whether they look like they want a job card

| Folder                         | Verdict  | Files | Stage signal | Suggested next step
|--------------------------------|----------|-------|--------------|---------------------
| docs/                          | card     |     2 | no           | /icm-context one docs
| src/                           | card     |     2 | no           | /icm-context one src

note a verdict is evidence, not a conclusion. a number in a folder name is a
note signal that it might be a stage; it is not proof that it is one.
note nothing above is written by apply. job cards are written one at a time
note with /icm-context, in conversation, and nothing moves by default.

ok   plan written: /home/you/acme-api/.icm/plan.txt
ok   CREATE 7   COLLIDE 1   ADOPT 2   SKIP 0   REFUSE 0   SURVEY 2
note plan wrote only .icm/plan.txt. until you run apply, .icm/ is not in your
note .gitignore, so git status will show it as untracked. nothing else in your
note project changed.
warn 1 file(s) collide. apply will never overwrite them; it writes the
warn candidate to .icm/proposed/ and leaves your file exactly as it is.
result: collisions to decide
```

Exit 1 here does not mean failure. It means a human decision is waiting: this project already
had a `CONTEXT.md` of its own.

Nothing you wrote is ever deleted or rewritten. Most managed paths are only written when nothing
exists there. Two of them, `CLAUDE.md` and `.gitignore`, are edited in place, and only between
`<!-- icm:begin -->` and `<!-- icm:end -->`. Every byte outside those markers is unchanged, and
the pre-image is copied to `.icm/backup/<stamp>/files/` before the edit. Anything else that
already exists is a collision: the toolkit's version goes to `.icm/proposed/` with a diff beside
it, and your file is not touched.

```sh
sh "$ICM_HOME/scripts/icm-apply.sh" .
```

```
# icm-apply
target:   /home/you/acme-api
plan:     /home/you/acme-api/.icm/plan.txt
stamp:    20260830T055159Z-53330

note the plan also carries 2 survey row(s). apply does not act on them; run /icm-context.
ok   created  IDENTITY.md
warn collide  CONTEXT.md left untouched, candidate is in .icm/proposed/CONTEXT.md
warn   exists and differs, candidate parked
ok   created  _config/conventions.md
ok   created  _config/glossary.md
ok   created  _config/voice.md
ok   created  _config/style.md
ok   created  _log/LOOP-LEDGER.md
ok   created  _log/FORGE-PROPOSALS.md
ok   adopted  CLAUDE.md (pre-image in .icm/backup/20260830T055159Z-53330/files/CLAUDE.md)
ok   adopted  .gitignore (pre-image in .icm/backup/20260830T055159Z-53330/files/.gitignore)

ok   created 7   modified 2   parked 1   skipped 0
ok   manifest: /home/you/acme-api/.icm/backup/20260830T055159Z-53330/manifest.txt

ok   icm-check.sh ran on the result:
     -- summary --
     ok 17   warn 0   FAIL 3
     result: FAIL
note the check does not change this run status. read the full report with:
note   scripts/icm-check.sh /home/you/acme-api

note read IDENTITY.md, then CONTEXT.md. they are the map.
note folders that do real work still have no job card. run /icm-context to write them.
note review the new files, then commit them: git add -A && git status
note undo this exact run with: scripts/icm-rollback.sh --stamp 20260830T055159Z-53330 /home/you/acme-api
warn nothing that collided was overwritten. read .icm/proposed/ and merge by hand.
warn each candidate has a .diff beside it: diff -u <path> .icm/proposed/<path>
result: a decision is waiting
```

`git status` shows the whole change, and it is small:

```
 M .gitignore
 M CLAUDE.md
?? IDENTITY.md
?? _config/
?? _log/
```

### The three FAILs are the collision, and they are expected

Apply runs the checker on the result. It found three, and they all name the file it refused to
touch:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --only sections .
```

```
-- sections --
ok   IDENTITY.md has every required section
FAIL CONTEXT.md is missing a required section: ## Routing
FAIL CONTEXT.md is missing a required section: ## Session Start
FAIL CONTEXT.md is missing a required section: ## Rule Books
```

Your `CONTEXT.md` survived, so it is still your notes file rather than a layer 1 routing table.
Read the prepared diff, merge what you want by hand, and the check goes clean:

```sh
cat .icm/proposed/CONTEXT.md.diff
diff -u CONTEXT.md .icm/proposed/CONTEXT.md
```

There is no force flag and no "overwrite all". A collision is a decision and it stays yours.

Next: `/icm-context` for the folders the survey named, then commit.

---

## TRANSFER: pull a messy tree into line

Folders already exist, they already hold real work, and nothing is named, routed or documented.
Ten years of a shared drive, or a repo that grew sideways.

Look first, and only look.

```sh
cd "/home/you/shared-drive"
sh "$ICM_HOME/scripts/icm-plan.sh" .
```

The dispositions are the same ten rows as a fresh project. The part that matters on a messy tree
is the survey: plan walks two levels deep, prunes the excluded globs from `icm.defaults.json`,
and gives every folder of yours one of four verdicts.

```
SURVEY - folders in your tree, and whether they look like they want a job card

| Folder                         | Verdict  | Files | Stage signal | Suggested next step
|--------------------------------|----------|-------|--------------|---------------------
| 01 - research notes/           | staged   |    34 | yes          | /icm-context one "01 - research notes"
| 02 - interviews/               | staged   |     4 | yes          | /icm-context one "02 - interviews"
| 02 - interviews/output/        | none     |     1 | no           | needs classification, ask the user
| assets/                        | none     |    20 | no           | asset-only, nothing to route
| drafts/                        | card     |    12 | no           | /icm-context one drafts
| FINAL FINAL v3/                | card     |     6 | no           | /icm-context one "FINAL FINAL v3"
| misc/                          | card     |     9 | no           | /icm-context one misc

note a verdict is evidence, not a conclusion. a number in a folder name is a
note signal that it might be a stage; it is not proof that it is one.
note nothing above is written by apply. job cards are written one at a time
note with /icm-context, in conversation, and nothing moves by default.

ok   plan written: /home/you/shared-drive/.icm/plan.txt
ok   CREATE 10   COLLIDE 0   ADOPT 0   SKIP 0   REFUSE 0   SURVEY 7
```

Folder names with spaces are handled, which is why the plan file is tab separated.

Three things that table is not. It is not a decision: `staged` means the folder looks like a
pipeline stage, not that it is one. It is not a work queue for `apply`: apply ignores every
`SURVEY` row except to count it, and it never writes a job card into one of your folders. And it
is not a licence to move anything: nothing moves by default, and moving is opt-in per folder,
after the map exists.

Then the order that works:

```sh
# 1. prune the noise first: add _old/, zz-archive/ and friends to
#    excluded_globs in icm.defaults.json, then re-plan. cheapest ten minutes here.
sh "$ICM_HOME/scripts/icm-plan.sh" .

# 2. install the top layers only. zero files moved.
sh "$ICM_HOME/scripts/icm-apply.sh" .
```

```
/icm-context report    # 3. the gap list: which folders warrant a job card and have none
/icm-context create    #    then write them, with you in the room
/icm-sync lint         # 4. later, find what drifted
```

The survey's "suggested next step" column names the folder to start with. The invocation comes
from the skill, whose modes are `report` and `create`.

Start with the folder you touch most, not all of them. If you cannot state what comes out of a
folder, you have found something worth knowing, and that discovery is worth more than the file.

The full walkthrough, including what not to do on a messy tree, is
[`docs/retrofit.md`](docs/retrofit.md).

---

## If you change your mind

Rollback is its own script. There is no `--rollback` flag on apply and there never was.

```sh
sh "$ICM_HOME/scripts/icm-rollback.sh" --list .
sh "$ICM_HOME/scripts/icm-rollback.sh" .
```

```
# icm-rollback runs under /home/you/acme-api/.icm/backup
ok   20260830T055159Z-53330

# icm-rollback
target:   /home/you/acme-api
run:      20260830T055159Z-53330
manifest: /home/you/acme-api/.icm/backup/20260830T055159Z-53330/manifest.txt

ok   removed  IDENTITY.md
ok   dropped  the parked candidate for CONTEXT.md
ok   removed  _config/conventions.md
ok   removed  _config/glossary.md
ok   removed  _config/voice.md
ok   removed  _config/style.md
ok   removed  _log/LOOP-LEDGER.md
ok   removed  _log/FORGE-PROPOSALS.md
ok   restored CLAUDE.md from its pre-image
ok   restored .gitignore from its pre-image
ok   removed  _log/
ok   removed  _config/

ok   undone 10   left alone 0

note git holds the other copy of the truth. compare what is there now with:
note   git -C /home/you/acme-api status --porcelain
result: clean
```

With no `--stamp` it undoes the newest run. `--stamp STAMP` picks one, `--list` shows what is
available, `--force` re-runs one already marked rolled back.

A file you edited after the apply is never deleted. Rollback leaves it in place and tells you
the decision you now own.

---

## Where to go next

- [`README.md`](README.md) - the skills, the archetypes, what lands in your project
- [`docs/retrofit.md`](docs/retrofit.md) - the retrofit flow in full, step by step
- [`docs/methodology.md`](docs/methodology.md) - why the layers are shaped this way
- [`docs/architect.md`](docs/architect.md) - folders as agents, the Pattern 24 shape
- [`examples/`](examples) - a worked source-and-article pair, and an architect company tree
- [`spec/CLI-CONTRACT.md`](spec/CLI-CONTRACT.md) - every command, flag, exit code and artifact
  path. It wins over every other file, including this one.
