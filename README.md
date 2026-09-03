# Momentrix ICM KAP Toolkit

A drop-in context layer for any project. Folders become agents, a short file in each one
says what that folder does, and a set of scripts proves the whole thing still tells the truth.

ICM is the Interpretable Context Methodology: you organise an agent's work the way you
organise a filing cabinet, and the structure itself does the routing. KAP is for Karpathy:
the second half of the toolkit is a `raw/` and `wiki/` pair where the model writes up what it
learned from your sources, and every fact it writes has to exist in a source first.

Nothing here is a framework. It is markdown files, POSIX `sh` scripts, and eight skills that
know how to write and check both.

**In a hurry?** [`QUICKSTART.md`](QUICKSTART.md) is the sixty-second path for all three ways in,
with the real output of every command beside it.

---

## The three ways in

Pick the one that matches what you are standing in front of. Copy-pasteable commands and what
they actually print: [`QUICKSTART.md`](QUICKSTART.md).

### NEW: scaffold from scratch

An empty folder, or a project that has no context files at all.

```
/icm-scaffold
```

The skill interviews you, picks an archetype, and writes Layer 0 (`IDENTITY.md`),
Layer 1 (root `CONTEXT.md`) and Layer 3 (`_config/` rule books). Add numbered stage folders
and the `raw/` + `wiki/` pair only if the interview says you need them.

### OVER: drop it on a live project

A working repo full of files you cannot afford to break.

```
/icm-retrofit plan     # writes nothing outside .icm/
/icm-retrofit apply    # only after you have read the plan
```

`plan` writes exactly one file, `.icm/plan.txt`, and prints the diff. Every row is one path,
one disposition and one reason. There are five disposition words and no others: `CREATE`,
`ADOPT`, `COLLIDE`, `SKIP`, `REFUSE`. Nothing in your project changes until you run `apply`.

Nothing you wrote is ever deleted or rewritten. Most managed paths are only written when
nothing exists there. Two of them, `CLAUDE.md` and `.gitignore`, are edited in place, and only
between `<!-- icm:begin -->` and `<!-- icm:end -->`. Every byte outside those markers is
unchanged, and the pre-image is copied to `.icm/backup/<stamp>/files/` before the edit.
Anything else that already exists is a collision: the toolkit's version goes to
`.icm/proposed/` with a diff beside it, and your file is not touched.

`/icm-retrofit rollback` undoes one apply run. It is a separate script,
`scripts/icm-rollback.sh`, and it takes `--stamp STAMP`, `--list` and `--force`. There is no
`--rollback` flag on `icm-apply.sh` and there never was.

Full walkthrough: [`docs/retrofit.md`](docs/retrofit.md). Command shapes, exit codes, artifact
paths and vocabulary: [`spec/CLI-CONTRACT.md`](spec/CLI-CONTRACT.md), which wins over this
file wherever the two differ.

### TRANSFER: pull a messy tree into line

Folders already exist, they already hold real work, and nothing is named, routed or documented.
Ten years of a shared drive, or a repo that grew sideways.

```
/icm-retrofit plan     # see the shape of what is already there
/icm-context           # write a job card into folders that have none
/icm-sync lint         # find what drifted, then fix it
```

`plan` walks your tree two levels deep, prunes the excluded globs, and reports each surviving
folder with one of four verdicts: `has-card`, `staged`, `card`, `none`. That is evidence, not
a conclusion. The script says what it found. You say what it means, and `/icm-context` writes
the job card one folder at a time, with you in the room. `apply` never writes a job card into
one of your folders.

The tree does not move. You add a name tag at the top, a map beside it, and one job card per
folder that does real work. Every folder that is not doing work gets left alone.

---

## Install

### Plugin marketplace (do this one)

```
/plugin marketplace add MOMENTRIXMARKETING/momentrix-icm-kap-toolkit
/plugin install momentrix-icm-kap-toolkit@momentrix-icm-kap-toolkit
```

The repo is its own single-plugin marketplace, so the first command reads
`.claude-plugin/marketplace.json` straight off the GitHub URL. `marketplace.json` sets
`"source": "./"`, so the whole repo lands and the plugin root is the repo root. All eight
skills arrive together and update with `/plugin update`. Nothing else to do: the skills find
the scripts through `CLAUDE_PLUGIN_ROOT`, which the harness sets for you.

