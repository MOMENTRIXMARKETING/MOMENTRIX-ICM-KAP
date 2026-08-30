# 01 research

## Purpose

Turn one reader question into a brief where each claim carries its source.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Question | the request | one sentence | what was asked |
| Rule book | `../_config/glossary.md` | "Domain Terms" | the words used here |
| Rule book | `../_config/style.md` | "Structure" | what a brief looks like |

## Process

1. Write the question as one sentence a viewer would ask. Not a topic.
2. Gather sources and read them. Name each so a reader finds it.
3. One row per claim: claim, source, what it does not say.
4. Anything unsettled goes under open questions, never smoothed.
5. Save the brief, then append the ledger row.

## Checkpoints

| After step | Agent presents | Human decides |
|---|---|---|
| 3 | the claim table | which claims the video rests on |

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Brief | `output/` | claim table, open questions |
| Ledger | `../_log/LOOP-LEDGER.md` | one appended row |

## Routing

| When | Go to |
|---|---|
| Brief accepted | `../02-script/CONTEXT.md` |
| A claim has no source | drop it, note it as open |
| The question is two | split it, run this twice |
