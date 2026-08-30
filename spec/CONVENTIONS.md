# ICM Conventions

> **Ported from the Model Workspace Protocol.** This file is a port of `_core/CONVENTIONS.md`
> by Jake Van Clief and David McDermott.
> Upstream: https://github.com/RinDig/Model-Workspace-Protocol-MWP-
>
> The layer model, the stage contract, and patterns 1 through 15 are theirs. This toolkit
> implements and extends that methodology. It did not invent it. Full licence text and the
> other two upstreams are in `NOTICE.md`.
>
> What this port changes: layer 0 is renamed `IDENTITY.md` and made model agnostic, layer 4
> splits into 4a and 4b, `_config/` holds rule books, layers 1 to 3 recurse, and three new
> pattern groups are added for grounding, authority, and logging.

This is the methodology spec. It is the canonical text. Everything else in this repo
implements it.

Companion specs, each authoritative for its own subject:

| File | Authoritative for |
|---|---|
| `spec/layers.md` | The layer definitions and the recursion |
| `spec/budgets.md` | Every size budget, sourced from `icm.defaults.json` |
| `spec/excluded-folders.md` | The one skip list |
| `spec/grounding-invariant.md` | Evidence, source fidelity, and the verifier |
| `spec/placeholder-syntax.md` | The `{{PLACEHOLDER}}` onboarding contract |
| `spec/authority-model.md` | Who may fix, who may only report, who holds the pen |

---

## The Layer Stack

Agents read down the layers. They stop as soon as they have what they need.

```
Layer 0   IDENTITY.md              "Where am I?"           always loaded
Layer 1   CONTEXT.md (root)        "Where do I go?"        read on entry
Layer 2   CONTEXT.md (job card)    "What do I do?"         read per task
Layer 3   _config/ rule books      "What rules apply?"     named by the job card
Layer 4a  raw/                     "What is true?"         immutable, cited not loaded whole
Layer 4b  wiki/ and output/        "What do we know?
                                    What did we make?"     compiled and per run
```

`spec/layers.md` holds the full definitions, the recursion rules, and a worked read order.
Sizes are in `spec/budgets.md`. This section is a map, not the source.

Three things about the stack are worth stating here because every pattern below depends on
them.

**Layer 2 is the control point.** The job card's Inputs table decides exactly which layer 3
and layer 4 files get loaded. Nothing else decides. An agent does not browse for context. It
loads what the job card names, by path, and nothing else.

**Layer 3 and layer 4 are different kinds of context.** Layer 3 is the factory: rule books
that get internalised as constraints. Write like this. Never say that. These files are
configured once and stay stable across every run. Layer 4 is the product: sources to reason
from and artifacts to produce. Layer 3 is read as law. Layer 4 is read as material.

**Layer 4 splits because immutability matters.** Layer 4a is `raw/`, which nothing ever
rewrites. Layer 4b is `wiki/` and `output/`, which agents own. The split is what makes the
grounding invariant checkable at all. See `spec/grounding-invariant.md`.

Every char of irrelevant context is a char of diluted attention. Loading more context does
not make output better. It makes it worse.

---

## Pattern 1: Stage Contracts

Every job card follows the same shape. A job card is a `CONTEXT.md` inside a stage folder.
It is called a job card, never a skill and never a prompt.

```markdown
# [Stage Name]

## Purpose

[One sentence. What this stage does and what it hands on.]

## Inputs

| Source | File/Location | Section/Scope | Why |
|--------|--------------|---------------|-----|
| ... | ... | ... | ... |

## Process

1. Step one
2. Step two
3. Step three

## Outputs

| Artifact | Location | Format |
|----------|----------|--------|
| ... | ... | ... |

## Routing

| When | Go to |
|------|-------|
| ... | ... |
```

Those five headings are required. `icm.defaults.json` lists them under
`required_sections."CONTEXT.stage.md"` and the checker fails a job card that is missing one.

`Checkpoints` and `Audit` are optional and are covered by patterns 11 and 12.

This is the contract. It is simple enough that a non technical person can read it and see
what is happening. It is structured enough that an agent can follow it the same way twice.
Every stage follows this exact shape. No exceptions.

