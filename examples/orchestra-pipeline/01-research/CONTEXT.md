# 01 research

## Purpose

Turn the bounded request and public sources into one evidence row per claim.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Prior intake | `00-intake/output/request-brief.md` | full file | the deliverable and limits |
| Compiled knowledge | `wiki/workshop/orientation.md` | full file | claims and sources |
| Raw workshop brief | `raw/workshop/2026-10-26-workshop-brief.md` | full file | purpose, access, and open detail |
| Raw participant notes | `raw/workshop/2026-10-26-participant-notes.md` | full file | arrival and preparation |

## Process

1. Select claims that answer the intake brief.
2. Locate each claim in raw and preserve its surface form.
3. Give each row an id and direct source link.
4. Keep the unresolved tool detail in its own row.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Evidence brief | `01-research/output/evidence-brief.md` | Markdown claim table |

## Preflight

| Kind | Reference | Version |
|---|---|---|
| None | - | - |

## Routing

| When | Go to | Edge |
|---|---|---|
| Evidence brief is ready | `02-draft/CONTEXT.md` | NEXT |
| Request needs repair | `00-intake/CONTEXT.md` | REWORK |
