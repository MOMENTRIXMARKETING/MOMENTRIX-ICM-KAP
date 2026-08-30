# Methodology

Why the folders are shaped this way. No instructions here, only reasons. For the rules
themselves read [`../spec/CONVENTIONS.md`](../spec/CONVENTIONS.md); for every number read
[`../spec/budgets.md`](../spec/budgets.md), which is generated from
[`../icm.defaults.json`](../icm.defaults.json) and is the only place a budget is allowed to
exist.

---

## The problem this solves

Give a model a large working folder and it will read too much of it. Every irrelevant token is
a diluted token. The usual fix is to bolt on a framework: an orchestrator in Python, agent
objects, a task graph, a vector store. That fix buys routing at the cost of legibility. The
wiring now lives in code, the reasoning lives in a prompt string, and neither is a thing a
non-programmer can open and correct.

The alternative is older and duller. Put the routing in the filing cabinet. Name the folders so
the order of work is visible. Put one short instruction file in each folder saying what comes
in and what must go out. The structure becomes the architecture, and a person who can organise
a shelf can now maintain an agent system.

That is the Interpretable Context Methodology. It is Jake Van Clief and David McDermott's, from
the Model Workspace Protocol and the paper reproduced in
[`paper/Interpretable-Context-Methodology.pdf`](paper/Interpretable-Context-Methodology.pdf).
This toolkit implements and extends it. It did not invent it.

---

## The compile metaphor

The model is a compiler, not a chatbot.

A compiler has a declared input, a declared output, and rules it applies in between. It does not
negotiate. It reads what the contract names, transforms it, and writes the result to a stated
path. A conversation is not part of the run. It happens at the review gate, before the next
stage starts.

This is the whole reason a stage folder has the shape it has. Its job card declares Inputs,
Process and Outputs. That is a function signature written in markdown. Give the same inputs to
the same job card and you should get the same class of output, because nothing else was in
scope. When the output is wrong you do not argue with the model, you look at the three sections
and find which one lied.

The consequence people miss: because the handoff is a file in a predictable place, a human can
open it between stages, edit it, and the next stage compiles the edited version. There is no
state to manage and no orchestration layer to lie to. The pipeline stops being a black box
because you can read every intermediate.

---

## The five layers

Agents read down the layers and stop as soon as they have enough.

| Layer | Where | Question it answers |
|---|---|---|
| 0 | `IDENTITY.md` | Where am I? |
| 1 | root `CONTEXT.md` | Where do I go? |
| 2 | stage or folder `CONTEXT.md`, the job card | What do I do? |
| 3 | `_config/` rule books | What rules apply? |
| 4a | `raw/` | What is true? |
| 4b | `wiki/` and `output/` | What do we know, and what did we make? |

The authoritative table, including what each layer may and may not contain, is
[`../spec/layers.md`](../spec/layers.md). Every size ceiling for every one of these files is in
[`../spec/budgets.md`](../spec/budgets.md).

Layer 2 is the control point. Its Inputs table decides exactly which Layer 3 rule books and
which Layer 4 artifacts get loaded for this task and no others. Nothing pushes context down the
pipeline. Each stage pulls the short list it named.

Layers 0 through 3 are the fixed cost of entering a workspace. That cost is a budget, it is
stated once in [`../spec/budgets.md`](../spec/budgets.md), and it does not grow when the
workspace grows. Layer 4 varies by task, which is the point: the part that scales is the part
you choose per run.

Two consequences worth naming.

**Layer 3 and Layer 4 want different things from the model.** Layer 3 material has to be
internalised as constraint: write like this, price like this, never say that. Layer 4 material
has to be processed as input: turn this research into a script. Layer 3 is the factory. Layer 4
is the product. Collapsing them is the most common way a workspace goes bad, because rules
start getting treated as material to remix.

**Layer 4a and Layer 4b are not the same layer.** Upstream, both the immutable sources and the
compiled wiki sat under one Layer 4, and separately the stage `output/` folder also claimed
Layer 4. Three incompatible meanings for one number. This toolkit splits them: 4a is what
arrived and is never edited, 4b is what was made and can always be remade. If you can regenerate
it, it is 4b. If losing it means losing evidence, it is 4a.

---

## The recursion

Layers 1, 2 and 3 repeat inside themselves. This is the property that makes the thing scale
without a new idea.

A company workspace has an `IDENTITY.md`, a routing `CONTEXT.md`, and `_config/` rule books
that apply company-wide. One of its top-level folders is `sales`. Open it and you find the same
three things: a routing `CONTEXT.md` for sales tasks, a `_config/` holding pricing and
objection rule books that only sales obeys, and numbered stage folders underneath. Open
`01_leads` and you find a job card with Inputs, Process and Outputs.