The root `CONTEXT.md` has its own required shape: `## Routing`, `## Session Start`,
`## Rule Books`. `IDENTITY.md` requires `## Workspace Map` and `## Rules`. Same source, same
file, same checker.

---

## Pattern 2: Stage Handoffs via Output Folders

Every stage has an `output/` folder. The stage writes its artifact there. The next stage
reads from the previous stage's `output/` folder.

The convention:

- Stage N produces `stages/0N-name/output/artifact-name.md`
- Stage N+1's job card says: read `../0N-name/output/artifact-name.md` as your input

That is the whole handoff. No state manager. No orchestration layer. Files in predictable
places.

A human can open the output file, edit it, save it, and the next stage picks up the edited
version. Every output is an edit surface.

File naming in output folders: `[topic-slug]-[stage-artifact].md`, for example
`acme-outreach-draft.md`, `acme-outreach-spec.md`.

`output/` is layer 4b. It is per run and disposable. It is not a source of truth and it is
not a template. See pattern 14.

---

## Pattern 3: One Way Cross References

Every folder points outward to what it needs. No folder points back.

If stage 03 references stage 02's component registry, stage 02 does not reference anything
in stage 03. If two departments both read the company voice rule book, the company voice
rule book references neither department.

Before you add a reference, check: does the target already reference my folder? If yes,
restructure. Reference cycles turn a readable tree into a graph, and a graph has no read
order, which means no budget.

The direction is always the same: down the layers and up the tree. A job card may reference
its department's rule books and the company's rule books. A company rule book may never
reference a department.

---

## Pattern 4: Selective Section Routing

Inputs tables do not say "read voice.md". They say which part of voice.md.

```markdown
| Source | File/Location | Section/Scope | Why |
|--------|--------------|---------------|-----|
| Rule book | `../../_config/voice.md` | "Banned words" through "Proof rules" | What we may not say |
| Rule book | `../../_config/objections.md` | "Price" and "Timing" only | The two this stage hits |
| Prior stage | `../01-qualify/output/lead-brief.md` | Full file | Who we are writing to |
```

When the whole file is needed, write `Full file` in the Section/Scope column. Do it because
the whole file is needed, not because naming the section was extra work.

This is the cheapest quality control in the system. A rule book of 2000 chars might hold 400
chars that matter to this stage. The other 1600 are rationale that dilutes the load.

The layer 3 budget is two rule books at target size. When a job card needs a third, the fix
is to name sections, not to raise the budget. See `spec/budgets.md`.

---

## Pattern 5: Canonical Sources

Every piece of information has one home. Other files point at it. They do not copy it.

If you need to change a rule, you change it in one place. Every other file holds a pointer.
If the same statement appears in two files and both are meant to be authoritative, one of
them must become a pointer.

Smell test: search the repo for a distinctive phrase. More than one hit means one of them is
a copy waiting to go stale.

This pattern is why the `BUILD-CONTRACT.md` says numbers come from `icm.defaults.json` and
the skip list comes from `spec/excluded-folders.md`. Restating a budget in prose creates a
second home for it, and the second home is always the one that drifts.

---

## Pattern 6: CONTEXT.md Is Routing, Not Content

A `CONTEXT.md` answers three questions:

1. What is this folder?
2. What do I load?
3. What is the process?

It never holds the reference material itself. No definitions. No rules. No extended
examples. No voice guidance. That keeps it small and stops it going stale when the thing it
would otherwise duplicate changes.

If you find yourself writing more than a sentence of description in a `CONTEXT.md`, that
content belongs in a rule book that the `CONTEXT.md` points to.

The size ceiling enforces this. A job card has a line ceiling as well as a char ceiling, and
both are in `spec/budgets.md`. A job card that will not fit is usually a job card that grew
content.

---

## Pattern 7: No Required Tooling

Every script in this toolkit is POSIX `sh` and uses only tools that ship with a Unix system:
`sh, grep, sed, awk, wc, find, sort, diff, cat, head, tail, mkdir, cp, mv, rm, printf, date`.