### Manual copy (fallback)

For Cursor, Codex CLI, or anyone not on Claude Code. Clone the **whole repo** and copy only
the skills out of it. The scripts stay in the clone.

```sh
git clone https://github.com/MOMENTRIXMARKETING/momentrix-icm-kap-toolkit.git ~/src/momentrix-icm-kap-toolkit

mkdir -p ~/.claude/skills
for s in ~/src/momentrix-icm-kap-toolkit/skills/icm-*; do
  n=$(basename "$s")
  mkdir -p ~/.claude/skills/"$n"
  cp -R "$s"/. ~/.claude/skills/"$n"/
done
```

If you cloned anywhere other than `~/src/momentrix-icm-kap-toolkit`, add one line to your
shell profile so every skill and every command finds the toolkit:

```sh
export ICM_HOME="$HOME/wherever/you/put/momentrix-icm-kap-toolkit"
```

Two details that are not decoration:

- **`mkdir -p` is required.** On a machine that has never run Claude Code, `~/.claude/skills/`
  does not exist yet and a bare `cp -r` fails with "No such file or directory". This is the
  exact failure in icm-template's published install command.
- **`cp -R "$s"/. dest/` is required, not `cp -R "$s" dest/`.** If the destination directory
  already exists, the second form copies the folder *inside* it and you end up with
  `~/.claude/skills/icm-sync/icm-sync/` holding a stale duplicate that shadows nothing and
  confuses everything. The `/.` form merges contents instead.

Swap `~/.claude/skills` for `~/.agents/skills` if that is where your tool reads from. The loop
above works in any POSIX shell.

### Where the scripts live after each install

`scripts/` is never copied anywhere. It stays at `<toolkit-root>/scripts/`, and no skill
directory holds a copy of it. Do not copy `scripts/`, `spec/`, `interview-templates/` or
`icm.defaults.json` next to the skills: that makes one drifting copy per skill and breaks the
scripts' own root resolution.

| Install method | The toolkit root is | How a command finds it |
|---|---|---|
| Plugin marketplace | The plugin root, which is the whole repo | `CLAUDE_PLUGIN_ROOT`, set by the harness |
| Manual copy | Your clone directory | `ICM_HOME`, defaulting to `~/src/momentrix-icm-kap-toolkit` |

Every skill resolves the root once, before its first command, with this block. It is identical
in all eight, byte for byte, so you can paste it into your own shell too.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

An operator override wins, then the plugin root, then the documented clone path. After it,
every invocation is absolute and every path is quoted, because your working directory is your
own project, not the toolkit:

```sh
sh "$ICM_HOME/scripts/icm-plan.sh" .
```

There is no `bin/icm`, no PATH install and no wrapper. One resolution mechanism, not two.

---

## The skills

| Skill | Reach for it when | Modes |
|---|---|---|
| `icm-scaffold` | You are starting fresh and want the layers written for you | `quick` (default), `full`, `wiki` |
| `icm-retrofit` | The project already exists and you want to see the diff first | `plan` (default), `apply`, `rollback` |
| `icm-context` | A folder does real work and has no job card | `report` (default), `create` |
| `icm-stage` | You want another numbered stage in the pipeline | `<stage-name>`, `<stage-name> after:NN` |
| `icm-sync` | The folder map has gone stale, or routing points at nothing | `lint` (default), `update` |
| `icm-wiki` | You have sources to turn into knowledge the model can reuse | `ingest <url\|path>`, `query <question>`, `lint` |
| `icm-log` | Something missed and you want it on the record in ten seconds | `miss`, `close`, `show` |
| `icm-forge` | It is review day and you want the misses turned into proposals | `run`, `show`, `approve <id>` |

Run a skill with no argument to get its default mode, which is always the one that reports
before it writes. Each skill's own `argument-hint` is the authority on its modes, and the
frontmatter contract every skill meets is in
[`docs/skill-authoring.md`](docs/skill-authoring.md).

### The archetypes

An archetype is how much of the layer set gets installed. `icm-scaffold` picks one in the
interview; `icm-plan.sh --archetype ID` picks one on the retrofit path.

