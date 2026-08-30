# The Authority Model

One model. Three tiers. Used by `icm-sync` lint and by `icm-forge` alike, and by anything else
in this toolkit that finds a problem.

There is exactly one set of definitions and it is here. A skill that invents a fourth tier, or
that treats a judgment call as a safe fix because it happens to be confident, has broken the
model.

---

## The Rule

**The logger never judges. The forge never edits. The human holds the only pen that touches
rule books.**

Everything below is that sentence with the details filled in.

---

## The Three Tiers

| Tier | Who found it | Auto applied | Where it goes |
|---|---|---|---|
| Safe fix | A script, deterministically | Yes | Applied, then counted in the report |
| Mechanical report | A script, deterministically | No | The report, for a human to decide |
| Judgment report | A model, by opinion | No | A proposal, for a human to approve |

### Safe fix

Deterministic. Exactly one correct answer exists and a script can find it. Applied without
asking.

The boundary test, and it is the important sentence in this file:

> **A safe fix only ever restores agreement between two things the toolkit already owns. It
> never changes what a file means.**

An index that disagrees with the article it indexes has one correct resolution: the article
wins. A folder map that disagrees with the disk has one correct resolution: the disk wins. No
opinion is involved because neither side is a claim about the world.

Examples that qualify:

- A file exists on disk but is missing from `IDENTITY.md`'s workspace map. Add it.
- An entry in `wiki/index.md` points at a file that does not exist. Mark it `[MISSING]`, do
  not delete the row, let the user decide.
- An `Updated` date in `wiki/index.md` differs from the article's own `Updated`. Match the
  article.
- An internal link is dead and a search finds **exactly one** file with that name. Fix the
  path.
- A `Raw:` link is dead and a search finds **exactly one** matching file in `raw/`. Fix the
  path.
- A `See Also` link is dead and a search finds zero matches. Remove the link, because a dead
  cross reference is not load bearing.
- A routing row points at a file that moved, with exactly one candidate destination.

Note the shape of those. Every one of them turns on "exactly one match". Zero matches or two
matches is not a safe fix, it is a mechanical report, because a script that picks between two
candidates is making a judgment while wearing a script's authority.

Every safe fix is reversible and every safe fix is counted in the report. Auto applied does
not mean invisible.

### Mechanical report

A script found it. Detection is deterministic. The fix is not. Never auto applied.

The boundary test: the finding is certain, the remedy requires a decision, or the remedy
changes what a file means.

Examples that qualify:

- **Source fidelity suspects** from `scripts/check_evidence.py`. A literal in an article does
  not appear in the raw files it links. That is certain. Whether it is a real breach or a
  legitimately derived value is a person's read of the raw context. See
  `spec/grounding-invariant.md`.
- **Evidence errors.** An article has no `Raw:` field, or its `Raw:` links do not resolve, or
  they escape `raw/`. Certain, and every resolution is a decision.
- **Budget breach.** `wc -c` says a file is over its ceiling. The number is not arguable. The
  fix is a split, a pointer, or a section reference, and choosing between those is design. See
  `spec/budgets.md`.
- **Missing required section.** A job card has no `## Outputs`. Certain. Writing the section
  is work, not a fix.
- **Banned frontmatter key.** A `SKILL.md` uses `user_invocable` instead of `user-invocable`.
  The correct spelling is not in doubt, but the key changes how the harness loads the skill,
  so it fails the boundary test above and a human applies it.
- **Unreferenced raw file.** A file in `raw/` that no article cites, excluding those logged as
  no material. A backlog reminder, not an error.
- **Dead link with two or more candidates.** Certain that it is dead, undecidable which one
  was meant.

Mechanical reports are the tier most likely to be quietly promoted to safe fix by an agent in
a hurry. Do not. The distinguishing property is not confidence, it is whether a decision is
being made.

### Judgment report

A model's opinion. Always a proposal. Never applied, ever, in any circumstance.

The boundary test: a competent reviewer could disagree.

Examples that qualify:

- A factual contradiction between two wiki articles.
- A claim superseded by a newer source but still presented with no status block.
- A missing conflict annotation where sources disagree.
- A cross reference that obviously should exist between two related articles. Suggest it, do
  not add it.
- An orphan page nothing links to.
- A concept mentioned constantly with no page of its own.
- A doctrine hole: a question the rule books cannot answer, that keeps coming up.
- A job card whose `Process` does not plausibly produce its `Outputs`.
- A stage that is doing two jobs and should be split.
- A rule book that has become two rule books.

Judgment findings against rule books are the forge's entire output. They go to
`_log/FORGE-PROPOSALS.md` and they wait.

---

## Who May Do What

| Component | Reads | May auto apply | May propose | May never |
|---|---|---|---|---|
| `icm-sync` lint | The workspace tree, `IDENTITY.md`, `CONTEXT.md` files, `wiki/` | Safe fixes only | Mechanical and judgment findings, in its report | Write to `_config/`, write to `raw/`, overwrite a user file |
| `scripts/check_evidence.py` | `wiki/`, `raw/`, `wiki/log.md` | Nothing | Mechanical findings, in its report | Modify any file at all |
| `icm-forge` | `_log/LOOP-LEDGER.md`, `_log/LOOP-RUNLOG-*.md`, `wiki/log.md`, `_config/` | Nothing | Judgment proposals into `_log/FORGE-PROPOSALS.md` | Edit any file other than its own proposals file |
| `icm-log` | The run log and the ledger | Appends its own log lines | Nothing | Judge, grade, summarise a verdict, or rewrite a past line |
| The human | Everything | Everything | | |

Three of those rows carry the weight.

**The forge never edits.** It reads the logs, it finds patterns, it writes proposals, and it
stops. It does not touch `_config/`. It does not touch job cards. It does not touch the wiki.
Its only write in the entire system is an append to `_log/FORGE-PROPOSALS.md`.

