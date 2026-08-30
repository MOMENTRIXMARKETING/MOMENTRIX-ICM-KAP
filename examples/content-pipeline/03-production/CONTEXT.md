# 03 production

## Purpose

Turn the narration into a shot list an editor can build from unaided.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Prior stage | `../02-script/output/` | the script | beats and timecodes |
| Rule book | `../_config/style.md` | "Quick Reference" | timecodes, tables |
| Rule book | `../_config/glossary.md` | "Workspace Vocabulary" | what a shot is |

## Process

1. Read the script. One shot per beat, in beat order.
2. Per shot: what is on screen, what moves, what is written.
3. An on screen number is copied from the script, never retyped.
4. Mark every shot needing an asset we do not hold.
5. Save the shot list, then append the ledger row.

## Audit

| Check | Pass condition |
|---|---|
| Coverage | every beat has exactly one shot |
| On screen text | every number matches the script |
| Assets | every missing asset is named |

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Shot list | `output/` | one row per beat |
| Ledger line | `../_log/LOOP-LEDGER.md` | one appended row |

## Routing

| When | Go to |
|---|---|
| Shot list done | `../output/CONTEXT.md` |
| A beat cannot be shown | `../02-script/CONTEXT.md` |
