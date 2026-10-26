# 02 draft

## Purpose

Draft a short report without adding facts or taking external action.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Prior evidence | `01-research/output/evidence-brief.md` | full file | every permitted claim |
| Voice rules | `_config/voice.md` | full file | audience and claim limits |
| Style rules | `_config/style.md` | "Structure" | report shape and evidence ids |

## Process

1. Draft only from evidence rows and keep each evidence id beside its claim.
2. State purpose, access and preparation, then the open tool detail.
3. Apply the voice and style rules without smoothing uncertainty.
4. Save the draft. Invitations, bookings, and messages stay outside this job.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Draft report | `02-draft/output/draft-report.md` | Markdown |

## Preflight

| Kind | Reference | Version |
|---|---|---|
| Skill | icm-orchestra | 1.0.0 |
| No touch | `.git/` | - |

## Routing

| When | Go to | Edge |
|---|---|---|
| Intake prerequisite | `00-intake/CONTEXT.md` | LOAD |
| Draft is ready for review | `03-review/CONTEXT.md` | NEXT |
| Evidence needs repair | `01-research/CONTEXT.md` | REWORK |
