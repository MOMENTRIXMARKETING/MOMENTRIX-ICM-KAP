# The architect pattern

Folders as agents. Why an org chart made of directories outlives the model that read it last.

This is the human page. [`../spec/CONVENTIONS.md`](../spec/CONVENTIONS.md) holds Pattern 24
itself and is authoritative for every rule below. A worked tree is in
[`../examples/architect-company/`](../examples/architect-company/).

---

## The claim

**The folders are the agents.** An agent is spawned into a folder, reads what that folder names,
does the job, writes its report, and dies. Agents are ephemeral. Reports are files.

**Nobody sits above the folders.** There is no orchestrator process, no supervisor object, no
long-lived session that has to stay alive for the system to make sense. The lead architect is
whichever model opens the top folder next.

That is Pattern 17's recursion carried to its conclusion. Recursion says a department repeats the
workspace pattern inside itself. This pattern says the same thing about who does the work: the
department is the worker, the folder is the address, and the agent is the short-lived thing that
shows up at it.

---

## Why it survives a model swap

Swap the model and ask what was lost.

In the usual arrangement the answer is most of it. The routing lives in an orchestrator, the
reasoning lives in a prompt string tuned to one vendor's behaviour, and the decisions live in a
conversation somebody had to be present for. A new model inherits an API and none of the
context. So does the same model tomorrow, after the session ends.

Here the answer is nothing. Everything load bearing is a file:

| What usually lives in the process | Where it lives here |
|---|---|
| Who works on what | The folder names, and each folder's job card |
| What the rules are | `_config/` rule books, read by whoever walks in |
| What happened | `reports/`, one file per run, append only |
| What state we are in | The folder itself, with `status.md` as an index of it |
| Who is in charge | Whoever opened the top folder, this minute |

So the handover is the filesystem. There is no appointment and no handover meeting, and there is
nothing to transfer, because nothing was ever held anywhere else. Any model, any vendor, any
day, reads `IDENTITY.md`, `CONTEXT.md`, `ARCHITECT.md` and `status.md` and is the lead architect.

The same property answers the failure question. Kill any agent at any moment and the workspace
is unharmed, because the agent was never where the state lived. There is no single process that
must stay up, which means there is no single process whose death loses the business.

It also means a non-programmer can audit the structure. An org chart in code is a thing you have
to run to read. An org chart in folders is a thing you can open.

---

## The five rules

Stated in full in [`../spec/CONVENTIONS.md`](../spec/CONVENTIONS.md), Pattern 24.

1. **Agents are ephemeral, reports are files.** A worker's last act is writing its report and its
   one status line. Nothing else it holds survives. A worker that finished the job and wrote
   nothing did not finish the job.
2. **The architect reads reports, not conversations.** Not transcripts, not scrollback, not what
   it remembers deciding. Reports are the interface between a dead agent and a live one.
3. **Messages coordinate, files record.** Messages are allowed and useful, and they decide
   nothing. No decision is real until it is written in the folder.
4. **The architect never does department work, except below the small task floor.** Under the
   floor, spawning an agent costs more than the task does, so the architect does it and logs that
   it did. Above the floor it spawns and stays out of the way.
5. **Any model that opens the top folder and reads the four files is the lead architect.** No
   appointment, no handover meeting, no state to transfer.

---

## The four corrections

The rules above are the easy half. Each of these four is a place where the obvious version of
the idea is wrong, and each one is load bearing.

**1. `ARCHITECT.md` is a layer 2 job card, not a new layer.** The stack is 0, 1, 2, 3, 4a, 4b and
it does not grow. `ARCHITECT.md` holds the job of the folder it sits in, in exactly the shape any
job card takes: read the rollup, decide who works today, spawn agents into departments, do not do
the work yourself. Calling it a new layer would add a number to a stack that
[`../spec/layers.md`](../spec/layers.md) closes, and every budget and every routing rule counts
on that stack being fixed.

**2. `status.md` is compiled, and never authoritative.** It is layer 4b. Workers write their one
line into it, the architect reads it to decide where to look, and that is the whole of its job.
**If `status.md` disagrees with the folder, the folder wins.** A rollup is an index, and an index
that contradicts the thing it indexes is a stale index, never a correction to it. Treat the
summary as the truth and you have rebuilt the thing this pattern exists to avoid: a state file
that the real work has to be kept in sync with.

**3. Reports are append only, and `report.md` is a pointer.** Reports land at
`reports/YYYY-MM-DD-slug.md`, one file per run. `report.md` holds a pointer at the newest one and
nothing else. Writing every worker's output over a single `report.md` breaks two patterns at
once: Pattern 19, because the second worker overwrites the first worker's file, and Pattern 22,
because the record stops being append only and becomes a snapshot of whoever ran last. A wrong
report is corrected by a new report, never by an edit.

**4. The small task floor is written down, not judged fresh.** Rule 4 has an exception in it, and
an exception decided case by case is not a rule, it is a preference. Each workspace states its
own floor, in words, in its root `_config/conventions.md`. Then "was this below the floor" is a
question anyone can answer the same way twice, and the architect logs that it did the work
itself rather than quietly absorbing a department's job.

---

## How you build one

`architect` is a workspace **shape**, not a fourth install manifest.
`icm-plan.sh --archetype` takes `quick`, `full` and `wiki` only. You install `full` at the root,
then add one department at a time with `/icm-context` and `/icm-stage add`, and each department
repeats the pattern inside itself.

Start with one department. A tree with one real department and honest reports beats a tree with
six empty ones, and the structure is meant to grow with use rather than ahead of it.

The shape, the file bodies and a walkthrough of one run are in
[`../examples/architect-company/`](../examples/architect-company/).
