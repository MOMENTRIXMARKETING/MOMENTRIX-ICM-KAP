# Grounding

Binds anything written into `wiki/`.

## The invariant

Every load-bearing fact in a wiki article, including every number, date, and direct quote, exists verbatim in a `raw/` file linked by that article's `Raw:` field.

## The rules

1. Locate the source line before writing the claim.
2. Keep the exact source surface form. Derived values show their components.
3. Every article has a metadata `Raw:` field whose links stay inside `raw/`.
4. `raw/` is immutable. A correction is a new source file and a new log entry.
5. Record disagreement and uncertainty rather than resolving either by guesswork.
6. Update `wiki/index.md` and append `wiki/log.md` in the same knowledge change.

## Article shape

Open with title, source summary, one or more `Raw:` links, and `Updated:` metadata. The body synthesises the linked evidence and ends with unsettled details. Use relative links that resolve on disk.

## What enforces this

The writer applies this rule at write time. The optional evidence checker reports suspect literals, broken evidence links, and unreferenced raw files. It never repairs an article or replaces judgment.

## When a rule is wrong

Append the case to `_log/FORGE-PROPOSALS.md`. Never edit this rule book as an agent.
