# Conventions

Layer 3 rule book. It binds. It is not a skill and no agent edits it.

## Quick Reference

| Thing | Convention |
|---|---|
| Folders and files | lowercase-with-hyphens, no spaces |
| Stage folders | zero padded number prefix: `01-`, `02-` |
| Reports | `reports/` under the run date and a slug, kebab case, never overwritten |
| Pointers | `report.md` holds one link and nothing else |
| Rollups | `status.md` is compiled, one line per department |
| Never edited by an agent | anything in `_config/`, at any depth |

## The small task floor

The floor is written here so it is not re-argued each morning.

A job is **below the floor** when all four are true:

1. One person could finish it in under fifteen minutes.
2. It needs no file that is not already named in `ARCHITECT.md`.
3. It changes no price, no invoice and no promise made to a customer.
4. It is reversible by deleting or rewriting one line.

The architect does below-floor work itself and writes what it did into today's report. Everything else gets an agent spawned into the department folder.

Under the floor, spawning costs more than the task does. Above it, doing the work yourself costs the department its record of its own work.

## One Home Per Fact

Every fact has one home and every other file points at it. The department that owns a number is the only place that number is written down. If the same figure is authoritative in two files, one of them is a copy waiting to go stale, and the fix is a pointer, not a second edit.

Search for a distinctive phrase. Two hits that both claim to be right is the bug.

## Cross references

Every folder points outward at what it needs. Nothing points back. A department may read the company rule books. A company rule book never names a department.

## When a rule is wrong

Say so in a call line in `../_log/LOOP-LEDGER.md`, with the file and the line that proves it. Then do the work the current rule's way. An agent proposes a rule change, it never makes one.