| Archetype | You get | Reach for it when |
|---|---|---|
| `quick` | Layers 0, 1 and 3, plus `_log/`. Default. | Most projects, and every project that will never compile knowledge |
| `full` | `quick` plus `output/` | The work produces artifacts a human reads |
| `wiki` | `full` plus `raw/`, `wiki/` and `_config/grounding.md` | You have sources to turn into knowledge |
| `architect` | A `full` install at the root, plus one department folder per team, each with its own `CONTEXT.md`, `_config/` and stages | A whole organisation in one tree, worked by agents that are spawned into a folder and die there |

`architect` is a workspace **shape**, not a fourth install manifest.
`icm-plan.sh --archetype` takes `quick`, `full` and `wiki` only. You build the architect shape
on top of a `full` install, one department at a time, with `/icm-context` and `/icm-stage add`.
It is Pattern 24 in [`spec/CONVENTIONS.md`](spec/CONVENTIONS.md).
[`docs/architect.md`](docs/architect.md) says why it works and where the obvious version of it
goes wrong, and [`examples/architect-company/`](examples/architect-company) is a worked tree.

Two of these are the loop that keeps the rest honest. `icm-log` writes to
`_log/LOOP-LEDGER.md` and never judges. `icm-forge` reads that ledger, finds where the same
rule book failed twice, and writes proposals to `_log/FORGE-PROPOSALS.md`. It never edits a
rule book. You hold the only pen that touches those.

### The weekly forge cron

The forge is the one skill worth putting on a schedule, because its input accumulates whether
anyone is watching or not. Set it up once, in the workspace you want reviewed, with Claude
Code's `/schedule`:

- **Cadence: weekly.** The threshold for a hole is two misses on the same rule book, and two
  misses take about a week to arrive. A daily run mostly reports nothing, and a report that is
  usually empty trains you to skip it.
- **The routine's prompt is exactly `/icm-forge run`.** Nothing else. No extra instructions, no
  "and fix what you find".

What the run does: reads `_log/LOOP-LEDGER.md`, counts the misses per rule book, names the holes
that cleared the threshold, and appends one proposal block per hole to
`_log/FORGE-PROPOSALS.md`, each quoting the ledger lines that justify it. It also appends the
weekly review block to the ledger. That is the whole of it.

**The cron only runs the forge. Approval always stays with the human.** A scheduled run cannot
approve anything, because approval is defined as a human in the turn naming a proposal by its
id, and there is no human in a scheduled turn. So a run that finds five holes writes five
proposals and stops. Proposals from an unattended run are written
`Status: proposed (unattended run)`, so nobody later reads silence as consent, and the "was the
call necessary" column is left blank rather than guessed.

The output is a queue, not a decision. You read it when you sit down, with `/icm-forge show`,
and act on it with `/icm-forge approve <id>`, which is the only mode in which a rule book
changes. The schedule changes when the forge looks. It changes nothing about who decides.

Full behaviour, including the ladder of smallest edits and every refusal:
[`skills/icm-forge/SKILL.md`](skills/icm-forge/SKILL.md).

---

## What lands in your project

Exactly this, and nothing else. `apply` installs a fixed set of paths and never invents one
from your tree.

```
your project
  IDENTITY.md               layer 0, where am I                      every archetype
  CONTEXT.md                layer 1, where do I go                   every archetype
  _config/conventions.md    layer 3, naming and folder shapes        every archetype
  _config/glossary.md       layer 3, your terms, one meaning each    every archetype
  _config/voice.md          layer 3, audience, tone, evidence bar    every archetype
  _config/style.md          layer 3, headings, tables, dates         every archetype
  _log/LOOP-LEDGER.md       the append-only ledger                   every archetype
  _log/FORGE-PROPOSALS.md   what the forge proposes                  every archetype
  CLAUDE.md                 adapter, a marked block appended         every archetype
  .gitignore                a marked block appended, adds .icm/      every archetype
  output/CONTEXT.md         layer 4b, what we shipped                full and wiki
  raw/CONTEXT.md            layer 4a, sources, immutable             wiki only
  wiki/index.md             layer 4b, the contents page              wiki only
  wiki/log.md               layer 4b, append-only, what changed      wiki only
  _config/grounding.md      layer 3, the grounding invariant applied wiki only
  .icm/                     plans, backups, proposed collisions      written by the tool
```

Numbered stage folders are **not** part of any install. You get one only when you ask for it,
with `/icm-stage add`. Job cards for folders you already have are written by `/icm-context`.

`CLAUDE.md` and `.gitignore` are the two paths that are edited rather than created. Everything
else on the list is written only where nothing exists.

