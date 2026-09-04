# Retrofit

How to put ICM on a project that already exists, without breaking it.

The whole design rests on one promise, and it is worth stating precisely rather than
comfortably:

> Nothing you wrote is ever deleted or rewritten. Most managed paths are only written when
> nothing exists there. Two of them, `CLAUDE.md` and `.gitignore`, are edited in place, and
> only between `<!-- icm:begin -->` and `<!-- icm:end -->`. Every byte outside those markers is
> unchanged, and the pre-image is copied to `.icm/backup/<stamp>/files/` before the edit.
> Anything else that already exists is a collision: the toolkit's version goes to
> `.icm/proposed/` with a diff beside it, and your file is not touched.

Everything below is the machinery that makes that promise true, plus the escape hatch for when
you change your mind afterwards.

You can drive this from the skill or from the scripts. They do the same work. Resolve the
toolkit root once before the first command, the same way every skill does:

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

| Step | Skill | Script |
|---|---|---|
| Dry run | `/icm-retrofit plan` | `sh "$ICM_HOME/scripts/icm-plan.sh" <path>` |
| Apply | `/icm-retrofit apply` | `sh "$ICM_HOME/scripts/icm-apply.sh" <path>` |
| Undo | `/icm-retrofit rollback` | `sh "$ICM_HOME/scripts/icm-rollback.sh" <path>` |
| Check | `/icm-sync lint` | `sh "$ICM_HOME/scripts/icm-check.sh" <path>` |

Four scripts on this path, and a fifth, `icm-loop.sh`, that belongs to the loop rather than to the retrofit. Rollback is its own script: there is no `--rollback` flag on apply, and there
never was.

---

## Step 1. Dry run

```
/icm-retrofit plan
```

`plan` is the default mode. It writes exactly one file, `<target>/.icm/plan.txt`, and nothing
else in your project is created, modified or deleted under any circumstances.

One honest caveat, because a dry run is not quite invisible: `.icm/` is only added to your
`.gitignore` at apply, so after a first plan `git status` shows `?? .icm/`. Nothing else in
your project changed. Plan says so itself in its closing note.

What it does while it is in there:

1. Classifies every path in the install manifest for the chosen archetype into one of five
   dispositions.
2. Walks your tree two levels deep, pruning the excluded globs, and reports which of your own
   folders look like they want a job card.
3. Prints the diff and the survey, then stops.

The skip globs come from `icm.defaults.json`, keys `excluded_globs` and `never_write`.
[`../spec/excluded-folders.md`](../spec/excluded-folders.md) is the human rendering of those
keys. No script reads that document.

Read the plan before you do anything else. It is the only cheap moment in the process.

---

## Step 2. The five dispositions

Five words. There are no others. Each plan row is one path, one disposition and one reason.

| Word | Means | What apply does |
|---|---|---|
| `CREATE` | Nothing exists at the path | Writes the whole file |
| `ADOPT` | Your file is kept, and a marked icm block belongs in it | Backs up the pre-image, then rewrites only the text between the markers |
| `COLLIDE` | It exists and apply must not write it | Parks its version in `.icm/proposed/` with a `.diff` beside it. Your file is not touched |
| `SKIP` | The path already holds exactly what apply would write, byte for byte | Nothing |
| `REFUSE` | The path matches a `never_write` glob, or resolves outside the target | Nothing at all. No candidate, no proposal, no suggestion of how it could be done |

`SKIP` means **already installed and identical**. It has never meant "excluded folder". An
excluded folder is never a candidate, so it can never appear as a `SKIP` row, or as any row.

### CREATE

```
CREATE - absent, apply would write these
  IDENTITY.md                        layer 0 identity, absent
  CONTEXT.md                         layer 1 routing, absent
  _config/voice.md                   layer 3 rule book, absent
```

The body apply writes is compiled into `scripts/icm_lib.sh`. It does not come from a template
directory, and no script reads one.

### ADOPT

```
ADOPT - your file is kept, apply appends a marked icm block and backs up the original first
  CLAUDE.md                          adapter, icm block will be appended
  .gitignore                         gitignore, icm block will be appended
```