No bashisms. No `[[ ]]`, no arrays, no `local`, no `${x^^}`, no process substitution. Test
every script with `sh -n` before it ships.

Nothing in this toolkit requires python or node. `scripts/check_evidence.py` is an optional
deep check and every path through the system works without it. What that means in practice
is in `spec/grounding-invariant.md`.

A workspace built with this toolkit may of course need real tools for its own work, a
renderer, a compiler, a converter. Setup guidance for those lives in the rule books of the
stage that needs them, or in the company `_config/` when more than one stage needs them. The
rule is about the toolkit, not about the user's domain.

---

## Pattern 8: Questionnaire Design

Onboarding configures the factory, not the product. Questionnaires follow six rules.

1. **Flat structure.** No category groupings. A numbered list of questions.
2. **All at once.** Every question in one pass, so the user can answer everything in a single
   message.
3. **System level only.** Ask about things that stay the same across runs: identity, voice,
   structure, defaults. Per run details are collected conversationally by the entry stage.
4. **Derive, do not ask.** If an answer can be inferred from another answer, fill it in. List
   derived fields under the question they depend on.
5. **Sensible defaults.** Every question carries a default or an example, so the user can
   skip what they do not care about.
6. **Ask once, never again.** After setup the user never sees these questions again. The
   answers are written into the workspace.

Questions map to placeholders. The syntax and the replacement contract are in
`spec/placeholder-syntax.md`.

---

## Pattern 9: Bundled Skills, and What a Skill Is Not

A workspace may bundle skills into a `skills/` folder so agents get domain knowledge without
the user installing anything globally.

```
workspace/
└── skills/
    └── <skill-name>/
        └── SKILL.md
```

**Vocabulary, and it is not negotiable.** "Skill" means one thing in this system: a folder
under `skills/` containing a `SKILL.md` with frontmatter. Files in `_config/` are **rule
books**. A stage `CONTEXT.md` is a **job card**. Never write "skills library" and never call
a rule book a skill. The three things have different owners, different budgets, and
different authority, and blurring the words blurs all three.

Frontmatter for every `SKILL.md`:

```
---
name: <must equal the directory name>
description: "This skill should be used when the user asks to '<trigger>', '<trigger>'... <what it does>."
user-invocable: true
argument-hint: "<modes>"
---
```

`user-invocable` is hyphenated. `user_invocable` with an underscore is banned and the checker
fails on it. `allowed_tools` is banned. Required keys and banned keys are in
`icm.defaults.json` under `frontmatter`.

Job cards reference skills in their Inputs table like anything else:

```
| Skill | `../../skills/<name>/SKILL.md` | Index, then load rules as needed | What it provides |
```

Do not bundle skills that are about the agent harness itself. Bundle skills that carry
domain knowledge the workspace's agents need at runtime.

---

## Pattern 10: Specs Are Contracts

A specification stage defines what the output must achieve and when things happen. It does
not prescribe how to implement. The build stage has freedom inside the quality floor its
rule books set.

A spec contains the outcome, the constraints, the moments that must land, and why each
matters. A spec does not contain implementation decisions. Those belong to the stage that
builds.

The test: if a competent builder reading the spec would produce something recognisably
correct but structurally their own, the spec is at the right altitude. If two builders would
produce byte identical output, the spec has done the build stage's job for it.

---

## Pattern 11: Checkpoints

Creative stages include at least one point where the agent stops and the human steers. The
agent finishes a full unit of work, presents options or a draft, and the human redirects
before the next unit starts.

Checkpoints go between process steps, never inside one.

```markdown
## Checkpoints

| After Step | Agent Presents | Human Decides |
|------------|---------------|---------------|
| 3 | Three angle options, one line each | Which angle to build |
```

Not every stage needs one. Linear stages such as extract, render, and validate usually run
straight through. Creative stages such as writing, design, and ideation almost always
benefit.

A checkpoint is not a call. Calls are the five triggers in the out-of-the-loop skill and they
fire on irreversibility, anchor breach, two strikes, target doubt, and scope fork. A
checkpoint is planned steering inside a stage. Do not use one where a call is required, and
do not fire a call where a checkpoint would do.

