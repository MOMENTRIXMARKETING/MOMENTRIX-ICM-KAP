# The Grounding Invariant

> **Ported from karpathy-llm-wiki** by Yuhan Lei.
> Upstream: https://github.com/Astro-Han/karpathy-llm-wiki
>
> The raw and wiki architecture, this invariant, and the evidence verifier come from that
> project. `scripts/check_evidence.py` and `tests/test_check_evidence.py` are vendored from it
> unchanged.
>
> The underlying idea is **Andrej Karpathy's**: the LLM writes and maintains the wiki, the
> human reads and asks questions, and the wiki is a persistent, compounding artifact. Idea
> credit, not a licence obligation. The KAP in this toolkit's name is for Karpathy.
>
> Full licence text is in `NOTICE.md`.

---

## The Invariant

> Every load bearing fact in a `wiki/` article, every number, every date, every direct quote,
> exists verbatim in a `raw/` file that the article's `Raw:` field links.

That is the whole rule. Everything below is how you keep it and how you check it.

**Load bearing** means the claim changes if the fact is wrong. A revenue figure, a date a
thing shipped, a percentage, a version number, a quoted sentence. Connective prose is not load
bearing. "Adoption grew sharply" is prose. "Adoption grew 42K to 61K" is two load bearing
facts and both need to be findable.

**Verbatim** means character for character, in the surface form the source used. See source
fidelity below. This is the part people get wrong.

**Links** means the article's `Raw:` metadata field carries a markdown link to the file, so
the path from claim to evidence is machine followable and one hop long.

---

## Why It Holds

The invariant only works because of layer 4a. `raw/` is immutable. Nothing edits a file in
`raw/`. The only legal write is adding a new file. See `spec/layers.md`.

That immutability is what makes verification cheap. A verified article stays verified, because
the evidence underneath it cannot have moved. There is no incremental verification state to
maintain, no cache to invalidate, no "last checked" column to keep honest. The whole wiki can
be re checked from scratch in seconds, which means it actually gets re checked.

Take immutability away and the invariant becomes a promise instead of a property.

---

## Scope

**Binding on `wiki/`.** Wiki articles are compiled from sources. Compilation is exactly the
operation this invariant governs.

**Not binding on `_config/`.** Rule books are rulings, not compilations. A person decided
them. There is no raw file behind a rule book and none is required. See `spec/layers.md`,
layer 3.

**Not binding on `output/`.** Per run artifacts are the product of a stage doing its job. If a
stage's job card requires its output to be sourced, the job card's Audit section says so, and
that is a stage rule, not this invariant.

**Not binding on `raw/`.** Raw is the evidence. It does not need evidence for itself. It needs
provenance, which is a different thing: where it came from, when it was collected, when it was
published.

---

## Source Fidelity

Four rules. They are the operational content of the invariant, and all four apply at write
time, before the character reaches the file.

### 1. Locate before you write

Before writing any number, date, or direct quote into a wiki article, find it in the raw file.
Actually find it. `grep` it or read the passage. Do not write it from the summary in your head
and plan to verify later, because later never has the same attention as now.

```sh
grep -F -n -- '42K' raw/market/2026-04-02-industry-survey.md
```

If it does not come back, you do not write it in that form. That is not a warning, it is the
rule.

### 2. Exact surface form

Write the value exactly as the source has it.

| Source says | You write | You do not write |
|---|---|---|
| `42K` | `42K` | `42,000` |
| `2.1.80` | `2.1.80` | `2.1.8` or `v2.1.80` |
| `99.9%` | `99.9%` | `99.9 percent` |
| `2026-03` | `2026-03` | `March 2026` |
| `about a third` | `about a third` | `33%` |

Normalising looks like tidying. It is not. It breaks the one hop from claim to evidence,
because the string in the article no longer appears in the file the article points at. It also
quietly invents precision: `about a third` became `33%` and nobody decided that, a habit did.

If the form is genuinely awkward in context, keep the source form and add the gloss beside it:
`42K (forty two thousand)`. The exact string survives, and the sentence still reads.

### 3. Derived values show their components

A number you computed is not in any raw file, so it cannot be located. Show the parts, so each
part can be.

> Growth of 19K over the period, from 42K to 61K.

`42K` and `61K` are both locatable. `19K` is arithmetic the reader can check. Compare:

> Growth of 19K over the period.

Nothing in that sentence exists in any source, and no verifier can say whether it is right.

This applies to sums, deltas, counts you tallied, averages, and percentages you calculated.

### 4. If you cannot locate it, drop the precision

Three options when a value will not verify, in order of preference:

1. **Drop the value.** Say the thing without the number. Most sentences survive this fine.
2. **State it without precision.** "Grew substantially" instead of a figure you cannot source.
3. **Find a source.** Add the source to `raw/`, then write the fact and link it.