Two paths, and only two. This is the section people misread, so the header says the whole
thing out loud. Your file is not replaced. The edit is confined to the text between
`<!-- icm:begin -->` and `<!-- icm:end -->`, and the pre-image is copied into the backup before
a byte moves.

### COLLIDE

The path exists **and** apply must not write it. This is the section that matters. There are
four ways in:

1. It exists and differs from what apply would write.
2. It is not a regular file: a symlink, a directory, a FIFO, a socket, a device.
3. It is an adopt-role file whose marker block is malformed: a missing end marker, or a
   stray second begin.
4. It is a `_config/*.md` rule book that already exists. Always, even when it looks stale.
   Rule books are the human's pen.

```
COLLIDE - apply parks a candidate and touches nothing
  IDENTITY.md                        exists and differs, candidate parked
  _config/voice.md                   rule book exists, candidate parked
note diff each one with: diff -u <path> .icm/proposed/<path>
note or read the prepared diff at: .icm/proposed/<path>.diff
```

There is no force flag. There is no "overwrite all". A collision is a decision, and decisions
belong to you.

### SKIP and REFUSE

```
SKIP - already installed and identical, apply would do nothing
  CONTEXT.md                         identical, nothing to do

REFUSE - apply will not write these at all
  node_modules/pkg/README.md         never_write glob in icm.defaults.json
```

If a folder you care about never appears anywhere in the plan, the fix is
`icm.defaults.json`'s `excluded_globs`, not a flag on the command.

---

## Step 3. Collision policy

Stated once, so it can be quoted:

> A file the toolkit does not own is never modified. The two adopt roles, `CLAUDE.md` and
> `.gitignore`, are edited only between `<!-- icm:begin -->` and `<!-- icm:end -->`, and the
> pre-image is backed up first. Everything else that already exists is parked in
> `.icm/proposed/` for you.

Three consequences people find surprising, all of them intentional.

**Applying twice changes nothing the second time.** After the first `apply`, every path it
wrote now holds exactly what it would write, so the second run classifies them `SKIP`. The
operation is idempotent by construction rather than by a flag.

**A file you edited after applying stays edited.** Edit a generated `CONTEXT.md` and the next
plan calls it `COLLIDE`, not `SKIP`, and parks its version rather than yours.

**The wiki starts empty.** Retrofit does not import your `docs/` into `wiki/`. An imported
document has no `raw/` source, so it fails the grounding invariant the moment it lands and
every fact in it is unverifiable forever. Existing docs get referenced as Layer 3 instead. If
you genuinely want a document in the wiki, put it in `raw/` first, as its own source, and
compile it from there with `/icm-wiki ingest`. Then the invariant holds, because the document
really is the source.

---

## Step 4. Backup

`apply` takes the backup itself, before it writes anything. You do not have to remember.

```
.icm/backup/<STAMP>/
  manifest.txt        what this run did, one row per path, written as it goes
  COMPLETE            written only after the last row is durable
  files/<relpath>     the pre-image of every file this run modified
```

The backup holds the pre-image of every `MODIFIED` row, plus `manifest.txt`, plus `COMPLETE`.
`CREATED` rows get no pre-image, because there was nothing there. The plan is not copied into
the backup.

`STAMP` is a UTC timestamp plus the process id, so two runs in the same second cannot share a
backup directory.

The manifest's action words are deliberately different from the plan's disposition words. A
plan row says what apply intends: `CREATE`, `ADOPT`, `COLLIDE`, `SKIP`, `REFUSE`. A manifest
row says what apply did: `MKDIR`, `CREATED`, `MODIFIED`, `PARKED`, `SKIPPED`.

`.icm/` is gitignored. If you want the backup to survive a `git clean -xdf`, copy it somewhere
else first.

---

## Step 5. Apply

```
/icm-retrofit apply
```

