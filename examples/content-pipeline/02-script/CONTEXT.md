# 02 script

## Purpose

Turn the brief into narration a person reads aloud, each claim tied to a brief row.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Prior stage | `../01-research/output/` | the brief | the only facts |
| Rule book | `../_config/voice.md` | full file | how it sounds |
| Rule book | `../_config/glossary.md` | "Workspace Vocabulary" | what a beat is |

## Process

1. Read the brief. Work only from its claim table.
2. Pick the through line: the one thing the viewer keeps.
3. Write beats in order, each tagged with its brief row.
4. Read it aloud and time it. Over runtime, cut a beat.
5. Run the audit, then save and append the ledger row.

## Audit

| Check | Pass condition |
|---|---|
| Sourcing | every claim names a brief row |
| Voice | zero hits against the hard constraints |
| Runtime | read aloud time fits the brief |

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Script | `output/` | beats in order, with timecodes |
| Ledger | `../_log/LOOP-LEDGER.md` | one appended row |

## Routing

| When | Go to |
|---|---|
| Script accepted | `../03-production/CONTEXT.md` |
| A beat has no brief row | `../01-research/CONTEXT.md` |