An agent walking in reads the company map, the company rule books, then the department map, the
department rule books, then one job card. Four short reads and it knows where it is standing,
whatever the size of the building. A five-person business and a five-hundred-person business
differ only in how many times the pattern repeats, never in what the pattern is.

Two rules keep the recursion from turning into a knot.

**References point outward, never back.** If a later stage reads an earlier stage's output, the
earlier stage must not reference the later one. Without this, cross-references grow with the
square of the folder count and the tree eventually cannot be reasoned about.

**Every fact has one home.** Other files point at it. They do not copy it. If the same rule
appears in two files and both read as authoritative, one of them is already wrong and nobody
has noticed yet. This is why budgets live in one JSON file, why the skip list lives in
[`../spec/excluded-folders.md`](../spec/excluded-folders.md) and nowhere else, and why this
document keeps sending you to `spec/` instead of telling you the number.

---

## The archetypes, and the architect shape

How much of the layer set a workspace installs is an archetype. There are three install
archetypes and one shape built on top of them.

| Archetype | What it installs | Reach for it when |
|---|---|---|
| `quick` | Layers 0, 1 and 3, plus the log. The default. | Most projects, and every project that will never compile knowledge |
| `full` | `quick` plus `output/` | The work produces artifacts a human reads |
| `wiki` | `full` plus `raw/`, `wiki/` and the grounding rule book | You have sources to turn into knowledge |
| `architect` | A `full` install at the root, plus one department folder per team | A whole organisation in one tree, worked by agents spawned into a folder |

The first three are install manifests and the scripts know their names.
`architect` is not: it is a **shape**, assembled on top of a `full` install one department at a
time. It is what recursion looks like when you stop treating the tree as a filing system and
start treating it as the org chart.

The claim it rests on is that an agent is not a persistent thing. It is spawned into a folder,
reads the three or four short files that folder names, does the job, writes a report, and dies.
What persists is the folder and the reports in it. Which means the lead architect is not a
role a particular model holds: it is whoever opens the top folder next. Any model, any vendor,
any day, can walk in and take the chair, because the handover is the filesystem rather than a
conversation somebody has to have been present for.

That is Pattern 24 in [`../spec/CONVENTIONS.md`](../spec/CONVENTIONS.md), which is
authoritative for it, including the five rules and the small-task floor.

---

## The three-way split

Rule books tell the model how to work. They do not tell it what is true. Those are different
problems and they need different folders.

| Folder | What it holds | Who writes it | Who edits it |
|---|---|---|---|
| `_config/` | how we work | you, once, at setup | you, deliberately |
| `raw/` | what is true | you collect it | nobody, ever |
| `wiki/` | what we know | the model, from `raw/` only | the model, on recompile |

`_config/` is stable. It changes when your standards change, which is rarely, and every change
is a decision someone made on purpose.

`raw/` is append-only. A transcript, an article, a report, a screenshot of a policy: it goes in
exactly as it arrived and is never tidied. Immutability is not tidiness for its own sake. It is
what makes a verified claim stay verified. If the source cannot change under you, then a check
that passed last month still means something today.

`wiki/` is derived. The model reads `raw/`, works out what it means, and writes articles. This
half is Andrej Karpathy's idea: the model writes and maintains the wiki, the human reads it and
asks questions of it, and the wiki is a persistent artifact that compounds rather than being
rebuilt each session. The implementation this toolkit vendors and extends is Yuhan Lei's
karpathy-llm-wiki. Idea credit and code credit both, set out in
[`../NOTICE.md`](../NOTICE.md).

Add a source on Monday and every run from Tuesday already knows it. Nothing is relearned and
nothing is lost.

The capacity story is the same one as the rule books, for the same reason. The model never
reads the whole wiki. It reads `wiki/index.md`, picks the articles that matter, and opens only
those. A large wiki costs about what a small one costs to consult, because the saving comes
from structure rather than cleverness. The article ceiling that keeps this true is in
[`../spec/budgets.md`](../spec/budgets.md).

---

## The grounding invariant

Every load-bearing fact in a compiled file, meaning every number, date and direct quote, exists
verbatim in a `raw/` file that the article links to.

This one rule is the difference between a knowledge base and a pile of confident guesses. Take
it away and the wiki still looks exactly the same, reads exactly as fluently, and is worth
nothing, because no claim can be traced.

It is enforced twice, at different strengths.