---

## Pattern 12: Stage Audits

Creative and build stages include an audit: a checklist the agent runs after the process and
before writing to `output/`. Audits catch quality problems before they propagate downstream.

```markdown
## Audit

| Check | Pass Condition |
|-------|---------------|
| Banned words | Zero hits from the banned list in the rule book |
| Evidence | Every number in the draft is located in a linked raw file |
```

Each check must be specific enough that pass or fail is unambiguous. If a check fails, the
agent revises before saving.

An audit is a self pass. It does not replace review by fresh eyes, and it never grades the
work against a definition of done that the same agent wrote. See `spec/authority-model.md`.

---

## Pattern 13: Value Validation

Content producing stages define what kinds of value their output can deliver, and the agent
and human agree which kinds this piece will hit before the creative work starts. Usually at
the first checkpoint.

This prevents output that is interesting but does nothing.

The value types are workspace specific. A content workspace might use novel, usable,
question generating. A course workspace might use teaches, practices, challenges. Define the
set once in a rule book and reference it at every checkpoint.

---

## Pattern 14: Rule Books Over Outputs

Rule books in `_config/` are the authoritative source for how to build. Files in `output/`
are artifacts, not templates. An agent does not read another stage's output to learn a
pattern.

Early outputs are the worst outputs. If later agents learn from them, quality never improves,
it converges on the first draft anyone happened to write.

The exception is the explicit handoff in pattern 2: a stage reads the previous stage's output
as material to transform, not as an example to imitate. The Inputs table makes which one it
is obvious, because it says why.

---

## Pattern 15: Shared Constants

Workspaces that produce code define a constants file. Configurable values, colours, fonts,
timings, endpoints, live in one shared file that every build output imports from. Onboarding
populates it once. Change a value once and it changes everywhere.

This is pattern 5 applied to code. Without it, the same hex code is hardcoded in every file
ever built, and changing the brand colour means a find and replace across the history of the
workspace.

For non code workspaces this pattern does not apply. Shared values live in rule books.

---

## Pattern 16: Rule Books Are Rulings

A rule book is a human's ruling written down. It says what is true and what is allowed in
this workspace. It is layer 3, it lives in `_config/`, and its budget is in
`spec/budgets.md`.

Three consequences.

**Only the human edits a rule book.** No script, no skill, and no agent writes to `_config/`.
An agent that finds a doctrine hole writes a proposal to `_log/FORGE-PROPOSALS.md` and stops.
See `spec/authority-model.md`.

**A rule book is not evidence checked.** The grounding invariant binds `wiki/`, which is
compiled from sources. A rule book is a decision, not a compilation. It does not need a raw
file behind it because a person decided it.

**A rule book states the rule and the reason, in that order.** Rule first because that is
what gets applied under load. Reason second because a rule with no reason gets ignored the
first time it is inconvenient.

When a folder holds more than about ten rule books, add an `_index.md` that routes to them,
and let job cards point at the index. That is pattern 4 applied to a folder.

---

## Pattern 17: Layers 1 to 3 Recurse

A company workspace holds departments. Each department repeats the same pattern inside
itself: its own `CONTEXT.md` for routing, its own `_config/` for rules, its own stages with
job cards.

```
company CONTEXT.md  ->  company _config/
        |
        v
department CONTEXT.md  ->  department _config/
        |
        v
stage CONTEXT.md (job card)  ->  the rule books this job names
```

Layer 0 does not recurse. There is one `IDENTITY.md` for the workspace.

Layer 4a does not recurse. There is one `raw/` at the root, because a source is a source no
matter which department cites it, and duplicating raw material breaks the grounding
invariant's one home rule.

The full rules, the read order, and the cost of each nesting level are in `spec/layers.md`.

Recursion is what lets one workspace hold a whole business without any single agent ever
loading the whole business. It is also a tax: every level between the root and the job card
is another file every task in that department must read. Keep departments one level deep
unless there is a reason.

---

## Pattern 18: The Grounding Invariant

Every load bearing fact in a `wiki/` article, every number, date, and direct quote, exists
verbatim in a `raw/` file that the article links.