`apply` refuses to run without a plan on disk. It will not re-derive one for you, because the
whole point is that you read the plan that is about to execute, not a fresh one that might
differ. It refuses on exactly two things: no plan file, and a plan whose `# target:` header
names a different directory. It is not a staleness gate, because you are expected to work
between plan and apply. Instead of guessing, it re-derives every row's live disposition before
writing and warns when disk disagrees with the plan.

What it does:

1. Takes a lock, so a second apply in the same target refuses instead of racing.
2. Reads the plan from `.icm/plan.txt`.
3. Executes the five dispositions, and only those. It never writes a job card into one of your
   folders, and it ignores every `SURVEY` row except to count it.
4. Backs up the pre-image of each `ADOPT` row before it edits, and records every action in
   `manifest.txt` as it goes.
5. Writes each `COLLIDE` row's version to `.icm/proposed/<relpath>`, with the unified diff
   beside it at `.icm/proposed/<relpath>.diff`.
6. Runs the checker on the result and prints its summary, unless you passed `--no-check`. The
   checker's verdict does not change apply's exit status.

Then it tells you what to do next, and the rollback hint comes last rather than first:

```
note read IDENTITY.md, then CONTEXT.md. they are the map.
note folders that do real work still have no job card. run /icm-context to write them.
note review the new files, then commit them: git add -A && git status
note undo this exact run with: scripts/icm-rollback.sh --stamp <STAMP> <TARGET>
```

Expect `git status` to show two modified files and a handful of new ones. That is the whole
change, and you approve it by committing it.

Read the check report. A drift warning on a tree that was generated ninety seconds ago is a
checker bug, not a skip-list problem: nothing you add to the skip list will clear it. Report
it. Everything else the report names is real.

---

## Step 6. Rollback

```
/icm-retrofit rollback
```

The script is `scripts/icm-rollback.sh` and it takes three flags:

| Flag | Meaning |
|---|---|
| `--stamp STAMP` | Roll back this run. `STAMP` is a directory name under `.icm/backup/` |
| `--list` | List the runs available to roll back, then stop |
| `--force` | Roll back a run already marked rolled back |

With no `--stamp` it undoes the newest run. Every recorded path is classified before anything
is removed:

| Class | What rollback does |
|---|---|
| Untouched since the toolkit wrote it | Deletes it |
| Modified by a human since | Leaves it in place and names the decision you now own |
| Modified by the toolkit, pre-image on file | Puts the original back, byte for byte |

**Rollback never deletes a file a human has touched.** If you wrote three good paragraphs into
a generated `IDENTITY.md` and then rolled back, you keep the file and get told it was kept,
along with the choice in front of you: keep it, or delete it by hand and rerun to close the
run.

It removes only directories it made, named by a `MKDIR` row, in reverse order. A `wiki/`,
`raw/` or `output/` that was yours before the install is never pruned.

Exit 0 means fully undone, or nothing to undo. Exit 1 means something was left alone because
you changed it. Exit 2 means it refused before touching anything.

---

## The TRANSFER case: a messy tree

The hardest starting point, and the most common. Folders already exist. They hold years of real
work. Nothing is named consistently, nothing is routed, half of it is duplicated and nobody
remembers which copy is current. A shared drive that grew, or a repo that grew sideways.

The instinct is to reorganise first and add ICM second. Do the opposite. **Reorganising a tree
nobody understands is how work gets lost.** ICM is how you come to understand it.

### What the script does, and what you do

The division of labour is the whole design, and it is worth being blunt about:

- **Plan surveys and proposes.** It walks two levels deep, prunes the excluded globs, skips the
  directories the install manifest owns, and gives every surviving folder one of four
  verdicts.
- **Apply installs and nothing more.** It never writes a job card. There is no renderer for
  `<folder>/CONTEXT.md` and there must not be one, because naming a folder honestly is
  judgment, not classification.
- **You name the work.** `/icm-context` writes each job card, one at a time, with you in the
  room.

The four verdicts:

| Verdict | Condition |
|---|---|
| `has-card` | The folder already holds a `CONTEXT.md` |
| `staged` | Warrants a card, and carries a stage signal: a leading number in the name, or an output-like child |
| `card` | Warrants a card: two or more direct files, no `CONTEXT.md`, not asset-only |
| `none` | Empty, one file, asset-only, or a vendor drop |