Layers 1, 2 and 3 recurse. A company holds departments, and each department repeats the same
pattern inside itself. See [`spec/layers.md`](spec/layers.md).

Three homes, and they are not interchangeable.

| Home | Holds | Same in every project? |
|---|---|---|
| Toolkit skills | the eight `icm-*` skills in this repo's `skills/` | yes. The install toolkit. |
| `_config/` | **rule books**, not skills | no. They are yours. |
| Customer skills | `customers/<name>/SKILL.md` in that customer's workspace | no. One folder per customer. |

The eight toolkit skills stay the same eight in every project. A customer-specific `SKILL.md`
does not join them. It lives in that customer's folder, or in that company's own tree the way
[`examples/architect-company/`](examples/architect-company) is a company tree. It is never
copied into `skills/`, never into `~/.claude/skills`, never into the agent, and never installed
as a Grok Bot global skill. `_config/` is not a skills library. Rule books differ per project,
and nothing but you edits them.

The blank, including the job card that routes to it:
[`examples/customers/_TEMPLATE/`](examples/customers/_TEMPLATE). Pattern 25 in
[`spec/CONVENTIONS.md`](spec/CONVENTIONS.md).

---

## Zero dependencies

Every script in `scripts/` is POSIX `sh`. No bashisms, so it runs the same under `dash`, `ash`
and `busybox sh` as it does under `bash` and `zsh`. The tools come in three tiers, and the
difference between them matters.

**1. Always required, all POSIX.** `sh`, `grep`, `sed`, `awk`, `wc`, `find`, `sort`, `diff`,
`cat`, `head`, `tail`, `mkdir`, `cp`, `mv`, `rm`, `printf`, `date`, `basename`, `dirname`,
`tr`, `rmdir`, `cmp`, `ls`. Two are soft: `cmp` falls back to `diff -q`, and `ls` is reached
only in the degraded hash path below.

**2. Hashing, first one found.** `shasum`, else `sha256sum`, else a size-plus-mtime
fingerprint. Neither hasher is POSIX. macOS ships `shasum`, coreutils Linux ships
`sha256sum`, and busybox and Alpine ship `sha256sum` as a standard applet, so the fallback is
an edge case rather than the normal path. When it does fire, the scripts say so out loud and
stamp the mode into the manifest. What it costs: **rollback's tamper detection**, which
compares recorded against current hashes before it removes or restores anything, and a
same-size edit inside the same minute can collide. It costs apply's never-overwrite promise
nothing, because that decision is a byte compare, not a hash.

**3. Optional, both guarded, neither ever blocking.** `git`, used only for `icm-plan.sh`'s
dirty-repo refusal, and a machine with no git simply skips it. And `python3` 3.10 or
newer for the one deep check below.

**No python is required. No node is required. There is no install step and no lockfile.**

```sh
sh "$ICM_HOME/scripts/icm-check.sh" .      # lints a workspace, reports only, writes nothing
sh "$ICM_HOME/scripts/icm-plan.sh" .       # dry run, writes .icm/plan.txt and nothing else
sh "$ICM_HOME/scripts/icm-apply.sh" .      # executes that plan and nothing else
sh "$ICM_HOME/scripts/icm-rollback.sh" .   # undoes one apply run
```

Four scripts. There are no others. `scripts/icm_lib.sh` is dot-sourced, never executed, and
`scripts/check_evidence.py` is only ever invoked by `icm-check.sh`. All four take the target
directory as a positional argument, defaulting to `.`, and all four answer `--help`.

One exit code scheme, all four scripts.

| Code | Meaning |
|---|---|
| 0 | Clean. Nothing is waiting on you. |
| 1 | Finished, and a human decision is waiting. Collisions parked, or rollback kept a file you edited. |
| 2 | Refused before anything was written. Usage error, bad target, missing plan, dirty repo. |
| 3 | Aborted part way through. The target may be half changed. `icm-apply.sh` only. |

One optional extra. `scripts/check_evidence.py` is the deep grounding check: it greps every
load-bearing literal in a `wiki/` article against the `raw/` files that article links to. It
needs `python3` 3.10 or newer. If `python3` is missing, `scripts/icm-check.sh` skips it, says
so, and still passes on everything else. Nothing in the toolkit depends on it being there.

---

## Where the numbers live