Locate before you write. Write the value exactly as the source has it. If the source says
42K, write 42K, not 42,000. Derived values show their components so each component is
findable.

Instruction enforces this at write time. `scripts/check_evidence.py` verifies it when python3
exists. When python3 does not exist, the write time rule still binds and the log records that
the deep check did not run.

`spec/grounding-invariant.md` is authoritative. Read it before writing anything into `wiki/`.

---

## Pattern 19: Never Overwrite

Nothing a user wrote is ever deleted or rewritten. Most managed paths are only written when
nothing exists there. Two of them, `CLAUDE.md` and `.gitignore`, are edited in place, and only
between `<!-- icm:begin -->` and `<!-- icm:end -->`. Every byte outside those markers is
unchanged, and the pre-image is copied to `.icm/backup/<stamp>/files/` before the edit.

There is one exception to "no script writes to a rule book", and it is narrow: a script may
create a rule book that does not exist, once, as part of an install. No script and no agent
ever edits a rule book that exists. An existing rule book is always a collision.

When a file the toolkit wants to create already exists, the toolkit writes its version to
`.icm/proposed/` at the same relative path and reports the collision. The user diffs and
decides.

```
.icm/proposed/departments/sales/CONTEXT.md   <- what the toolkit would have written
departments/sales/CONTEXT.md                 <- untouched
```

`.icm/` is gitignored. It holds the plan, backups, and proposed collisions.

The folders that must never be written to at all, under any circumstance, are the
`never_write` list in `spec/excluded-folders.md`. That list is stricter than the collision
rule: for those paths there is no proposal, there is no write, the answer is no.

---

## Pattern 20: One Authority Model

Findings come in three tiers and there is exactly one set of definitions, used by lint and by
the forge alike.

- **Safe fix.** Deterministic, exactly one correct answer, auto applied.
- **Mechanical report.** A script found it, never auto fixed.
- **Judgment report.** Model opinion, always a proposal.

The logger never judges. The forge never edits. The human holds the only pen that touches
rule books.

`spec/authority-model.md` is authoritative, including the boundary test for which tier a
finding falls in and the reason the tiers exist at all.

---

## Pattern 21: Identity Is Model Agnostic

Layer 0 lives in `IDENTITY.md`. Not in `CLAUDE.md`, not in `.cursorrules`, not in
`.github/copilot-instructions.md`.

Harness specific files are **aliases, not copies**. An alias points at `IDENTITY.md`. It does
not restate it. A copy is a second home for the same information and pattern 5 says it will
drift, which it does, usually within a week.

Where the harness supports imports, the alias is an import:

```markdown
<!-- Alias. The workspace identity lives in IDENTITY.md. Do not edit this file. -->
@./IDENTITY.md
```

Where the harness does not support imports, the alias is one instruction:

```markdown
<!-- Alias. Do not edit this file. -->
Read `IDENTITY.md` at the workspace root before doing anything else. It is layer 0.
```

Either way the alias is a handful of lines and contains no workspace facts. If you find a
folder map inside a `CLAUDE.md`, that is a copy and it is a bug.

Upstream `icm-template` auto generates `CLAUDE.md` from `IDENTITY.md` as a full copy and syncs
them. This port does not, because a sync loop is the maintenance cost that the alias removes
entirely.

---

## Pattern 22: The Log Is Append Only

Four log files, all append only, all defined in `icm.defaults.json` under `log`.

| File | Holds |
|---|---|
| `_log/LOOP-LEDGER.md` | One line per closed task, one line per call fired, the weekly review block |
| `_log/LOOP-RUNLOG-<task>.md` | One line per event during a task, timestamped |
| `_log/FORGE-PROPOSALS.md` | What the forge proposes, awaiting approval |
| `wiki/log.md` | Ingest, query, and lint operations against the wiki |

The ledger and run log formats are **not defined here**. They are defined in the
out-of-the-loop skill's `references/ledger.md`, and this toolkit uses those formats unchanged.
Pattern 5 applies to formats as hard as it applies to facts. If the ledger format changes
there, it changes here, because there is no copy here to update.

