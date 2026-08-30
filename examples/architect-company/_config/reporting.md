# Reporting

Layer 3 rule book. What a run owes before it counts as finished.

## Quick Reference

| Thing | Rule |
|---|---|
| Where | the folder's own `reports/`, under the run date and a slug |
| Overwrite | never, at any depth, for any reason |
| Pointer | update `report.md` to the new file, same run |
| Rollup line | update the folder's `status.md`, same run |

## What a report contains

Five parts, in this order, and nothing else.

1. **What I was asked to do.** One sentence, in the words of the job card.
2. **What I did.** The steps that actually ran, including the ones that failed.
3. **What I found.** Numbers with the file or record they came from.
4. **What is still open.** Named, with who or what unblocks it. An empty list is written as "nothing open", never left out.
5. **The one line.** The sentence that will be copied into `status.md`.

## Why append only

Writing every run over one `report.md` loses the first worker's record to the second, and turns the history into a snapshot of whoever ran last. A wrong report is corrected by a new report that says what changed, never by editing the old one.

The pointer file exists so that append only costs a reader nothing. `report.md` is one link. `reports/` is the record.

## When a rule is wrong

Log a call line in `../_log/LOOP-LEDGER.md` with the report that would not fit the shape. Do not widen the shape yourself.
