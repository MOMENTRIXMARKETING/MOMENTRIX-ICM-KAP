# FORGE PROPOSALS

What the forge proposes, waiting on a human decision. The forge never edits. The logger never judges. The human holds the only pen that touches a rule book.

## Proposals

One block per proposal, appended by icm-forge below the Authority section, body never edited after it is written. The Status line is the only line that changes, and only when a human names the id. The shape, indented here so the example is never counted as a proposal:

    ## FP-<YYYY-MM-DD>-<NN> | <path>
    - Status: proposed | proposed (unattended run) | approved <date> | rejected <date>, <reason>
    - Kind: edit | new | archive | rewrite
    - Hole: <one line>
    - Evidence: <the ledger lines, pasted verbatim, at least two for edit>
    - Smallest edit: <the exact replacement text, or the exact path and shape for new>
    - Test that proves it: <a measurable check, or none possible and why>

A proposal heading starts at column one with two hashes and FP-. No other heading in this file may start with FP-.

## Authority

Authority is one of three, and the word chosen decides who may act.

- **safe fix** - deterministic and reversible, applied by a script, recorded here after the fact.
- **mechanical report** - a script found it and a script must not fix it. A human decides.
- **judgment report** - a model's opinion. Always a proposal, never a change.

A proposal with no evidence column is not a proposal, it is an opinion. Give it the file and the line.