**The logger never judges.** `icm-log` writes down what happened, including verdicts that
other components reached. It does not reach verdicts. It does not soften a failure into a
note, and it does not decide that a finding was probably fine. A logger with an opinion is a
logger that eventually edits the record to match it.

**Nothing writes to `_config/` except a human.** Rule books are layer 3, they are rulings, and
a ruling with no ruler is just a preference the system developed about itself. See
`spec/layers.md`.

---

## Why the Tiers Exist

An agent that grades its own work optimises the grade, not the outcome.

This is Goodhart, and it is not a hypothetical failure mode in agent systems, it is the
default one. Give a single loop the job of doing the work, the job of deciding whether the
work is good, and the job of changing the standard the work is measured against, and it will
converge. It will converge on something that passes. Passing and being right are different
targets, and only one of them has a feedback signal the agent can see.

The three tiers are a separation of those jobs, expressed as file permissions.

- The tier that can auto apply is restricted to changes with no discretion in them at all, so
  there is nothing to optimise.
- The tier that has discretion cannot apply anything, so its opinion costs the system nothing
  until a human agrees with it.
- The standard itself, the rule books, is outside every agent's reach, so no amount of
  proposing can move the target.

The out-of-the-loop skill this toolkit logs into makes the same separation and states the same
reason: the definition of done is held out and locked before work starts, review is a separate
pass from execution, and threshold changes are proposals to the human and never silent edits,
because the optimiser does not get to touch its own leash.

The failure this prevents is specific and it is quiet. A forge that could edit rule books
would, over a few months, produce a set of rule books that its own output satisfies perfectly.
Every lint would pass. Nothing would be wrong, and nothing would be true either, because the
standard would have walked to meet the work instead of the work walking to meet the standard.

Keeping the pen in one human hand is what keeps the system attached to reality. It costs a
review cycle. It is worth it.

---

## Proposals

A proposal is what a judgment finding becomes when it concerns a rule book.

### What fires one

The forge reads logs. It does not read opinions and it does not read its own past proposals as
evidence. Three patterns fire a proposal:

1. **A repeated hole.** The same class of mistake caught more than once on the same subject.
   Once is a mistake. Twice on the same subject is a hole in doctrine and the fix belongs in a
   rule book, not in a better attempt.
2. **A recurring blocker.** The same blocker beaten by a workaround on more than one task. The
   out-of-the-loop ledger records workarounds in their own column precisely so this is
   countable. A blocker appearing twice is a system hole: build the fix once as its own task
   and stop paying the toll.
3. **An unanswerable question.** A question the rule books cannot answer, logged more than
   once. That is a gap in coverage rather than a wrong rule.

The counting is done against the ledger and the run logs, by date and task, and the proposal
quotes the lines. A proposal with no log lines behind it is an opinion the forge invented, and
it does not get written.

### Format

Appended to `_log/FORGE-PROPOSALS.md`, using the same heading shape as the wiki log so the two
logs read the same way:

```markdown
## [2026-08-30] proposal | _config/objections.md | No ruling on multi-year discounting

- Tier: judgment
- Pattern: unanswerable question, 3 occurrences
- Evidence: LOOP-LEDGER 2026-08-12 acme-outreach-04; 2026-08-19 acme-outreach-07;
  2026-08-26 acme-renewals-02
- Proposed: add a "Discounting" section to `_config/objections.md` stating the ceiling
  and who may approve an exception
- Blast radius: read by departments/sales stages 02 and 03
- On silence: nothing changes
```

Six fields, all required.

`Blast radius` names every job card that loads the rule book. A rule book change is not local,
because layer 3 is loaded by every stage that names it, and a reviewer needs to see the reach
before approving.

### On silence, nothing changes

**A forge proposal never proceeds by default.** Not after four hours, not after a week, not
ever.

The out-of-the-loop call model lets a scope fork proceed on a stated default after four hours
of silence, and never lets an irreversible action proceed on silence at all. A rule book
change is doctrine. Changing doctrine without a decision is target surgery, which that model
classes as a call in its own right rather than something to route around. So the forge sits at
the irreversible end: it waits, indefinitely, and an unanswered proposal stays in the file as
an open one.

An unanswered proposal is not a failure. It is a queue, and a queue that keeps growing on one
subject is itself a finding worth raising at the weekly review.

---

## Logging a Finding

Every finding, in every tier, is written down with its tier attached. The tier is part of the
line, not a note about it, because a report where safe fixes and judgment calls look the same
trains the reader to skim past both.

Lint appends its summary line to `wiki/log.md` in the log's existing shape:

```
## [2026-08-30] lint | 11 issues found, 4 auto-fixed
```

Auto fixed counts safe fixes only. It can never count a mechanical or judgment finding,
because those were not fixed. If those numbers are ever equal, something applied a fix it had
no authority to apply.

When the evidence deep check could not run, the lint line says so rather than staying silent
about it. See `spec/grounding-invariant.md`.

Task level and call level records go to `_log/LOOP-LEDGER.md` and `_log/LOOP-RUNLOG-<task>.md`,
in the formats defined by the out-of-the-loop skill's `references/ledger.md`. Those formats are
not restated here and they are not restated anywhere else in this repo. Canonical sources
applies to formats exactly as hard as it applies to facts.

---

## The Short Version

| Question | Answer |
|---|---|
| Can a script fix it with no discretion? | Safe fix. Apply it, count it. |
| Is the finding certain but the remedy a decision? | Mechanical report. Report it, do not touch it. |
| Could a competent reviewer disagree? | Judgment report. Propose it, wait. |
| Does it change a rule book? | Proposal. Only a human applies it. |
| Did nobody answer? | Nothing changes. |
