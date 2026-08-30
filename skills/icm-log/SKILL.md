---
name: icm-log
description: "This skill should be used when the user says 'log that', 'log a miss', 'that was wrong', 'the rule book should have caught that', 'close this task', 'write the ledger line', or 'show me the ledger'. Records one miss in ten seconds, writes the task line and call lines at close, and prints the ledger. It records what happened and never diagnoses it."
user-invocable: true
argument-hint: "miss | close | show"
---

# ICM Log

The recorder for the loop. It writes to `_log/LOOP-LEDGER.md` in the user's workspace and it reads it back. That is the whole job.

The ledger is the file that makes the loop self-learning instead of self-referential. Without it, next month's judgment is this month's guess. The formats here are the ones defined in `references/ledger.md` of the **out-of-the-loop** skill. They are not negotiable and they are not extended casually: `icm-forge` reads this file with `grep`, so a line in a private format is a line that will never be counted.

This skill runs no toolkit script. It appends to one file with `printf` and reads it back with `grep`, `awk` and `tail`. Nothing here is verified by a machine, which is exactly why the format discipline below is written out in full.

## Resolve the toolkit first

The ledger path and the authority model live in the toolkit, not in the workspace. Resolve the root once before reading either.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

Ledger path: the `log.ledger` key in `$ICM_HOME/icm.defaults.json`. Run log path: `log.runlog` in the same file. Both are relative to the user's workspace root, not to the toolkit.

## THE LOGGER NEVER JUDGES

This is the one rule the whole skill exists to hold.

You record what happened. You do not diagnose why. You do not decide whether it is a pattern. You do not open the rule book. You do not propose an edit. You do not soften what the user said and you do not sharpen it either.

Diagnosis belongs to `icm-forge`, and it only earns the right to diagnose because the ledger it reads is uncontaminated. A logger that pre-judges is a logger that filters, and a filtered ledger tells the forge what the logger already believed.

If the user says something that sounds like a fix, write it in the fix column verbatim and move on. If they say something that sounds like a theory, that is not a miss line, and the honest answer is "logged the miss, the pattern is the forge's call".

## Append only

Never rewrite a line. Never reorder. Never delete. Never tidy. A wrong line gets a new line underneath it that says so, dated. History that can be edited is not evidence.

Every write is `>>`. Create the file if it is missing and never in any other circumstance touch what is already in it:

```sh
mkdir -p _log
[ -f _log/LOOP-LEDGER.md ] || printf '# LOOP LEDGER\n\nAppend only. Never rewrite a line.\n\n' > _log/LOOP-LEDGER.md
```

---

## Mode: miss

Ten seconds. Three answers. One line. Then stop.

Ask, in one message, and accept short answers:

1. **Which rule book?** The path, `_config/voice.md` or `stages/02-spec/references/spec-format.md`. If no rule book covers it, the answer is the literal word `none`.
2. **What missed?** One phrase. What actually happened, not what it means.
3. **What would the fix have been?** One phrase, in the user's words. If they do not know, write `unknown`.

If the user already said all three in their message, ask nothing. Write the line.

Write the rule book path exactly as it exists on disk in that workspace. The five rule book filenames are `_config/conventions.md`, `_config/glossary.md`, `_config/voice.md`, `_config/style.md` and `_config/grounding.md`, per `$ICM_HOME/spec/CLI-CONTRACT.md` section 8, and a stage may add its own under `references/`. The forge counts on this column matching a real path, so record the path that is there rather than the one you expected.

The line:

```
| Date | Miss | Rule book | What missed | Fix that would have prevented it |
```

Example:

```
| 2026-08-30 | Miss | _config/voice.md | shipped an em dash in deck copy | ban the em dash in deck copy, not just in prose |
```

The literal word `Miss` in column two is the selector. `icm-forge` finds every miss with one grep, so it goes in every time, spelled exactly like that. The rule book column holds a path or the word `none`, nothing else, because that column is what the forge counts.

Write it:

```sh
printf '| %s | Miss | %s | %s | %s |\n' "$(date +%Y-%m-%d)" "$BOOK" "$WHAT" "$FIX" >> _log/LOOP-LEDGER.md
```

Keep pipes out of the free-text columns. Keep each column to one phrase. A miss line that runs to a paragraph is a miss line nobody will ever count.

Then confirm in one line: the file, the rule book, and nothing else. No summary. No advice. No "you might want to".

---

## Mode: close

A task closes with one task line, plus one call line for every call it fired.

**Evidence closure first.** Nothing closes on assertion. Walk the DOD line by line and name the artifact for each one: a file, a diff, a link, a number. A DOD line with no artifact means the task is still open, and the correct action is to say so and write nothing.

### The task line

```
| Date | Task | Tier | Anchor | Verify cycles | Holes: plan/hunt/review/audit | Workarounds | Call fired | Artifact |
```

Example:

```
| 2026-08-10 | MCK outreach batch 03 | 3 | Cash | 1 | 1/2/1/0 | 1 (API limit, batched sends) | T5 (approved default) | batch-03.md |
```

Column by column:

- **Tier** is 1 to 4, the action tier the task ran at.
- **Anchor** is the one anchor the task moved: cash, customer result, date, or whatever the operator defined.
- **Verify cycles** is how many times review sent it back. Zero is a number, write it.
- **Holes** is four counts separated by slashes, in order: plan, hunt, review, audit. No spaces.
- **Workarounds** is a count, then the blocker and the route taken in brackets. `0` when there were none.
- **Call fired** is the trigger and its outcome, or `none`.
- **Artifact** is the file the task produced. Not a description of it. The filename.

The task line is the run log compressed. If the task had a run log at `_log/LOOP-RUNLOG-<task>.md`, read it and count from it. Do not count from memory, and do not count from your own context window, which has been compacted at least once by now.

### Call lines

One line per call that fired during the task, appended at close:

```
| Date | Trigger | What fired it | Decision | Was the call necessary (filled at weekly review) |
```

The last column is **left blank**. It is filled at the weekly review by `icm-forge`, from the human's answer, and only then. Necessary means the human changed something because of the call. Do not guess it at close. Do not fill it in because it seems obvious. A blank there is correct data; a guess there is corrupt data.

### Run log lines

Below the small task floor there is no run log and the task line is the whole record. Above it, the run log takes one line per event while the task is running:

```
| Time | Loop | Event | Detail |
```

Loop is which part of the graph wrote it: run, workaround, hunt, review, tier check, call, rollback. These go to `_log/LOOP-RUNLOG-<task>.md`, not to the ledger. The ledger gets the compressed line at close.

---

## Mode: show

Read only. Writes nothing, ever, including the file-creation step. If `_log/LOOP-LEDGER.md` does not exist, say so and stop.

Print three things:

**Recent lines.**

```sh
tail -n 20 _log/LOOP-LEDGER.md
```

**Miss counts by rule book**, highest first, because that is the number that decides whether the forge has a hole to work with:

```sh
grep '| Miss |' _log/LOOP-LEDGER.md | awk -F'|' '{ gsub(/^ +| +$/, "", $4); print $4 }' | sort | uniq -c | sort -rn
```

**Open calls**, the ones whose necessary column is still blank. A blank last column shows up as two pipes with nothing but spaces between them at end of line:

```sh
grep -c '| *|$' _log/LOOP-LEDGER.md
```

Then say, in one line, whether any rule book has reached two misses. Say only the count. Do not say what it means and do not propose anything. "`_config/voice.md` is at 3" is the whole output. `/icm-forge run` is where it goes next.

---

## Refusals

- No writing in `show` mode.
- No rewriting, reordering or deleting an existing ledger line, in any mode, for any reason.
- No closing a task whose DOD lines do not each name an artifact.
- No filling the "was the call necessary" column at close.
- No inventing a rule book path. If the user does not name one, the column is `none`, and `none` is a real answer that the forge needs.
- No diagnosis, in any mode. Not even a helpful one.

## What is machine enforced and what is judgment

Authority model: `$ICM_HOME/spec/authority-model.md`.

**Machine-enforced by a toolkit script: nothing in this skill.** `scripts/icm-check.sh` has no ledger check, no format check and no append check. `_log/LOOP-LEDGER.md` is not in `required_sections` and it is not budgeted. Say that plainly rather than implying a machine is watching the record.

There is one indirect exception worth knowing: `icm-check.sh --fences` reads every `.md` under the workspace, so an unbalanced code fence pasted into the ledger will show up in a workspace check. That is the only way this file ever reaches a script.

**Safe fix, applied by you, then reported.** These are shell commands you run and edits you make. No script applies any of them, and none of them is silent: you say what you did.

| Check | How you run it |
|---|---|
| `_log/` exists and the ledger has its heading | `[ -f ]` then `printf >` on the missing case only |
| Every write is an append | `>>`, never `>`, on an existing file |
| Date format is `YYYY-MM-DD` | `date +%Y-%m-%d` |
| Column count on a miss line, a task line and a call line | `awk` splitting on the pipe, field count against the format above |
| The literal `Miss` marker is present in column two | `grep` for the Miss selector |

**Mechanical report, found by a check, never fixed**

| Check | Why it is not fixed |
|---|---|
| A line whose column count does not match any known format | Guessing which column is missing rewrites history |
| A pipe character inside a free-text column | The fix is the user's wording, not yours |
| A task line closed with no artifact filename | Only the human knows whether the artifact exists |
| Miss count per rule book | Counting is mechanical. What the count *means* is the forge's job, and the forge's alone |

**Judgment, and it is the user's, not yours**

- Which rule book should have caught it.
- What the fix would have been.
- Whether something is a miss at all.

You transcribe those three answers. You do not supply them, correct them, or improve them. The ledger is worth exactly as much as it is unedited.