**At write time, by instruction.** Locate the fact in a source before you write it down. If it
cannot be located, it does not go in the article. This covers everything, including the claims a
script cannot recognise.

**At check time, by script.** `scripts/check_evidence.py` greps the high-signal literals out of
an article and looks for each one in the raw files that article's Raw field names. It runs over
the whole wiki in seconds and needs no incremental state, because `raw/` is immutable.

The verifier is optional and needs `python3`. That is a deliberate asymmetry. The instruction
is the invariant. The script is a second opinion. A toolkit whose correctness depends on an
interpreter being installed is a toolkit that quietly stops being correct on the first machine
that lacks it.

Stated formally in [`../spec/grounding-invariant.md`](../spec/grounding-invariant.md).

---

## The authority model

Both the linter and the forge classify every finding into one of three tiers, and the tier
decides who is allowed to act.

**Safe fix.** Deterministic and auto-applied. A dead link with exactly one possible target. An
index row out of sync with the file it names. There is one right answer and a script can prove
it.

**Mechanical report.** A script found it and a script must not fix it. A fact in the wiki that
does not appear in its raw. A file over its ceiling. The finding is certain, the remedy is a
judgement call, so it gets reported and stops there.

**Judgment report.** A model opinion. A missing cross-reference, a doctrine hole, a rule book
that contradicts itself. Always a proposal, never a change.

From which follow the three sentences that govern the whole toolkit:

> The logger never judges. The forge never edits. The human holds the only pen that touches
> rule books.

An agent that grades its own work optimises the grade, not the outcome. So the loop is split:
the logger writes what happened to `_log/LOOP-LEDGER.md` and takes no view on it, the forge
reads that ledger and writes proposals to `_log/FORGE-PROPOSALS.md`, and you approve or reject
them. The system improves once a week, by a decision, on evidence. That is slower than
self-editing and it is the only version anyone can trust.

---

## Why POSIX sh, and why nothing else

Every script here uses only `sh`, `grep`, `sed`, `awk`, `wc`, `find`, `sort`, `diff`, `cat`,
`head`, `tail`, `mkdir`, `cp`, `mv`, `rm`, `printf`, `date`, `basename`, `dirname`, `tr`,
`rmdir`, `cmp` and `ls`. All POSIX. No bashisms, so the same file runs under `dash` and
`busybox sh` as it does under `bash`. No python and no node are required anywhere.

Three tools sit outside that list and each one is guarded. Hashing takes `shasum`, else
`sha256sum`, else a size-plus-mtime fingerprint; neither hasher is POSIX, every mainstream
image ships one, and when the fallback does fire the scripts announce it and stamp the mode
into the manifest. `git` is used for one thing, the dirty-repo refusal, and a machine without
it skips that refusal. `python3` runs the one optional deep check. The full tiering, and what
the degraded hash mode costs, is in [`../README.md`](../README.md) and
[`../BUILD-CONTRACT.md`](../BUILD-CONTRACT.md).

A context toolkit that needs an install step has a failure mode worse than being wrong: it is
absent. The moment it will not run is the moment someone is trying it on an unfamiliar machine,
which is the only moment it had to work. Zero dependencies is a correctness property, not a
brag.

The rule that decides what becomes a script and what stays an instruction: **if a machine can
check it, a machine must check it, and a skill may never assert a fact a script could have
verified.** Byte counts, missing sections, name mismatches, dead links and drifted indexes are
script work. Whether a rule book is missing a rule is not.

---

## What is owed to whom

- **Jake Van Clief and David McDermott**, Model Workspace Protocol: the five-layer model, the
  stage contract, the fifteen conventions, and the `{{PLACEHOLDER}}` onboarding system. This
  toolkit implements and extends that methodology.
- **Yuhan Lei**, karpathy-llm-wiki: the `raw/` and `wiki/` architecture, the grounding
  invariant, the three-tier lint authority model, and the evidence verifier vendored into
  `scripts/`.
- **Andrej Karpathy**: the underlying idea that the model writes and maintains the wiki while
  the human reads and asks questions of it, and that the wiki is a compounding artifact. Idea
  credit, not a licence obligation. The KAP in this toolkit's name is for Karpathy.
- **Kevin Nguyen**, icm-template: the conversational scaffolder, the setup interview and the
  sync and gap-fill loops.

Full licence texts and per-file provenance are in [`../NOTICE.md`](../NOTICE.md). Cite the
authors and the repositories. Do not cite an institution for the paper: an affiliation claim
circulating downstream could not be verified against the paper itself, so
[`../NOTICE.md`](../NOTICE.md) deliberately omits one and so does this document.
