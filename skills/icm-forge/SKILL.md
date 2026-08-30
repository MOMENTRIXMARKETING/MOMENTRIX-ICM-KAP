---
name: icm-forge
description: "This skill should be used when the user asks to 'run the forge', 'what are we getting wrong', 'do the weekly review', 'read the ledger for patterns', 'show the proposals', or 'approve that proposal'. Reads _log/LOOP-LEDGER.md, finds the rule books that keep missing, and writes the smallest edit that would have prevented each miss to _log/FORGE-PROPOSALS.md. It proposes. The human approves. It never edits a rule book on its own."
user-invocable: true
argument-hint: "run | show | approve"
---

# ICM Forge

The weekly pass that turns a ledger of misses into a short list of rule book edits.

`icm-log` records. The forge diagnoses. The human decides. Those are three jobs and they stay in three places, because a system that records its own misses, judges them, and then rewrites its own rules has closed the loop on itself and will optimise the record instead of the work.

This skill runs no toolkit script. Every count below is a shell command you run yourself, and every proposal is your reading of the result. Nothing in `scripts/` reads the ledger, reads the proposals file, or stands between you and a `_config/` file. The separation holds because you hold it.

## Resolve the toolkit first

The ledger and proposals paths, and the authority model, live in the toolkit. Resolve the root once before reading either.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

Ledger: the `log.ledger` key in `$ICM_HOME/icm.defaults.json`. Proposals: `log.forge_proposals` in the same file. Both are relative to the user's workspace root. Ledger line formats are defined in `references/ledger.md` of the **out-of-the-loop** skill and the forge reads them, it does not redefine them.

## THE FORGE NEVER EDITS A RULE BOOK

Not in `run`. Not when the evidence is overwhelming. Not when the fix is one word. Not when the user is busy and it would obviously help.

In `run` mode the forge's only write targets are `_log/FORGE-PROPOSALS.md` and the weekly review block appended to the ledger. Nothing in `_config/`, nothing in any `references/` folder, nothing in any job card.

The toolkit's own rule, from `$ICM_HOME/spec/CLI-CONTRACT.md`: a script may create a rule book that does not exist, once, as part of an install; no script and no agent ever edits a rule book that exists. `approve` is the one place that rule bends, and it bends only because a human in the turn named a proposal by id.

## Evidence only

**A proposal with no ledger line behind it is not a proposal.**

Every proposal quotes the ledger lines that justify it, verbatim, pasted into the proposal body. If you cannot paste at least two lines, you do not have a hole. You have a note, and a note is not written to the proposals file.

You may not propose from memory of the session. You may not propose from something the user mentioned in passing. You may not propose an improvement you happen to think is good. The ledger is the entire input. If a real problem has never been logged, the correct output is "not in the ledger" and the correct next action is `/icm-log miss`.

---

## Mode: run

### Step 1. Read the ledger

```sh
[ -f _log/LOOP-LEDGER.md ] || { echo "no ledger yet, nothing to forge"; exit 0; }
```

No ledger, no run. Do not create one. Do not synthesise one from the conversation.

### Step 2. Count the misses by rule book

```sh
grep '| Miss |' _log/LOOP-LEDGER.md \
  | awk -F'|' '{ gsub(/^ +| +$/, "", $4); print $4 }' \
  | sort | uniq -c | sort -rn
```

The literal `Miss` marker in column two is what separates a miss line from a call line, which has the same column count. Column four is the rule book.

Before you count a path as one book, confirm it exists on disk. The five rule book filenames are in `$ICM_HOME/spec/CLI-CONTRACT.md` section 8, and a stage may add its own under `references/`. Two spellings of one book, or a path to a book nobody ever created, split a count in half and hide a hole.

### Step 3. Name the holes

Two kinds, and they get different proposals:

**A hole in an existing rule book.** The same rule book path appears on two or more miss lines. The book exists, it was loaded, and it did not catch this. Two is the threshold: once is a bad day, twice is the rule book being wrong or silent about something.

**A missing rule book.** The word `none` appears on two or more miss lines *about the same subject*. Nobody could have caught these, because no book covers the ground. Read the "what missed" column across all the `none` lines and group them by subject before you count. Two `none` lines about unrelated things are two bad days, not a missing book.

Anything under the threshold is not written up. Say the count out loud so the user can see what is one line short, and leave it in the ledger to mature.

### Step 4. Write the smallest edit

For each hole, the proposal is **the smallest edit that would have prevented the miss**, and nothing larger.

The ladder, cheapest first. Take the first rung that works:

1. One sentence added to a rule that already exists.
2. One clause tightened in a rule that is already there but too loose.
3. One example added underneath an existing rule, when the rule was right and unrecognisable in practice.
4. One new rule in an existing rule book.
5. A new rule book. Only when no existing book could plausibly hold the rule.

A rewrite of a section is not on the ladder. If your proposal is a rewrite, you have not found the hole yet, you have found that you would have written the book differently. Go back to the ledger lines and ask what single sentence would have changed the outcome.

