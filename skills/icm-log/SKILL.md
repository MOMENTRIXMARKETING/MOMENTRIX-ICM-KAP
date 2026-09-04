---
name: icm-log
description: "This skill should be used when the user says 'log that', 'log a miss', 'that was wrong', 'the rule book should have caught that', 'log the use', 'close this task', 'write the ledger line', or 'show me the ledger', and by every Session Close in a workspace the toolkit built. Records one miss in ten seconds with a severity, writes the use line for the skill or job card a task ran under, writes the task line and call lines at close, and prints the ledger. It records what happened and never diagnoses it."
user-invocable: true
argument-hint: "miss | use | close | show"
---

# ICM Log

The recorder for the loop. It writes to `_log/LOOP-LEDGER.md` in the user's workspace and it reads it back. That is the whole job.

The ledger is the file that makes the loop self-learning instead of self-referential. Without it, next month's judgment is this month's guess. Two owners of shape, and no third. The task line, the call line and the weekly review block are defined in `references/ledger.md` of the **out-of-the-loop** skill and used unchanged. The miss line, the use line and the patched line are defined here, in this file, and nowhere else: out-of-the-loop has no miss shape, and every earlier attempt to have one produced three private formats that no forge could count. None of the six is extended casually. `icm-forge` and `scripts/icm-loop.sh` read this file with `grep` and `awk`, so a line in a private format is a line that will never be counted.

This skill runs one toolkit script, `icm-loop.sh`, and only in `show` mode, to print the index. Everything else is an append with `printf` and a read with `grep`, `awk` and `tail`. Nothing an append does is verified by a machine at write time, which is exactly why the format discipline below is written out in full.

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

Ledger path: the `log.ledger` key in `$ICM_HOME/icm.defaults.json`. Run log path: `log.runlog`. Index path: `log.skill_index`. All relative to the user's workspace root, not to the toolkit.

## THE LOGGER NEVER JUDGES

This is the one rule the whole skill exists to hold.

You record what happened. You do not diagnose why. You do not decide whether it is a pattern. You do not open the rule book. You do not propose an edit. You do not soften what the user said and you do not sharpen it either.

Diagnosis belongs to `icm-forge`, and it only earns the right to diagnose because the ledger it reads is uncontaminated. A logger that pre-judges is a logger that filters, and a filtered ledger tells the forge what the logger already believed.

If the user says something that sounds like a fix, write it in the fix column verbatim and move on. If they say something that sounds like a theory, that is not a miss line, and the honest answer is "logged the miss, the pattern is the forge's call".

## Append only

Never rewrite a line. Never reorder. Never delete. Never tidy. A wrong line gets a new line underneath it that says so, dated. History that can be edited is not evidence.

Every write is `>>`. Every line of every kind lands at the end of the file, under the `## Lines` heading, in time order. The sections above it are shapes, not places. Create the file if it is missing and never in any other circumstance touch what is already in it:

```sh
mkdir -p _log
[ -f _log/LOOP-LEDGER.md ] || printf '# LOOP LEDGER\n\nAppend only. Never rewrite a line.\n\n## Lines\n\n' > _log/LOOP-LEDGER.md
```

A ledger the toolkit installed already has every section. A ledger created by this fallback has the one that matters.

---

## Mode: miss

Ten seconds. Four answers. One line. Then stop.

Ask, in one message, and accept short answers:

1. **What is at fault?** A path: a rule book (`_config/voice.md`), a job card (`sales/02-follow-up/CONTEXT.md`) or a skill (`skills/icm-context/SKILL.md`). Never a person, never the task. If nothing on disk covers it, the answer is the literal word `none`, and `none` is the answer the placement question needs.
2. **How bad?** Sev 3: wrong output shipped, or a decision made on bad information. Sev 2: cost time. Sev 1: cosmetic. Unsure: 2.
3. **What missed?** One phrase naming the mechanism. "Flex container stretched the img" counts. "Logo looked off" does not, and is not written.
4. **What would the fix have been?** One phrase, in the user's words. If they do not know, write `unknown`.

If the user already said all four, ask nothing. Write the line. If the Session Close is what called this mode, there is no user to ask: the agent answers all four from the run and writes the line.

