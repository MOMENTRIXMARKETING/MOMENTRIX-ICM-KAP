# Skill authoring

The contract every `skills/<name>/SKILL.md` in this repo has to meet. Read it before you write
one, and before you edit one.

This document exists because of a specific failure. Upstream, icm-template's flagship skill
shipped with no YAML frontmatter at all. Line 1 was a markdown heading. The loader therefore
never registered it, fifteen documented references to it pointed at nothing, and two other
skills hard-stopped with "run that one first". The package was non-functional as published, and
the reason nobody caught it is that there was no document saying what a SKILL.md must contain.
This is that document.

---

## The frontmatter

Every SKILL.md starts on line 1 with `---`. Not a heading, not a comment, not a blank line.

```
---
name: <MUST equal the directory name>
description: "This skill should be used when the user asks to '<trigger>', '<trigger>', or '<trigger>'. <What it does, in one or two sentences.>"
user-invocable: true
argument-hint: "<mode> (default) | <mode> | <mode>"
---
```

Required keys and banned keys are declared in
[`../icm.defaults.json`](../icm.defaults.json) under `frontmatter`. That file is the authority.
The checker reads it, this document only explains it.

### `name`

**It must equal the directory name, exactly, including case.**

`skills/icm-retrofit/SKILL.md` has `name: icm-retrofit`. Not `ICM Retrofit`, not
`icm_retrofit`, not `retrofit`. The checker compares the value against `basename` of the parent
directory and fails on any difference.

Two related traps.

Directory names are lowercase. Plugin skill discovery is case-sensitive on Linux and forgiving
on macOS, so an uppercase folder passes locally and disappears in CI. Create the folder
lowercase from the start. Renaming case-only on APFS fails outright (`git mv SKILLS skills`
returns `fatal: renaming 'SKILLS' failed: Invalid argument`); the two-step
`git mv SKILLS skills-tmp && git mv skills-tmp skills` is the workaround, and not needing it is
better.

Never rename a directory without changing `name` in the same commit. A renamed folder with a
stale `name` is the exact defect described at the top of this page.

### `description`

Third person, and it names the triggers in quotes.

The description is not documentation. It is the only thing a model sees when deciding whether
to load this skill, so it has to read as a routing rule. The shape:

> This skill should be used when the user asks to '<trigger>', '<trigger>', or '<trigger>'.
> <What it does.>

Good:

```
description: "This skill should be used when the user asks to 'add ICM to an existing project', 'retrofit this repo', 'do this without breaking anything', or 'show me what would change first'. Runs a dry-run plan over a live project, reports every collision, takes a backup, and applies only additive changes."
```

Bad, and all four of these ship in the wild:

| Written as | Why it fails |
|---|---|
| `Syncs the workspace.` | A mechanism summary. Nothing in it matches anything a user would say. |
| `Use me to sync ICM.` | First and second person. The model is not being addressed, it is being routed. |
| `This skill syncs IDENTITY.md, CONTEXT.md, routing tables, adapters, budgets and the folder map after any structural change to the workspace tree.` | Accurate and useless. Long on mechanism, zero quoted triggers. |
| `This skill should be used for syncing.` | No quoted triggers, so it competes with every other skill on vibes. |

Write the triggers by asking what the user actually types. They will type "the folder map is
stale", not "reconcile the Layer 0 workspace map against disk". Put their words in the quotes
and yours in the sentence after.

### `user-invocable`

**Hyphenated. `user_invocable` with an underscore is banned and the checker fails on it.**

The underscore form is not a real key. It is silently ignored by the loader, which means a
skill carrying it looks configured and is not. It is listed in
[`../icm.defaults.json`](../icm.defaults.json) under `frontmatter.banned_keys` for that reason.

Set it to `true` for any skill a person is meant to invoke by name. Every skill in this repo is
user-invocable.

### `argument-hint`

The modes, written the way the user will type them, with the default marked.

```
argument-hint: "plan (default, writes nothing) | apply | rollback"
```

If the skill takes no argument, leave the key out rather than writing an empty string.

### Keys you must not add

`user_invocable` and `allowed_tools` are both in `frontmatter.banned_keys`. The checker fails
on either.

Do not reach for the correctly-spelled `allowed-tools` as a fix. It is a permission **grant**,
not a restriction. Adding `allowed-tools: Bash` to a file-writing skill pre-approves arbitrary
shell for it. A skill in this repo earns its permissions at the moment it asks, like everything
else.

---

## The body

After the closing `---`, one `# Title` and then the work.

Keep it operational. A skill is a procedure the model executes, not an essay it reads. The
reasoning belongs in [`methodology.md`](methodology.md); the rules belong in
[`../spec/`](../spec/); the skill says what to do, in order, with the exact paths.

Structure that works:

