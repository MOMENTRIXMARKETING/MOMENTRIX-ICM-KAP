# 02 newsletter

## Purpose

Draft one monthly newsletter a busy customer finishes, then hand it to the owner.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Department | `../_config/listings.md` | "The newsletter" | what is allowed |
| Company | `../../_config/voice.md` | "Hard Constraints" | how it reads |
| Prior stage | `../01-listings/CONTEXT.md` | Outputs | prices are checked first |

## Process

1. Confirm the listing sweep ran this month. If not, run it first.
2. Pick one thing worth saying. One offer at most, and only an agreed one.
3. Draft it. No countdowns, no urgency, no exclamation marks.
4. Give the draft to the owner. Drafted is not sent.
5. Write the report into `../reports/` and say plainly which it is.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Newsletter draft | with the owner | house voice |
| Run report | `../reports/` | five parts |
| Pointer, rollup | `../report.md`, `../status.md` | one link, one line |

## Routing

| When | Go to |
|---|---|
| Owner approves | send, then write a second report saying it went |
| Prices unchecked | `../01-listings/CONTEXT.md` first |
| An offer is not agreed | drop it, do not soften it |
