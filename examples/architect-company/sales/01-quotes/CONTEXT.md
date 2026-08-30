# 01 quotes

## Purpose

Turn one enquiry into a written quote any other agent would have priced the same.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Department | `../_config/quoting.md` | rate card, deposits | the price |
| Company | `../../_config/voice.md` | "Hard Constraints" | how it reads |
| Enquiry | the customer message | full text | what was asked |

## Process

1. Name the item as the rate card names it. If it is not on the card, stop.
2. Count hire days. Five or more is quoted at the week rate.
3. Add the deposit and delivery. Delivery outside town is a question, not a guess.
4. Write the quote in the house voice. One ask, no exclamation marks.
5. Record the quote and its date in the report in `../reports/`.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Quote sent | the customer, in writing | house voice |
| Run report | `../reports/` | five parts |
| Ledger line | `../../_log/LOOP-LEDGER.md` | one appended row |

## Routing

| When | Go to |
|---|---|
| Quote sent | `../02-follow-up/CONTEXT.md` after 3 days |
| Item not on the rate card | stop, ask the owner, quote nothing |
| Customer pushes on price | hold it, log a call line |