1. One paragraph saying what this skill does and when it stops.
2. The modes, one section each, in the order of `argument-hint`.
3. The steps, numbered, each one an action with a named path.
4. What it writes, and what it will never write.
5. What it reports back.

Reference, never duplicate. If the skill needs a budget, it points at
[`../spec/budgets.md`](../spec/budgets.md). If it walks a tree, it points at
[`../spec/excluded-folders.md`](../spec/excluded-folders.md) for the skip list. A skill that
restates either one has created a second authority that will drift, and drift silently, because
nothing compares them.

---

## The rule that matters most

**A skill may never assert a fact a script could have checked.**

If the answer is derivable from bytes on disk, the skill runs the script and reports what came
back. It does not look at the tree and conclude. It does not remember from earlier in the
session. It does not say "the workspace is within budget" because it wrote the files itself and
they seemed short.

Script work, always:

- byte and line counts against ceilings
- required sections present or missing
- `name` versus directory name
- frontmatter present, keys valid
- links that resolve, index rows that match disk
- whether a file already exists

Model work, legitimately:

- whether a rule book is missing a rule
- whether a routing row sends a real task to the right folder
- whether an article's summary is a fair summary
- whether two rule books contradict each other

The line is not about difficulty. It is about who can be wrong without noticing. A model that
asserts a byte count is guessing with a confident tone, and the guess is indistinguishable from
a measurement in the transcript. Run `sh "$ICM_HOME/scripts/icm-check.sh" <path>` and paste
what it said.

This is the same three-tier authority model the linter and the forge use, applied to skills:
safe fixes are applied, mechanical findings are reported, judgements are proposed. See
[`methodology.md`](methodology.md).

---

## Finding the scripts

A skill runs with the **user's project** as its working directory, never the toolkit. A bare relative
invocation of `icm-plan.sh` therefore exits 127, and a read of `spec/budgets.md` opens nothing.

Every `SKILL.md` that invokes a script or reads a `spec/` file opens its first command block
with this preamble, byte for byte identical across every skill so a test can assert it:

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

After it, every invocation is absolute and every path is quoted:
`sh "$ICM_HOME/scripts/icm-plan.sh" .`, `$ICM_HOME/spec/layers.md`,
`$ICM_HOME/icm.defaults.json`. A bare `spec/budgets.md` in a read table is a defect.

`scripts/` is never copied next to a skill. One copy, in the toolkit root, resolved at run
time. See [`../spec/CLI-CONTRACT.md`](../spec/CLI-CONTRACT.md) section 2.

---

## Vocabulary

The checker does not enforce these. Reviewers do, and getting them wrong makes the docs
unreadable.

| Say | Not | Why |
|---|---|---|
| rule book | skill | `_config/` holds rule books. "Skill" means `skills/<name>/SKILL.md` and nothing else. |
| rule books | skills library | Collides head-on with Claude Code skills. Never write it. |
| job card | stage context, stage file | A stage or folder `CONTEXT.md` is a job card. |
| `output/` | `output.md` | A stage writes a folder of results, not one file. |

Folder names are lowercase in prose. `_config/`, `raw/`, `wiki/`, `01_research`.

---

## Two hard limits on behaviour

**Never overwrite a user file.** Nothing a user wrote is ever deleted or rewritten. Two managed
paths, `CLAUDE.md` and `.gitignore`, are edited in place and only between `<!-- icm:begin -->`
and `<!-- icm:end -->`, with the pre-image backed up first. Everything else that already exists
is a collision: the toolkit's version is written to `.icm/proposed/` with a diff beside it and
reported, and the user merges it. There is no `--force`. This holds even when the existing file
is obviously worse than the one you would have written.

**Stay inside the budget.** Every file a skill generates has a target and a ceiling, both in
[`../spec/budgets.md`](../spec/budgets.md). Generate to the target. If the content will not fit
under the ceiling, split it and add a pointer rather than shipping something over.

---

## Before you ship a skill

Run this, and read all of it:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" .
```

Then check by eye what the script cannot:

- [ ] Line 1 is `---`.
- [ ] `name` matches the directory name character for character.
- [ ] `description` is third person and quotes at least three real triggers.
- [ ] `user-invocable` is hyphenated.
- [ ] No `user_invocable`, no `allowed_tools`, no `allowed-tools`.
- [ ] `argument-hint` lists the modes and marks the default.
- [ ] Every mode in `argument-hint` has a section in the body.
- [ ] No budget number is written in the file; it points at `spec/budgets.md`.
- [ ] No skip list is written in the file; it points at `spec/excluded-folders.md`.
- [ ] Nothing in `_config/` is called a skill.
- [ ] Every claim the skill makes about disk comes from a script it ran.
- [ ] The skill cannot overwrite anything.