Three rules about logging.

**Never rewrite history.** A line goes in and stays in. A wrong line is corrected by a new
line, not by an edit.

**Log into a file, not into context.** Context gets compacted. A loop that logs into its own
context window forgets exactly the runs long enough to matter.

**The log records verdicts, it does not form them.** The logger writes down what a review
decided. It does not decide. See `spec/authority-model.md`.

---

## Pattern 23: Budgets Are Checkable

Budgets in this toolkit are in **chars, not tokens**, because chars can be checked with `wc`
on any machine and tokens cannot.

```sh
wc -c < IDENTITY.md
```

Every budget lives in `icm.defaults.json`. `spec/budgets.md` explains each one and shows the
arithmetic. Never restate a budget as a literal in prose anywhere else in this repo. Cite the
file.

Target means write to this size. Ceiling means lint fails above this size. The gap between
them is room to breathe, not room to spread.

When a file exceeds its ceiling the fix is almost never compression. It is a split, a
pointer, or a section reference. A rule book at twice its ceiling is two rule books. A job
card at twice its ceiling has content in it that belongs in a rule book.

---

## Pattern 24: The Architect Pattern

**The folders are the agents.** An agent is spawned into a folder, reads what that folder
names, does the job, writes its report, and dies. Agents are ephemeral. Reports are files.

**Nobody sits above the folders.** There is no orchestrator process, no supervisor object and
no long-lived session that has to stay alive for the system to make sense. The lead architect
is simply whichever LLM opens the top folder. Any model, any vendor, any day, can walk in and
take the chair. The org chart lives in the tree, not in code, and no single agent is load
bearing.

This is pattern 17's recursion carried to its conclusion. Recursion says a department repeats
the workspace pattern inside itself. This pattern says the same thing about who does the work:
the department is the worker, the folder is the address, and the agent is the short-lived thing
that shows up at it.

### The shape

```
the workspace
  IDENTITY.md         layer 0, where am I
  CONTEXT.md          layer 1, where do I go
  ARCHITECT.md        layer 2, the job card for the root folder
  status.md           layer 4b, the rollup, one line per department
  _config/            layer 3, the rule books everyone obeys
  sales/
    CONTEXT.md        layer 1, routing inside the department
    ARCHITECT.md      layer 2, only if this department spawns its own workers
    status.md         layer 4b, this department's one line, compiled
    report.md         a pointer at the newest report, never a report itself
    reports/          the reports, one file per run, append only
      2026-08-30-q3-pipeline-review.md
    _config/          layer 3, rules only sales obeys
    01-leads/         layer 2, a stage with its own job card
  marketing/
    ...
```

`ARCHITECT.md` is **a layer 2 job card for the root folder**. It is not a new layer. The layer
stack is 0, 1, 2, 3, 4a, 4b, unchanged, and pattern 17 still says which of those recurse. What
`ARCHITECT.md` holds is the job of the folder it sits in, in exactly the shape any job card
takes: read the rollup, decide who works today, spawn agents into departments, never do the
work yourself.

`status.md` is **layer 4b: compiled, and never authoritative**. Workers write their one line
into it, the architect reads it to decide where to look, and that is the whole of its job. If
`status.md` disagrees with the folder, **the folder wins**. A rollup is an index, and an index
that contradicts the thing it indexes is a stale index, never a correction to it.

### The five rules

**1. Agents are ephemeral, reports are files.** A worker's last act is writing its report and
its one status line. Nothing else it holds survives. A worker that finished the job and wrote
nothing did not finish the job.

**2. The architect reads reports, not conversations.** Not transcripts, not scrollback, not
what it remembers deciding. Reports are the interface between a dead agent and a live one.

**3. Messages coordinate, files record.** Messages are allowed and useful, and they decide
nothing. No decision is real until it is written in the folder. If the only record of a call is
in a conversation, that call was never made.

**4. The architect never does department work, except below the small task floor.** Under the
floor, spawning an agent costs more than the task does, so the architect does the work itself
and logs that it did. Above the floor it spawns and stays out of the way. Each workspace sets
its own floor, in words, in its root `_config/conventions.md`, and the floor is a written rule
rather than a judgement made fresh each time.

