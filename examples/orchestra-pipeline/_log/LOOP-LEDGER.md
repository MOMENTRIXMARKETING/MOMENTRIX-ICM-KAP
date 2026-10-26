# LOOP LEDGER

Append only. Never rewrite history. A wrong line is corrected by a new line. Every line goes under Lines in time order. The sections above Lines define shapes, not destinations. Do not invent columns.

## Task lines

One line per closed task.

| Date | Task | Tier | Anchor | Verify cycles | Holes: plan/hunt/review/audit | Workarounds | Call fired | Artifact |
|---|---|---|---|---|---|---|---|---|

## Call lines

One line per call fired. The last column is filled at weekly review.

| Date | Trigger | What fired it | Decision | Was the call necessary |
|---|---|---|---|---|

## Miss lines

One line per miss at Session Close. Sev 3 is wrong output shipped, 2 cost time, 1 cosmetic.

| Date | Miss | Sev | At fault | What missed | Fix that would have prevented it |
|---|---|---|---|---|---|

## Skill lines

One use line per skill or job card. One patched line per approved proposal.

| Date | Use | Skill or job card | Path | Task | Outcome | Misses |
|---|---|---|---|---|---|---|

| Date | Patched | Path | Proposal id |
|---|---|---|---|

## Weekly review

One block per review in the shape the loop skill defines.

## Lines

These rows belong to the public-safe worked example.

| 2026-10-26 | Workshop intake | 1 | request bounded | 1 | 0/0/0/0 | none | no | `00-intake/output/request-brief.md` |
| 2026-10-26 | Use | 00-intake | 00-intake/CONTEXT.md | Workshop intake | ok | 0 |
| 2026-10-26 | Workshop evidence | 1 | every claim has a raw link | 1 | 0/0/0/0 | none | no | `01-research/output/evidence-brief.md` |
| 2026-10-26 | Use | 01-research | 01-research/CONTEXT.md | Workshop evidence | ok | 0 |
| 2026-10-26 | Workshop draft | 1 | evidence ids retained | 1 | 0/0/0/0 | none | no | `02-draft/output/draft-report.md` |
| 2026-10-26 | Use | 02-draft | 02-draft/CONTEXT.md | Workshop draft | ok | 0 |
| 2026-10-26 | Workshop review | 1 | final claims match evidence | 1 | 0/0/0/1 | none | no | `03-review/output/final-report.md` |
| 2026-10-26 | Use | 03-review | 03-review/CONTEXT.md | Workshop review | ok | 0 |
