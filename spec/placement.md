# Placement

Where a learned thing lives. This file is authoritative on one question: a task taught the
workspace something, and the Session Close in `CONTEXT.md` has asked where it goes. The answer
is a kind, a layer and a path, and the rule for the depth. `spec/layers.md` says what each
layer is. This file says which layer a new thing belongs to, and it defers to `spec/layers.md`
for everything else.

The rendered form of this table ships inside every generated `_config/conventions.md` under
the heading Where A Learned Thing Lives, so an agent in a workspace never needs this repo open
to answer the question. That rendered table and this file agree because `scripts/icm_lib.sh`
is the only thing that writes the rendered one; if they ever differ, this file is right and
the body in `icm_lib.sh` is the bug.

---

## The question

At Session Close, after the misses, before the task line:

> Did this task produce a repeatable procedure, a rule, or a fact that nothing on disk holds?

Three honest answers. **No**, and nothing is written. **Yes, and a file already holds the
ground**, which is a miss against that file, not a placement: the file was there and was
silent, so log the miss and let the forge propose the edit. **Yes, and nothing holds it**,
which is the only case this file governs.

The agent does not create the thing. It appends a proposal of kind `new` to
`_log/FORGE-PROPOSALS.md` naming the kind and the path from the table below, and stops.
Nothing new lands on disk until a human names the proposal id. That is what "lock it away"
means: the learning is recorded the moment it happens, at the place it will live, and the
creation waits for a decision. An agent that creates a rule book at close because it seemed
obviously right has just edited layer 3 without a human, and `spec/authority-model.md` says
what that is.

---

## The table

| What was learned | Kind | Layer | Lives at |
|---|---|---|---|
| A rule: a do, a never, a threshold, a wording that binds | Rule book | 3 | `_config/<book>.md`, the existing book nearest in subject. A new book only when no existing book could plausibly hold the rule |
| How this folder does its job: a step, an input, a checkpoint | Job card | 2 | That folder's `CONTEXT.md`, in Process, Inputs or Checkpoints |
| A procedure invoked by name, reused across folders or across workspaces | Skill | outside the layers | `skills/<name>/SKILL.md` in the harness that runs it. Written by `skill-creator` or the harness's own authoring path, never by the forge |
| A fact about the world: a number, a date, a quote, a source | Source, then article | 4a then 4b | `raw/<topic>/YYYY-MM-DD-slug.md` first, then the `wiki/` article that cites it. Never a rule book |
| A fact about this workspace: a folder exists, a route was missing | Map or route | 0 or 1 | `IDENTITY.md` for the map, the routing `CONTEXT.md` the route belongs to |
| A repeated blocker and its workaround | System fix | its own task | One task line proposing the fix. Not a rule, not a skill. A blocker in two task lines is a hole in the system, and the fix is built once |

Two tests decide between the rows that look alike.

**Rule book or job card.** Does it bind every task in the folder, or does it describe what one
job does? "Never quote below the rate card" binds everything sales does: rule book. "Step 3
reconciles against the bank export in `raw/bank/`" is how one stage works: job card.

**Job card or skill.** Is it ever invoked by name from outside the folder that owns it? A
procedure only this stage runs is its job card, and a job card is not a skill
(`spec/layers.md`, layer 2). A procedure that three departments call by the same name, or
that another workspace would want, is a skill, and it goes to the harness, not the tree.

---

## Depth

The path in the table says which file kind. The depth rule says which folder.

**The lowest folder that covers every place the thing applies.** A rule sales alone needs goes
in `sales/_config/`. The moment marketing needs the same rule, it moves up to the company
`_config/` and sales links to it. That is `spec/layers.md` recursion rule 2 applied at
placement time rather than discovered a year later.

**Never sideways.** A sales rule is never placed in marketing's `_config/`, and a job card never
names another department's book (`spec/layers.md` recursion rule 3). If a rule seems to belong
to two siblings and only two, it belongs to their parent.

**Never up into layer 0.** `IDENTITY.md` holds the map and the standing rules of the house,
and it does not grow a rule because one was learned today. A rule learned today is layer 3 by
definition: doctrine, human-owned, budgeted.

**Depth costs.** Every level between the root and a job card is one more file every task in
that department reads, forever (`spec/layers.md`, recursion rule 6). Placement does not create
a level. If the right folder does not exist, the proposal says so and the human decides whether
the tree grows.

---

## The proposal

A placement proposal is a forge proposal with `Kind: new`. Same block, same file, same
authority as an edit. The differences:

- **Evidence** may be one ledger line. An edit needs two lines because it changes a book that
  exists; a new thing needs one line proving the ground was empty: the miss against `none`
  when something went wrong, otherwise the task line of the run that taught it.
- **Smallest edit** names the kind, the exact path, and the text or shape. For a rule, the
  sentence. For a job card step, the step. For a skill, the name and the one-line description,
  and the note that `skill-creator` writes the body.
- **Test that proves it** is the check that would have caught the miss that prompted it. A
  placement with no test is a note, and a note is not written.

`icm-forge approve` on a `new` proposal creates the file or the section at the named path,
once, and writes the patched line. `spec/CLI-CONTRACT.md` section 8 already allows a rule book
to be created once as part of an install; this is the same allowance, extended to a human
naming an id.

---

## What the index does with it

`scripts/icm-loop.sh` reads every miss logged against `none` and marks the row `uncovered`.
That is the mechanical signal that ground is empty. Two `uncovered` misses about the same
subject in one forge cycle mean the placement question was answered with a proposal that
nobody has approved yet, or was never asked. Either way the forge says so, and says which.

---

## What this file must never do

| Never | Because |
|---|---|
| Let an agent create the thing at close | Layer 3 is human-only. So is a job card. A skill is a harness decision |
| Route a rule into `IDENTITY.md` | Layer 0 does not hold doctrine (`spec/layers.md`) |
| Route a fact into a rule book | A rule book is a decision. A fact has a source, and the source lives in `raw/` |
| Place sideways | Two homes for one fact, and the grounding invariant breaks |
| Grow the tree to place one thing | Every level is a permanent tax on every task below it |
