# Conventions

Layer 3 rule book. It binds. It is not a skill and no agent edits it.

## Quick Reference

| Thing | Convention |
|---|---|
| Folders and files | lowercase-with-hyphens, no spaces |
| Stage folders | zero padded number prefix: `01-`, `02-`, `03-` |
| Stage artifacts | `<topic-slug>-<artifact-type>.md` |
| Topic slug | kebab case, taken from the question, capped at 40 characters |
| Rule books | `_config/*.md`, reference only, never a to do list |
| Job cards | a stage `CONTEXT.md`, five sections, nothing else |

## The handoff

Stage N writes into its own `output/`. Stage N plus 1 reads that folder and nothing further back. That is the whole handoff. No state manager, no orchestration layer, files in predictable places.

A stage that needs something two stages back is a stage whose input table is wrong. Fix the upstream artifact, do not reach around it.

## One Home Per Fact

Every fact has one home and every other file points at it. The brief owns the facts. The script quotes the brief. The shot list quotes the script. If a figure appears in two places and both claim to be right, one is a copy waiting to go stale.

## Rule books over outputs

`_config/` is the authoritative source for how to build here. A file in an `output/` folder is an artifact, not a template. Never read a past output to learn a pattern. Early outputs are the worst outputs, and a desk that imitates them converges on its own first draft.

The one exception is the handoff above: a stage reads the previous stage's output as material to transform, which is why the Inputs table always says why.

## When a rule is wrong

Write it into `../_log/FORGE-PROPOSALS.md` with the file and the line that proves it. Then do the work the current rule's way. An agent proposes a rule change, it never makes one.