Write the path exactly as it exists on disk in that workspace. The five rule book filenames are `_config/conventions.md`, `_config/glossary.md`, `_config/voice.md`, `_config/style.md` and `_config/grounding.md`, per `$ICM_HOME/spec/CLI-CONTRACT.md` section 8, and a stage may add its own under `references/`. The forge and the index count on this column matching a real path; a path that is not on disk is reported as a ghost. Record the path that is there rather than the one you expected.

**Grep before you write.** The same fault on the same path, already in the file and not yet followed by a `Patched` line for that path, is not written twice: the forge already has it. The same fault returning after a `Patched` line is written again, and What missed starts with the literal `RECURRENCE:`. That is the strongest signal in the file: it says the last fix was wrong at the concept level, and two of them make the index say `rewrite`.

```sh
grep -F "| Miss |" _log/LOOP-LEDGER.md | grep -F "| $BOOK |"
grep -F "| Patched | $BOOK |" _log/LOOP-LEDGER.md | tail -n 1
```

The line:

```
| Date | Miss | Sev | At fault | What missed | Fix that would have prevented it |
```

Example:

```
| 2026-08-30 | Miss | 2 | _config/voice.md | shipped an em dash in deck copy | ban the em dash in deck copy, not just in prose |
```

The literal word `Miss` in column two is the selector. `icm-forge` and `icm-loop.sh` find every miss with one grep, so it goes in every time, spelled exactly like that. Sev is one digit. The At fault column holds a path or the word `none`, nothing else, because that column is what gets counted.

Write it:

```sh
printf '| %s | Miss | %s | %s | %s | %s |\n' "$(date +%Y-%m-%d)" "$SEV" "$BOOK" "$WHAT" "$FIX" >> _log/LOOP-LEDGER.md
```

Keep pipes out of the free-text columns. Keep each column to one phrase. A miss line that runs to a paragraph is a miss line nobody will ever count.

Then confirm in one line: the file, the path, the sev, and nothing else. No summary. No advice. No "you might want to".

---

## Mode: use

One line per skill or job card a task ran under, written at Session Close, after the misses and before the task line. This is what the index counts, so a skill that is never logged here looks unused, and a skill that is used every day and never misses looks under-logged rather than perfect.

```
| Date | Use | Skill or job card | Path | Task | Outcome | Misses |
```

- **Skill or job card** is the name: the skill directory name, or the stage folder.
- **Path** is where it lives on disk, relative to the workspace root, the same string a miss line would put in At fault.
- **Task** is the task name the task line will carry.
- **Outcome** is one of `ok`, `rework`, `abandoned`. Rework means a human sent it back at least once. Abandoned means the task closed without its artifact.
- **Misses** is the count of miss lines this run wrote against this path. Zero is a number, write it.

Example:

```
| 2026-08-30 | Use | 02-script | 02-script/CONTEXT.md | bread staling script | rework | 1 |
```

Write it:

```sh
printf '| %s | Use | %s | %s | %s | %s | %s |\n' "$(date +%Y-%m-%d)" "$NAME" "$BOOK" "$TASK" "$OUTCOME" "$MISSES" >> _log/LOOP-LEDGER.md
```

A task that ran under nothing, no skill and no job card, writes no use line. That silence is data too: the index will show the folder as unlogged, and a folder that does work with no job card is a placement question.

### The patched line

Not written by this mode and not written by the user. `icm-forge approve` writes it, once per approved proposal, so the index can tell a file that was fixed from a file that has always been wrong:

```
| Date | Patched | Path | Proposal id |
```

Every miss against that path dated on or before the patched line counts as closed. Every miss after it is open again, and a `RECURRENCE:` after it is the fix failing. The shape is recorded here because this skill owns the line shapes, and it is listed so that nobody invents a second way to say "fixed".

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
| 2026-08-10 | Acme outreach batch 03 | 3 | Cash | 1 | 1/2/1/0 | 1 (API limit, batched sends) | T5 (approved default) | batch-03.md |
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

**Miss counts by path**, highest first, because that is the number that decides whether the forge has a hole to work with. Column five is the path now that column four is Sev:

```sh
grep '| Miss |' _log/LOOP-LEDGER.md | awk -F'|' '{ gsub(/^ +| +$/, "", $5); print $5 }' | sort | uniq -c | sort -rn
```

