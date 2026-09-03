# Customer skill template

## Purpose

Show where a customer-specific `SKILL.md` lives, and keep it out of the install toolkit.

## Inputs

| Source | File/Location | Section/Scope | Why |
|--------|--------------|---------------|-----|
| This folder's skill | `SKILL.md` | The three homes | toolkit skills vs rule books vs this file |
| The pattern | `../../../spec/CONVENTIONS.md` | Pattern 25 | where a customer skill may live |
| One toolkit skill | `../../../skills/icm-scaffold/SKILL.md` | frontmatter | one of the eight. Do not add a ninth. |

## Process

1. Copy this folder to `customers/<name>/` in the customer's workspace. Use their real folder name. Do not invent one here.
2. Set `name` in `SKILL.md` to that folder name.
3. Leave the eight `icm-*` skills in the toolkit. Do not add this file to `skills/`, `~/.claude/skills`, or a Grok Bot global skill.
4. Put rulings in that workspace's `_config/`. Put this customer's procedure in `SKILL.md`.
5. Never write "AI agent", "AI platform", or "AI OS" in copy this customer will see.

## Outputs

| Artifact | Location | Format |
|----------|----------|--------|
| Customer skill | `customers/<name>/SKILL.md` | this `SKILL.md`, renamed |
| Job card | `customers/<name>/CONTEXT.md` | this shape |

## Routing

| When | Go to |
|---|---|
| Writing the customer's procedure | `SKILL.md` |
| Changing the install toolkit | `../../../skills/` |
| Reading the pattern | `../../../spec/CONVENTIONS.md` |
