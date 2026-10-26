# 03 review

## Purpose

Audit the draft against the evidence brief and save the final report at the declared output.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Prior draft | `02-draft/output/draft-report.md` | full file | the report to review |
| Evidence brief | `01-research/output/evidence-brief.md` | full file | the claim-by-claim audit source |

## Process

1. Match every factual sentence in the draft to its evidence id and raw link.
2. Remove unsupported additions and preserve the open tool detail.
3. Confirm the report performs no invitation, booking, message, or purchase.
4. Save the reviewed report at the declared final output.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Final report | `03-review/output/final-report.md` | Markdown |

## Preflight

| Kind | Reference | Version |
|---|---|---|
| Skill | icm-orchestra | 1.0.0 |
| No touch | `.git/` | - |

## Routing

| When | Go to | Edge |
|---|---|---|
| Final report is accepted | - | - |
| Draft needs repair | `02-draft/CONTEXT.md` | REWORK |
