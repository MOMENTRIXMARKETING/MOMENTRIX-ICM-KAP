# 00 intake

## Purpose

Bind one external request and turn it into a bounded intake brief before any research begins.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| External request | @request | one materialised Markdown file | the requested outcome and boundaries |

## Process

1. Require a `request=PATH` binding to an existing readable file inside this workspace.
2. Restate the deliverable, required content, and external-action boundaries without doing domain work.
3. Name unresolved details rather than filling them in.
4. Save the intake brief at the declared output.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Intake brief | `00-intake/output/request-brief.md` | Markdown |

## Preflight

| Kind | Reference | Version |
|---|---|---|
| None | - | - |

## Routing

| When | Go to | Edge |
|---|---|---|
| Request is bounded | `01-research/CONTEXT.md` | NEXT |
| Request material is incomplete | - | - |
