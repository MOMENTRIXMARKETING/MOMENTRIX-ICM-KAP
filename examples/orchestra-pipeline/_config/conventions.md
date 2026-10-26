# Conventions

Layer 3 rule book. It binds and no agent edits it.

## Quick Reference

| Thing | Convention |
|---|---|
| Job identity | full workspace-relative path to a job card |
| Positive stages | `01-` through `99-`, lowercase slug, gaps allowed |
| Intake | optional reserved `00-intake`, first in routing order |
| Artifacts | one named Markdown file under the stage's `output/` |
| Routing | explicit `LOAD`, `NEXT`, or `REWORK` on every path-bearing row |

## Typed handoffs

An Inputs reference to a unique prior output creates a `LOAD` dependency. `NEXT` selects normal forward flow. `REWORK` returns to an earlier card for repair. Keep `LOAD` acyclic and check `NEXT` cycles independently. A legal forward `NEXT` and backward `REWORK` pair is ordinary repair flow, not a dependency cycle.

## One Home Per Fact

Immutable evidence lives in `raw/`. Compiled knowledge lives in `wiki/`. A stage handoff lives at one declared output path. Other files link or point to that home rather than maintaining a second authoritative copy.

## Where A Learned Thing Lives

| Learning | Home |
|---|---|
| A naming or routing rule | this file, after human approval |
| A word with two uses | `_config/glossary.md`, after human approval |
| A new public-safe source | a new file under `raw/workshop/` |
| Compiled source knowledge | `wiki/workshop/`, with `Raw:` links and log entries |
| A proposed rule with no approved home | `_log/FORGE-PROPOSALS.md` |

## When a rule is wrong

Append the case and its evidence to `_log/FORGE-PROPOSALS.md`. Follow the current rule until a human approves a change.