**5. Any LLM that opens the top folder and reads `IDENTITY.md`, `CONTEXT.md`, `ARCHITECT.md`
and `status.md` is the lead architect.** There is no appointment, no handover meeting and no
state to transfer. The handover is the filesystem.

### Reports are append only

A report is never written to a path a later report will take. Reports land in
`reports/YYYY-MM-DD-slug.md`, one file per run, and `report.md` holds a pointer at the newest
one and nothing else.

Writing every worker's output over a single `report.md` would break two patterns at once:
pattern 19, because the second worker overwrites the first worker's file, and pattern 22,
because the record of what happened stops being append only and becomes a snapshot of whoever
ran last. The reason those patterns exist is exactly this case. A wrong report is corrected by
a new report, never by an edit.

### Why the tree and not code

An org chart in code is a thing you have to run to read. An org chart in folders is a thing you
can open. The routing, the reporting lines and the division of labour are all visible to
anyone who can list a directory, which means a non-programmer can audit the structure and a
model with no memory of yesterday can rejoin it cold.

It also removes the failure mode every orchestrator has: the single process that must stay up.
Kill any agent here at any moment and the workspace is unharmed, because the agent was never
where the state lived.

---

## Trigger Keywords

Every workspace built with this toolkit recognises these.

**`setup`** starts onboarding. The agent reads the questionnaire, asks the questions
conversationally, collects the answers, replaces the placeholders, then sweeps the workspace
for any remaining `{{`. Onboarding is complete only when zero placeholders remain.

**`status`** shows pipeline completion. The agent scans every `stages/*/output/` folder and
reports which stages are complete and which are pending. A folder holding only `.gitkeep` is
pending.

**`lint`** runs the checks and reports. It applies safe fixes and reports everything else.
Authority per finding is in `spec/authority-model.md`.

Workspaces may define their own additional triggers in their root `CONTEXT.md`.

---

## Naming Conventions

- Folders and files: `lowercase-with-hyphens`
- Stage folders: zero padded number prefix, `01-`, `02-`, `03-`
- Placeholders: `{{SCREAMING_SNAKE_CASE}}`
- Output artifacts: `[topic-slug]-[artifact-type].md`
- Raw files: `YYYY-MM-DD-descriptive-slug.md`, kebab case, slug capped at 60 chars
- Reports: `reports/YYYY-MM-DD-descriptive-slug.md`, kebab case, never overwritten
- No spaces in any file or folder name
- Structural files keep their conventional casing: `IDENTITY.md`, `CONTEXT.md`, `SKILL.md`,
  `ARCHITECT.md`. `status.md` and `report.md` are lowercase, because they are compiled
  artifacts rather than authored ones

---

## Quality Guardrails

- Job cards stay under their line ceiling in `spec/budgets.md`
- Rule books that outgrow their ceiling get split, not compressed
- Plain English. If a term needs explaining, it is too specialised for a job card
- Second person. Short declaratives
- No em dashes in user facing copy
- Every folder that must persist but starts empty gets a `.gitkeep`
- Every markdown file is readable by someone who knows markdown and git and nothing else
- Every load bearing number in a `wiki/` article is locatable in `raw/` before it is written
- Every script passes `sh -n`

---

## The Shape of the Whole Thing

Five ideas hold the system up. Four are from the upstream methodology. The fifth is what the
Karpathy layer adds.

**One stage, one job.** A stage that researches does not also write. A stage that writes does
not also build.

**Plain text as the interface.** Stages talk through markdown files. Any tool that reads text
can join in. Any human with an editor can inspect or change any artifact.

**Layered context loading.** Agents load only what the current job card names. This is
prevention, not compression.

**Every output is an edit surface.** The intermediate output of each stage is a file a human
can open, change, and save before the next stage runs. The system picks up whatever the human
left there.

**Nothing compiled is unsourced.** Everything in `wiki/` traces to something immutable in
`raw/`. Knowledge compounds instead of drifting, because you can always ask a claim where it
came from and get a file path back.
