# Customer skill template

## Purpose

Show where a customer skill lives. Keep it out of the install toolkit.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| This folder | `SKILL.md` | The three homes | toolkit vs rule books vs this file |
| Pattern 25 | `../../../spec/CONVENTIONS.md` | Pattern 25 | where it may live |
| One of eight | `../../../skills/icm-scaffold/SKILL.md` | frontmatter | do not add a ninth |

## Process

1. Copy this folder to customers/<name>/ in the customer's workspace. Use their real name.
2. Set `name` in `SKILL.md` to that folder name.
3. Leave the eight icm-* skills as the install toolkit. Do not install this file globally.
4. Rulings go in that workspace's rule books. Procedure goes in `SKILL.md`.
5. Customer copy never says AI agent, AI platform, or AI OS.

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Customer skill | customers/<name>/SKILL.md | this `SKILL.md`, renamed |
| Job card | customers/<name>/CONTEXT.md | this shape |

## Routing

| When | Go to |
|---|---|
| Write the procedure | `SKILL.md` |
| Change the install toolkit | `../../../skills/` |
| Read the pattern | `../../../spec/CONVENTIONS.md` |