Then test it against the evidence: read each cited miss line and confirm this exact edit would have caught it. If it would only have caught one of the two, it is not the fix for this hole. Say so and propose nothing.

### Step 5. Write the proposals

Append to `_log/FORGE-PROPOSALS.md`, creating it with a heading if it does not exist. One block per hole:

```
## FP-2026-08-30-01 | _config/voice.md
- Status: proposed
- Hole: the em dash ban reads as prose-only, so deck copy keeps shipping with them
- Evidence:
  | 2026-08-14 | Miss | _config/voice.md | shipped an em dash in deck copy | ban the em dash in deck copy too |
  | 2026-08-27 | Miss | _config/voice.md | em dash in a slide subhead | say it covers slides |
- Rung: 2 (tighten an existing clause)
- Where: _config/voice.md, section "Punctuation", the sentence beginning "No em dashes in prose"
- Smallest edit: change "No em dashes in prose." to "No em dashes anywhere, prose or deck copy or slide furniture."
- Would have prevented: both cited lines
```

The Evidence block is pasted, not paraphrased. The Smallest edit line carries the exact replacement text, not a description of it, so `approve` has something unambiguous to apply.

Ids run `FP-<date>-NN`, numbered within the day.

Once a proposal block is written, its body is never edited again. The `Status` line is the only line the forge ever changes, and only in `approve` mode.

### Step 6. Append the weekly review block

To the ledger, in the format `references/ledger.md` defines:

```
Week of: <date>
Calls fired: <n> Necessary: <n>
Pre-mortem catches: <n> Hunt catches: <n> Review catches: <n> Audit catches: <n>
Workarounds taken: <n> Recurring blocker: <none, or the blocker and the proposed system fix>
Anchor decay check: <pass or what drifted>
Floor misses: <n tasks with more process lines than output>
Threshold proposals: <none, or the proposal and the operator's decision>
```

Counts come from the ledger, not from recollection. Task lines carry the four hole counts as `plan/hunt/review/audit` in the Holes column:

```sh
awk -F'|' 'NF==11 { split($7, h, "/"); p+=h[1]; u+=h[2]; r+=h[3]; a+=h[4]; w+=$8 } \
  END { print "plan " p+0, "hunt " u+0, "review " r+0, "audit " a+0, "workarounds " w+0 }' \
  _log/LOOP-LEDGER.md
```

The trendline to watch, and to say out loud: review and audit catches falling while pre-mortem and hunt catches hold. That is holes dying earlier, where they are cheapest. Review catches rising means the hunt questions have gone stale, and the proposal for that is an update to the hunt questions with the pattern that slipped through.

A blocker in the workaround column of two different task lines is a system hole. Propose the fix once, as its own task, and stop paying the weekly toll.

### Step 7. The "was the call necessary" column

Call lines close with that column blank on purpose. It is filled at the weekly review, and it is filled from the human's answer.

List every call line whose last column is empty and ask, one line each: did you change anything because of this call? Write only what you are told. If nobody answers, leave every one of them blank and note it in the report. A blank is correct data. A guess is corrupt data, and a corrupt necessity count is how a trigger gets loosened by mistake.

### Step 8. Threshold proposals

If a trigger's calls came back approved unchanged 90 percent of the time or more across at least ten firings, propose loosening it. If a breach got through with no call, propose tightening it.

A threshold change is a proposal, written into `_log/FORGE-PROPOSALS.md` like any other, and it is never applied silently. The optimiser does not get to touch its own leash. That rule is the one part of the loop that never self-tunes.

---

## Mode: show

Read only. Writes nothing.

Print, in this order:

- Proposals with `Status: proposed`, oldest first, id and rule book and the one-line hole.
- Proposals approved since the last run, with their date.
- Proposals rejected, with the reason, so the same hole is not written up again next week.
- Rule books at one miss: the ones a single line away from becoming a hole.

```sh
grep -n '^## FP-' _log/FORGE-PROPOSALS.md
grep -n '^- Status:' _log/FORGE-PROPOSALS.md
```

No proposals file: say "no proposals yet, run /icm-forge run" and stop.

---

## Mode: approve

The only mode in which a rule book changes, and it changes because a human in this turn said which proposal to apply.

1. **Require an id.** "Approve the voice one" is not an id if two proposals name that book. Ask which. Silence approves nothing. An unattended session approves nothing.
2. **Re-read the proposal block** from `_log/FORGE-PROPOSALS.md`. Apply what is written there, not what you remember writing.
3. **Show the exact before and after** on the target rule book: the current line and the replacement line. Then apply it.
4. **Surgical edit only.** Change the named lines and nothing else. Reflow nothing. Reword nothing nearby. If the proposal cannot be applied as a targeted edit, write the whole candidate file to `.icm/proposed/<same-relative-path>` and stop. Never rewrite a rule book wholesale. `icm-apply.sh` writes a `.diff` beside a candidate it parks, but you are parking this one by hand, so write the diff yourself with `diff -u` and show it.
5. **Stamp the proposal.** Rewrite its Status line only:

