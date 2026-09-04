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

| 2026-08-26 | September newsletter draft | 2 | one send, no discount claims | 1 | 0/1/0/0 | none | no | `marketing/reports/2026-08-26-september-newsletter.md` |
| 2026-08-26 | Use | marketing/02-newsletter | marketing/02-newsletter/CONTEXT.md | September newsletter draft | ok | 0 |
| 2026-08-28 | August close | 2 | books balanced before the 1st | 2 | 1/0/1/0 | none | no | `finance/reports/2026-08-28-august-close.md` |
| 2026-08-28 | Miss | 2 | finance/02-month-end/CONTEXT.md | Process step 3 says reconcile but not against which export, the agent asked | name the export file in the Inputs table |
| 2026-08-28 | Use | finance/02-month-end | finance/02-month-end/CONTEXT.md | August close | rework | 1 |
| 2026-08-29 | Open quote sweep | 1 | no customer chased twice in a week | 1 | 0/0/0/0 | none | yes | `sales/reports/2026-08-29-open-quote-sweep.md` |
| 2026-08-29 | irreversibility | Sales wanted to discount an open quote to close it | Held the quoted price, asked the owner first | pending |
| 2026-08-29 | Use | sales/02-follow-up | sales/02-follow-up/CONTEXT.md | Open quote sweep | ok | 0 |
| 2026-08-29 | Architect day | 1 | spawn above the floor, log below it | 1 | 0/0/0/0 | none | no | `reports/2026-08-29-architect-day.md` |
