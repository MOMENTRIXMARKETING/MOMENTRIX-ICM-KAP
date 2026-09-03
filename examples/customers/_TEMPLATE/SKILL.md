---
name: _TEMPLATE
description: "This skill should be used when the user asks to 'add a customer skill', 'where does this customer's SKILL.md live', or 'do not install this globally'. It is the template for a customer-specific skill that lives in this folder, not in the toolkit."
user-invocable: true
---

# Customer skill template

Copy this folder to `customers/<name>/` in the customer's workspace. `<name>` is their real folder name on disk. Do not invent a name in this toolkit. Then set `name` in this file to that folder name.

This file is the customer's procedure. It is not a ninth toolkit skill.

## The three homes

| Home | Holds | Same in every project? |
|---|---|---|
| Toolkit skills | the eight `icm-*` skills under the toolkit's `skills/` | yes. The install toolkit. |
| `_config/` | rule books: how we sound, what words mean, what is allowed | no. They are this project's. |
| This folder's `SKILL.md` | this customer's procedure | no. One folder per customer. |

`_config/` is rule books. It is not a skills library. Do not call a rule book a skill.

The eight toolkit skills stay as the install toolkit and only the install toolkit:

`icm-scaffold`, `icm-retrofit`, `icm-context`, `icm-stage`, `icm-sync`, `icm-wiki`, `icm-log`, `icm-forge`

Do not add this file to that list.

## Where this file must live

This `SKILL.md` lives in the customer folder:

```
customers/<name>/
  CONTEXT.md     the job card for this customer
  SKILL.md       this file
```

In a Pattern 24 company tree the equivalent is the same file sitting in that company's own folder. `examples/architect-company/` is that shape: the skill stays in the tree, it does not leave it.

## Where this file must never live

- Not in the toolkit's `skills/`
- Not in the agent
- Not in `~/.claude/skills` or `~/.agents/skills`
- Not as a Grok Bot global skill
- Not copied next to the eight `icm-*` skills on install

The plugin install and the manual copy in `README.md` copy `skills/icm-*` only. A customer skill is not in that glob. Leave it that way.

## What goes in `_config/` instead

Rulings. Voice, glossary, style, conventions, prices, banned words. A human writes them. Nothing in this skill edits a rule book that already exists.

If a sentence is true for every run of this customer, it may belong in a rule book. If it is the procedure for one job, it belongs here.

## Customer-facing copy

Never write "AI agent", "AI platform", or "AI OS" in anything this customer will see.

## Procedure

Replace this section with this customer's work after you copy the folder. Until then it is empty on purpose.

1. Read this folder's `CONTEXT.md`.
2. Load only the rule books that job card names.
3. Do the job those Inputs name.
4. Write the output where that job card says.

Do not reach into another customer's folder. Do not load the eight toolkit skills unless the job is to install or check ICM itself.
