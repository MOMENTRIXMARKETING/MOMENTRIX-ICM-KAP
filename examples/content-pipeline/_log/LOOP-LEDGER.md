# LOOP LEDGER

Append only. Never rewrite history. A wrong line is corrected by a new line. Every line of every kind goes at the end of the file, under Lines, in time order. The sections above Lines are the shapes, not the places. Task, call and weekly review shapes are fixed by the out-of-the-loop skill. Miss, use and patched shapes are fixed by the toolkit's icm-log skill. Do not invent columns.

## Task lines

One line per closed task.

| Date | Task | Tier | Anchor | Verify cycles | Holes: plan/hunt/review/audit | Workarounds | Call fired | Artifact |
|---|---|---|---|---|---|---|---|---|

## Call lines

One line per call fired. The last column is filled at the weekly review.

| Date | Trigger | What fired it | Decision | Was the call necessary |
|---|---|---|---|---|

## Miss lines

One line per miss, at Session Close. Sev 3 wrong output shipped, 2 cost time, 1 cosmetic. At fault is a path as it exists on disk, or none.

| Date | Miss | Sev | At fault | What missed | Fix that would have prevented it |
|---|---|---|---|---|---|

## Skill lines

One use line per skill or job card a task ran under. One patched line per approved proposal.

| Date | Use | Skill or job card | Path | Task | Outcome | Misses |
|---|---|---|---|---|---|---|

| Date | Patched | Path | Proposal id |
|---|---|---|---|

## Weekly review

One block per review, in the shape the out-of-the-loop skill defines.

## Lines

| 2026-08-24 | Bread staling brief | 2 | every claim sourced | 1 | 0/2/0/0 | none | no | `01-research/output/why-bread-goes-stale-brief.md` |
| 2026-08-24 | Use | 01-research | 01-research/CONTEXT.md | Bread staling brief | ok | 0 |
| 2026-08-26 | Bread staling script | 2 | 5 minutes, every claim tied to a brief row | 2 | 0/0/1/1 | none | no | `02-script/output/why-bread-goes-stale-script.md` |
| 2026-08-26 | Miss | 2 | none | script had no sanctioned wording for an open question, the writer invented one | a rule in voice.md for saying we do not know inside a beat |
| 2026-08-26 | Use | 02-script | 02-script/CONTEXT.md | Bread staling script | rework | 1 |
| 2026-08-27 | Bread staling shot list | 1 | one shot per beat | 1 | 0/0/0/1 | none | no | `03-production/output/why-bread-goes-stale-shotlist.md` |
| 2026-08-27 | Miss | 2 | _config/style.md | shot list used beat start for the timecode, the rule book does not say start or midpoint | say which one the timecode means |
| 2026-08-27 | Use | 03-production | 03-production/CONTEXT.md | Bread staling shot list | ok | 1 |
| 2026-08-28 | Bread staling package | 1 | open questions carried forward | 1 | 0/0/0/0 | none | no | `output/why-bread-goes-stale-package.md` |
| 2026-08-28 | Use | output | output/CONTEXT.md | Bread staling package | ok | 0 |