The option that is not available is writing it anyway and hoping. An article with one
unsourced number is not slightly worse than one with none. It is a wiki nobody can trust,
because the reader cannot tell which number it was.

---

## Enforcement

Three mechanisms, in the order they act.

### 1. Instruction, at write time

This is the primary enforcement and it is the only one that is always available.

The rules above are followed by the agent writing the article, before the file is saved.
Locate, then write. Every skill that writes into `wiki/` carries this rule and cites this file.

Nothing downstream can recover a fact that was never located. A verifier can only tell you
that a string is missing from a raw file. It cannot tell you what the source actually said. If
the write time rule is skipped, the best the rest of the system can do is report damage.

### 2. `scripts/check_evidence.py`, when python3 exists

The mechanical verifier. Vendored from upstream unchanged, along with its tests.

```sh
python3 scripts/check_evidence.py .
python3 scripts/check_evidence.py . wiki/market/pricing-benchmarks.md
```

With no article paths it checks the whole wiki. It is fast enough that whole wiki is the
normal way to run it.

Three sweeps:

| Sweep | Finds |
|---|---|
| Fidelity | Candidate literals in an article that do not appear in the raw files it links |
| Evidence errors | Articles that cannot be checked at all: missing `Raw:` field, unresolvable `Raw:` links, `Raw:` links escaping `raw/` |
| Inventory | Raw files no article references, excluding those logged as no material |

Its candidate set is deliberately closed: quotes of 15 or more characters, ISO dates, and
specific numbers, meaning thousands grouped, dotted, suffixed, or four or more digits. Small
plain integers and exotic forms are not checked. Those belong to the write time rule and to
judgment review, and the script's own docstring says so.

**It reports. It never fixes.** Its findings are a mechanical report under
`spec/authority-model.md`, which means a script found them and a human decides. Fidelity hits
are suspects, not verdicts: derived values and product names show up there legitimately.
Judging each one against the raw context is a person's job.

The exit code carries no information. The report is the interface.

Its tests are stdlib `unittest`. There is no pytest and nothing to install:

```sh
python3 tests/test_check_evidence.py
```

`check_evidence.py` needs `python3` 3.10 or newer, and so do its tests.

### 3. Nothing, when python3 does not exist

This is the case that matters, because it is the one people design around and then leave
undefined.

Nothing in this toolkit requires python. `scripts/check_evidence.py` is an optional deep
check. Every path through the system works without it. So:

**The write time rule still binds.** It is instruction, not tooling. It does not become
optional because a tool is missing. This is the primary enforcement in every environment and
the only enforcement in this one.

**The POSIX spot check is available and should be used.** It is the same check, done one
literal at a time by the writer:

```sh
grep -F -q -- 'LITERAL' raw/topic/file.md && echo found || echo MISSING
```

To check several literals against one raw file, put them in a file and use `grep -F -f`:

```sh
grep -F -f candidates.txt raw/topic/file.md
```

That is not a substitute for the verifier. The verifier extracts candidates automatically and
sweeps the whole wiki. `grep` checks what you already knew to check. It is still a real check
and it catches the common failure, which is a number that got normalised on its way into the
article.

**Lint reports the gap and never hides it.** When python3 is absent, the lint output says so
in plain words:

```
evidence: deep check not run (python3 not found)
```

**The log records that it did not run.** The lint line in `wiki/log.md` says the deep check
was skipped. A run where the check did not happen must never be indistinguishable from a run
where it passed.

**Nothing is ever reported as verified on the strength of a check that did not run.** No
silent downgrade, no assumed pass, no "probably fine". Absence of the tool is a known unknown
and it gets written down as one.

**Absence never blocks.** The run continues. Ingest works, compile works, query works, lint
works. Missing python3 costs you the deep sweep and nothing else.

---

## Status Blocks, and Not Rewriting History

The invariant governs facts against sources. It does not govern facts against time. Sources go
out of date and sources disagree, and neither is a reason to quietly edit a claim.

When a newer source supersedes a claim, keep the claim and mark it:

```markdown
> **Status: Outdated** (2026-08-14)
> Superseded by the Q3 survey, which reports 61K. Source: Acme Research, 2026-08-14.
```

When sources disagree, keep both and mark the contest:

```markdown
> **Status: Disputed**
> Acme Research reports 42K. The vendor's own filing reports 39K.
```

Both blocks preserve the original claim, which is still verbatim in its raw file, so the
invariant still holds for it. Silently rewriting the number would break the link between the
article and the evidence it was compiled from, and it would erase the fact that the number
ever changed, which is usually the most interesting thing in the article.

A missing or malformed status block is a judgment report, not a mechanical one. See
`spec/authority-model.md`.

---

## The One Sentence Version

Locate it before you write it, write it exactly as it was, show your arithmetic, and when the
tool that would have checked you is not installed, say so out loud instead of calling it
verified.