```
- Status: approved 2026-08-30
```

Or, when the human says no:

```
- Status: rejected 2026-08-30, deck copy is deliberately looser than prose
```

A rejection reason is not optional. It is what stops next week's forge writing the same proposal again.

6. **Re-check the workspace.** A rule book that grew a paragraph can cross its budget ceiling, so confirm the edit did not break the workspace:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --budgets --fences --placeholders .
```

Exit 0 clean, 1 findings, 2 usage or environment error. `--only <id>` selects one check by its id, and is the same thing as passing that check's own flag.

7. **Log the change.** One line to the ledger recording that the rule book moved, so the next forge run can tell a book that was fixed from a book that has always been wrong.

---

## The cron

The weekly run is a scheduled task, created with Claude Code's `/schedule`.

- **Cadence:** weekly. The threshold is two misses, and two misses take about a week to accumulate. Daily runs mostly report nothing and train you to skip the output.
- **The routine's prompt is exactly `/icm-forge run`.** Nothing else.
- **The cron only runs the forge.** It never runs `approve`. It cannot: there is no human in a scheduled turn, and approval is defined as a human in the turn saying an id out loud. A scheduled run that finds five holes writes five proposals and stops.
- **Mark the origin.** Proposals from an unattended run are written `Status: proposed (unattended run)`, so nobody later reads silence as consent.
- **Leave the necessity column blank** on an unattended run, and say in the report that it was skipped.
- **The output is a queue, not a decision.** You read it when you sit down, with `/icm-forge show`, and act on it with `/icm-forge approve`.

Approval stays with the human whether the run was scheduled or typed. The schedule changes when the forge looks. It changes nothing about who decides.

---

## Refusals

- No editing a rule book in `run` mode, under any circumstances.
- No proposal without at least two ledger lines pasted into it.
- No proposal built from the conversation instead of the ledger.
- No approving in an unattended run.
- No approving a proposal the human did not name by id.
- No rewriting a rule book wholesale. Targeted edit, or `.icm/proposed/`.
- No editing a proposal body after it is written. The Status line only.
- No filling the necessity column with a guess.
- No writing to the ledger except the weekly review block and the rule-book-changed line.

## What is machine enforced and what is judgment

Authority model: `$ICM_HOME/spec/authority-model.md`.

**Machine-enforced by a toolkit script: almost nothing here.** Nothing in `scripts/` reads `_log/LOOP-LEDGER.md` or `_log/FORGE-PROPOSALS.md`. No script counts a miss, tests a threshold, or refuses an edit to a rule book. The only script this skill runs is `icm-check.sh` at step 6 of `approve`, and it verifies the workspace after the edit, not the edit itself:

| Check | check-id | What it verifies after an approved edit |
|---|---|---|
| Character budgets | `budgets` | The edited rule book is still inside the `rulebook.md` ceiling in `icm.defaults.json` |
| Code fences | `fences` | The edit left the file's backtick and tilde fence counts even |
| Placeholders | `placeholders` | The edit did not introduce an unfilled double-brace placeholder in live prose |

**Counted by you, then reported.** These are shell commands you run. They are deterministic, they invent nothing, and no script runs any of them for you. Say that you ran them.

| Count | How you run it |
|---|---|
| Miss count per rule book | `grep` for the Miss marker, `awk` on column four, `uniq -c` |
| The two-miss threshold | integer comparison on that count |
| Hole counts summed across task lines | `awk` splitting the Holes column on the slash |
| Workaround count and recurring blockers | `awk` on the Workarounds column |
| Call lines with an empty necessity column | `grep` for a trailing empty cell |
| Proposal ids are unique and sequential within the day | `grep` on the FP heading |

Counting is mechanical and needs no permission. Everything the count is *used for* below is not.

**Mechanical report, found by a count, never acted on alone**

| Finding | Why it is not acted on |
|---|---|
| A rule book at two or more misses | The count is a fact. The hole is a diagnosis |
| Two or more `none` lines | Whether they share a subject is a reading, not a count |
| A blocker in two different task lines | The system fix is a design decision and its own task |
| A trigger approved unchanged past the threshold | Loosening a leash is always the human's call |
| A ledger line that matches no known format | Repairing it would edit history |

**Judgment, yours, and always a proposal**

- Whether a set of miss lines is one hole or two.
- Whether `none` lines share a subject.
- Which rung of the ladder the fix sits on.
- The exact wording of the smallest edit.
- Where in the rule book it belongs.
- Whether a new rule book is warranted, or whether an existing one can hold it.
- Whether a proposal genuinely would have prevented every miss it cites.

**Enforced by nothing but this file:** that the forge does not edit rule books, and that approval requires a human in the turn. No script stands between you and a `_config/` file. That separation holds because you hold it.
