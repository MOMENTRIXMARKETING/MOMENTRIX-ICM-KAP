# Layer budgets in the ICM KAP Toolkit

> Sources: icm.defaults.json, 2026-08-30
> Raw: [budgets block of icm.defaults.json](../raw/2026-08-30-icm-defaults-budgets.md)
> Updated: 2026-08-30

## Overview

Every layer file in an ICM workspace carries a character target and a character ceiling, and
both live in one file so that no document has to restate them. The checker warns at the
target and fails at the ceiling.

## The table

| File kind | Target | Ceiling |
|---|---|---|
| Layer 0 identity | 3200 | 6000 |
| Layer 1 routing at a workspace root | 3200 | 8000 |
| Layer 2 job card | 1200 | 2000 |
| Layer 1 routing inside a folder | 1200 | 2000 |
| Layer 3 rule book | 2000 | 4000 |
| Layer 4b wiki article | 8000 | 16000 |

A job card also carries a line ceiling on top of its character ceiling, because job cards
fail by accumulating steps rather than by growing prose.

## The fixed cost of a session

The layers a session always pays for are identity, routing, the job card, and the rule books
the job card names. Their published figures are 3200, 3200, 1200 and 4000, and the file
states the total as 11600.

The note attached to that block reads "Chars, not tokens. 4 chars ~= 1 token. Layers 0+1+2+3
are the fixed cost."

## Why this pair ships as an example

It is the smallest honest demonstration of the grounding invariant: an immutable capture on
one side, a compiled article on the other, and every number in the article present word for
word in the capture. Collected 2026-08-30.
