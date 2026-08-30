# 01 listings

## Purpose

Sweep the listings so name, price and deposit match the company rate card.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Department | `../_config/listings.md` | the field rules | what a listing says |
| Company | `../../_config/rate-card.md` | the card | the only price source |
| Last run | `../report.md`, then what it names | open items | leftovers |

## Process

1. List every live listing and when it was last checked.
2. Compare name, day price, week price and deposit to the card.
3. Fix the listing, never the card. A price that looks wrong goes to the owner.
4. Record every change, old value and new, in the report.
5. Write the report into `../reports/`, then pointer and rollup.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Sweep report | `../reports/` | five parts |
| Pointer, rollup | `../report.md`, `../status.md` | link, line |
| Ledger line | `../../_log/LOOP-LEDGER.md` | one appended row |

## Routing

| When | Go to |
|---|---|
| Listings current | `../02-newsletter/CONTEXT.md` at month turn |
| A price looks wrong | ask the owner, leave the listing |
| Item not on the card | report it, invent no price |
