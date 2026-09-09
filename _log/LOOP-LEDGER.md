# LOOP LEDGER

Append only. Never rewrite history. A wrong line is corrected by a new line. Every line of every kind goes at the end of the file, under Lines, in time order. The sections above Lines are the shapes, not the places. Task, call and weekly review shapes are fixed by the out-of-the-loop skill. Miss, use and patched shapes are fixed by the toolkit's icm-log skill. Do not invent columns.

## Task lines

One line per closed task.

| Date | Task | Tier | Anchor | Verify cycles | Holes: plan/hunt/review/audit | Workarounds | Call fired | Artifact |
|---|---|---|---|---|---|---|---|---|

## Call lines

One line per call fired. The last column is filled at the weekly review. Necessary means the human changed something because of it.

| Date | Trigger | What fired it | Decision | Was the call necessary |
|---|---|---|---|---|

## Miss lines

One line per miss, at Session Close. The literal word Miss in column two is the selector. Sev is 3 wrong output shipped or a decision made on bad information, 2 cost time, 1 cosmetic, 2 when unsure. At fault is a rule book, job card or skill path as it exists on disk, or the word none. A returning fault after a patch starts What missed with RECURRENCE: and that is the strongest signal in the file.

| Date | Miss | Sev | At fault | What missed | Fix that would have prevented it |
|---|---|---|---|---|---|

## Skill lines

One use line per skill or job card a task ran under, at Session Close. The literal word Use in column two is the selector. Outcome is ok, rework or abandoned. Misses is how many miss lines this run wrote against it. One patched line whenever a human approves a proposal that changes a file; the forge writes it, the index reads it, and every miss dated before it counts as closed.

| Date | Use | Skill or job card | Path | Task | Outcome | Misses |
|---|---|---|---|---|---|---|

| Date | Patched | Path | Proposal id |
|---|---|---|---|

## Weekly review

Appended at each review, one block per week:

Week of, calls fired and how many were necessary, catch counts for pre-mortem, hunt, review and audit, workarounds taken, the recurring blocker if there is one, the anchor decay check, floor misses, and any threshold proposal with the operator's decision.

## Lines

Everything below this heading is the record. Append here. Never edit above it except to fix a shape, and never edit a line below it for any reason.
| 2026-09-04 | Miss | 3 | spec/layers.md | no layer owned the write back, so a generated workspace had no session close and nothing obliged an agent to log a miss | a Session Close section in layer 1, required by icm.defaults.json |
| 2026-09-04 | Miss | 2 | skills/icm-log/SKILL.md | said the miss line shape lived in out-of-the-loop references/ledger.md, which holds no miss shape at all, so three files each defined their own | the toolkit owns the miss, use and patched shapes, the skill says so |
| 2026-09-04 | Miss | 2 | scripts/icm_lib.sh | icm_body_forge_proposals emitted a six column table while icm-forge wrote FP blocks, two shapes for one file | one shape, the block, stated in the body |
| 2026-09-04 | Miss | 2 | scripts/icm_lib.sh | the ledger body had no section for miss lines, so an appended miss landed under Weekly review | Miss lines, Skill lines and a Lines section to append under |
| 2026-09-04 | Miss | 2 | skills/icm-forge/SKILL.md | counted misses with no severity, so one shipped wrong output weighed the same as a cosmetic slip | a Sev column and thresholds in icm.defaults.json |
| 2026-09-04 | Patched | spec/layers.md | commit the-loop-librarian, human edit, no proposal |
| 2026-09-04 | Patched | skills/icm-log/SKILL.md | commit the-loop-librarian, human edit, no proposal |
| 2026-09-04 | Patched | scripts/icm_lib.sh | commit the-loop-librarian, human edit, no proposal |
| 2026-09-04 | Patched | skills/icm-forge/SKILL.md | commit the-loop-librarian, human edit, no proposal |
| 2026-09-10 | Miss | 3 | scripts/icm-loop.sh | ghost ranked below hole and rewrite, so a sev 3 miss on a mistyped path was reported as a hole and the forge would edit a file that does not exist | rank ghost first in the verdict chain |
| 2026-09-10 | Miss | 2 | scripts/icm-loop.sh | a miss dated the patch day and appended after the patch counted as closed, so a same day recurrence was invisible | count a miss open when its date is on or after the patch |
| 2026-09-10 | Miss | 2 | scripts/icm_lib.sh | icm_today stamped UTC while every skill stamps local date, so windows counted a day behind before 10am AEST | one clock, local date, in icm_today |
| 2026-09-10 | Miss | 1 | .claude-plugin/plugin.json | homepage and repository pointed at the old repo name after the GitHub rename | update to MOMENTRIX-ICM-KAP |
| 2026-09-10 | Patched | scripts/icm-loop.sh | commit ghost-first-same-day-open, human directed edit, no proposal |
| 2026-09-10 | Patched | scripts/icm_lib.sh | commit ghost-first-same-day-open, human directed edit, no proposal |
| 2026-09-10 | Patched | .claude-plugin/plugin.json | commit ghost-first-same-day-open, human directed edit, no proposal |
| 2026-09-10 | Use | icm-loop | skills/icm-loop/SKILL.md | audit the loop and fix the index | ok | 3 |
| 2026-09-10 | loop audit and index fixes | 2 | Date | 0 | 0/4/0/0 | 0 | none | scripts/icm-loop.sh |