The verdict is evidence, never a conclusion. `staged` means the folder *looks like* a pipeline
stage. It does not mean it is one. Numbers in folder names are a signal, not a fact, and a set
of date-ordered folders under one parent is usually runs rather than stages.

The survey prints as a table:

```
SURVEY - folders in your tree, and whether they look like they want a job card

| Folder                         | Verdict  | Files | Stage signal | Suggested next step
|--------------------------------|----------|-------|--------------|---------------------
| 01 - research notes/           | staged   |    34 | yes          | /icm-context one "01 - research notes"
| drafts/                        | card     |    12 | no           | /icm-context one drafts
| misc/                          | none     |    41 | no           | needs classification, ask the user
| assets/                        | none     |   210 | no           | asset-only, nothing to route

note a verdict is evidence, not a conclusion. a number in a folder name is a
note signal that it might be a stage; it is not proof that it is one.
note nothing above is written by apply. job cards are written one at a time
note with /icm-context, in conversation, and nothing moves by default.
```

Three rules govern what you do with that table.

1. **Nothing moves by default.** The default action is a job card in place. The folder keeps
   its name, its path and its history. The tree stops being messy because it becomes legible,
   not because it was rearranged.
2. **Moving is opt-in, per row, and needs its own yes** after the plan is already approved.
   Check the working tree is clean under version control first, and say plainly that moving
   files rewrites paths other things may point at.
3. **Unclear stays unclear.** A folder the survey called `none` that you cannot classify is
   listed as "needs classification". Ask. Never guess it into a stage.

### The order

**1. Look, and only look.**

```
/icm-retrofit plan
```

Read the dispositions as a list of what would be installed, and the survey as a map of your own
tree. Do not apply yet.

**2. Prune the noise before you fix anything else.**

A messy tree almost always has junk the default globs do not know about: an `_old/` folder, a
`zz-archive/`, a `Copy of Copy of/`. Add them to `excluded_globs` in
[`../icm.defaults.json`](../icm.defaults.json) and re-plan. Every later step gets cheaper and
quieter. This is the highest-leverage ten minutes in the whole process.

**3. Apply the top two layers only.**

```
/icm-retrofit apply
```

You now have `IDENTITY.md` and a root `CONTEXT.md`. That is a name tag and a map. An agent
walking in can already find its way around a tree that no human could describe out loud. Zero
files moved.

**4. Add job cards where work actually happens, one at a time.**

```
/icm-context
```

Do not do all of them. Start with the folder you touch most. Write what comes in, what happens,
what goes out. If you cannot state the outputs, you have found something worth knowing about
that folder, and that discovery is worth more than the file.

**5. Now, and only now, move things.**

With a map that says what each folder is for, moving a folder is a small, reversible decision.
Update its row in the routing table and go. Without the map it was a gamble.

**6. Run lint on a schedule.**

```
/icm-sync lint
```

The map goes stale the first week someone adds a folder. Lint catches it. A stale map is worse
than no map, because a model will believe it.

### What not to do on a messy tree

- Do not absorb existing docs into generated files. Link to them. They are Layer 3 material and
  they are already written.
- Do not scaffold stage folders you are not going to use. The structure grows with use, never
  ahead of it.
- Do not import `docs/` into `wiki/`. See Step 3.
- Do not delete the duplicates yet. Route around them, leave them out of the walk, and delete
  once the map has been right for a month.

---

## What retrofit never does

- Never deletes or rewrites anything you wrote. The two adopt paths are edited only inside
  their markers, and only after the pre-image is on disk.
- Never resolves a collision for you.
- Never moves a file.
- Never deletes a file.
- Never writes outside the target project, except into that project's gitignored `.icm/`.
- Never writes a job card into one of your folders. That is `/icm-context`, and it is a
  conversation.
- Never runs without a plan you could have read first.
- Never requires python or node. Everything above is POSIX `sh`.