Every budget, every skip glob and every required-section list lives in
[`icm.defaults.json`](icm.defaults.json). Prose never restates them.

- Budgets in human form: [`spec/budgets.md`](spec/budgets.md)
- The one skip list, in human form: [`spec/excluded-folders.md`](spec/excluded-folders.md).
  The scripts read the `excluded_globs` and `never_write` keys out of the JSON, never this file.
- The layer table: [`spec/layers.md`](spec/layers.md)
- Command names, flags, exit codes, artifact paths and vocabulary:
  [`spec/CLI-CONTRACT.md`](spec/CLI-CONTRACT.md)
- The methodology, patterns 1 to 25: [`spec/CONVENTIONS.md`](spec/CONVENTIONS.md)
- The grounding invariant: [`spec/grounding-invariant.md`](spec/grounding-invariant.md)
- Placeholder onboarding: [`spec/placeholder-syntax.md`](spec/placeholder-syntax.md)

If a number appears in two files and both look authoritative, one of them is a bug.

---

## Docs

- [`QUICKSTART.md`](QUICKSTART.md) - the sixty-second path for NEW, OVER and TRANSFER, with the real output of every command
- [`BUILD-CONTRACT.md`](BUILD-CONTRACT.md) - the non-negotiables, read before writing any file here
- [`docs/methodology.md`](docs/methodology.md) - why the five layers, why the recursion, why the split
- [`docs/architect.md`](docs/architect.md) - folders as agents, why the shape survives a model swap
- [`docs/skill-authoring.md`](docs/skill-authoring.md) - the SKILL.md contract, read before you write one
- [`docs/retrofit.md`](docs/retrofit.md) - the retrofit flow, step by step
- [`docs/deck-boards.md`](docs/deck-boards.md) - the print deck copy
- [`docs/paper/Interpretable-Context-Methodology.pdf`](docs/paper/Interpretable-Context-Methodology.pdf) - the paper
- [`examples/`](examples) - worked examples you can read end to end:
  - [`examples/raw/`](examples/raw) and [`examples/wiki/`](examples/wiki) - a source capture and the article compiled from it, the grounding invariant end to end
  - [`examples/architect-company/`](examples/architect-company) - the Pattern 24 company tree, with the file bodies an agent reads when it walks in
  - [`examples/content-pipeline/`](examples/content-pipeline) - a numbered stage pipeline, job card by job card
  - [`examples/customers/_TEMPLATE/`](examples/customers/_TEMPLATE) - Pattern 25: where a customer `SKILL.md` lives, not a workspace root

---

## The toolkit runs on itself

This repo carries its own Layer 0 and Layer 1: [`IDENTITY.md`](IDENTITY.md),
[`CONTEXT.md`](CONTEXT.md), and a two-line [`CLAUDE.md`](CLAUDE.md) that aliases IDENTITY.md
rather than copying it. It has no `raw/`, no `wiki/` and no numbered stages, because it
produces a toolkit and not compiled knowledge; the checker reports those as absent instead of
failing on them.

```sh
cd ~/src/momentrix-icm-kap-toolkit     # you are standing in the toolkit itself
ICM_HOME=$(pwd)
sh tests/run-tests.sh                  # the POSIX harness
sh "$ICM_HOME/scripts/icm-check.sh" .  # the checker, on this repo
python3 tests/test_check_evidence.py   # optional, stdlib unittest, no pytest
```

Both of the first two must be green before anything ships. Test fixtures deliberately live
under a path containing a space, so an unquoted variable fails a test here rather than in
someone else's repo.

---

## Attribution

This toolkit merges three MIT-licensed upstream projects. It did not invent the methodology it
implements.

- The five-layer model, the stage contract, the fifteen conventions and the `{{PLACEHOLDER}}`
  onboarding system are **Jake Van Clief and David McDermott's** Model Workspace Protocol.
- The `raw/` and `wiki/` architecture, the grounding invariant, the three-tier lint authority
  model and the evidence verifier come from **Yuhan Lei's** karpathy-llm-wiki. The underlying
  idea is **Andrej Karpathy's**.
- The conversational scaffolder, the setup interview and the sync loops originate in
  **Kevin Nguyen's** icm-template.

Full licence texts, per-file provenance, and what was vendored versus derived:
[`NOTICE.md`](NOTICE.md).

This repo is MIT. See [`LICENSE`](LICENSE).