**The index**, which is the same count with the kill rules applied, one row per skill, job card and rule book on disk. It is read-only from this skill's point of view: the script writes `_log/SKILL-INDEX.md` and nothing else, and every verdict in it is a mechanical report a reader can redo with the grep above:

```sh
sh "$ICM_HOME/scripts/icm-loop.sh" .
```

Exit 0 nothing waiting, 1 a verdict or the starvation check is waiting on a human, 2 no ledger. The flags are `--index` (the default), `--starve`, `--block` and `--today DATE`. In `show` mode you run `--index` or nothing.

**Open calls**, the ones whose necessary column is still blank. A blank last column shows up as two pipes with nothing but spaces between them at end of line:

```sh
grep -c '| *|$' _log/LOOP-LEDGER.md
```

Then say, in one line, which paths the index marked `hole`, `rewrite`, `uncovered`, `ghost`, `archive` or `check-write-back`, and whether the starvation line says the write back is firing. Say only the verdict words and the counts. Do not say what they mean and do not propose anything. "`_config/voice.md` hole at 2, `_config/style.md` rewrite, write back firing" is the whole output. `/icm-forge run` is where it goes next.

---

## Refusals

- No writing in `show` mode, other than the index the script rewrites, which is a compiled artifact and not a record.
- No use line for a skill or job card the task did not actually run under. The index is only as honest as this column.
- No rewriting, reordering or deleting an existing ledger line, in any mode, for any reason.
- No closing a task whose DOD lines do not each name an artifact.
- No filling the "was the call necessary" column at close.
- No inventing a path. If the user does not name one, the column is `none`, and `none` is a real answer that the forge and the placement question need.
- No writing a `Patched` line from this skill. That line belongs to `icm-forge approve`.
- No second miss line for a fault already open on the same path. Grep first.
- No diagnosis, in any mode. Not even a helpful one.

## What is machine enforced and what is judgment

Authority model: `$ICM_HOME/spec/authority-model.md`.

**Machine-enforced by a toolkit script: the count, not the write.** `scripts/icm-check.sh` has no ledger check, no format check and no append check. `scripts/icm-loop.sh` reads the ledger and counts it, and a line in the wrong shape is a line it silently does not count, which is enforcement after the fact: the index will show a skill you know you used as unlogged, and that is the signal the shape was wrong. Say that plainly rather than implying a machine is watching the record as it is written.

Two indirect checks worth knowing: `icm-check.sh --fences` reads every `.md` under the workspace, so an unbalanced code fence pasted into the ledger will show up in a workspace check, and `icm-check.sh --sections` requires the ledger's section headings on a ledger the toolkit installed.

**Safe fix, applied by you, then reported.** These are shell commands you run and edits you make. No script applies any of them, and none of them is silent: you say what you did.

| Check | How you run it |
|---|---|
| `_log/` exists and the ledger has its heading | `[ -f ]` then `printf >` on the missing case only |
| Every write is an append | `>>`, never `>`, on an existing file |
| Date format is `YYYY-MM-DD` | `date +%Y-%m-%d` |
| Column count on a miss line, a use line, a task line and a call line | `awk` splitting on the pipe, field count against the format above |
| The literal `Miss` or `Use` marker is present in column two | `grep` for the selector |
| Sev is one digit, 1 to 3 | `case` on the value before the `printf` |
| The same fault is not already open on the same path | `grep` for the path in Miss lines, then for a later Patched line |

**Mechanical report, found by a check, never fixed**

| Check | Why it is not fixed |
|---|---|
| A line whose column count does not match any known format | Guessing which column is missing rewrites history |
| A pipe character inside a free-text column | The fix is the user's wording, not yours |
| A task line closed with no artifact filename | Only the human knows whether the artifact exists |
| Miss count per path, and every verdict word in the index | Counting is mechanical. What the count *means* is the forge's job, and the forge's alone |

**Judgment, and it is the user's, not yours**

- Which file should have caught it.
- How bad it was.
- What the fix would have been.
- Whether something is a miss at all.
- Whether a task ran under a skill or a job card, and how it came out.

You transcribe those answers. You do not supply them, correct them, or improve them. When the Session Close calls this skill with no human in the turn, the agent that did the work answers, and answers about its own run only. The ledger is worth exactly as much as it is unedited.
