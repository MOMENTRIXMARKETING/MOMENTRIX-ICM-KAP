# customers

The folder shape for a customer-specific skill. Not a workspace root. Not a ninth toolkit skill.

Copy [`_TEMPLATE/`](_TEMPLATE) to `customers/<name>/` in the customer's own project. `<name>` is their real folder name on disk. This toolkit does not invent one.

| File | What it is |
|---|---|
| [`_TEMPLATE/CONTEXT.md`](_TEMPLATE/CONTEXT.md) | the job card for this folder |
| [`_TEMPLATE/SKILL.md`](_TEMPLATE/SKILL.md) | the customer skill, including the three homes |

The three homes, stated in full in `_TEMPLATE/SKILL.md` and as Pattern 25 in `spec/CONVENTIONS.md`:

| Home | Holds |
|---|---|
| Toolkit `skills/icm-*` | the eight install skills. Same eight in every project. |
| `_config/` | rule books. Not a skills library. |
| `customers/<name>/SKILL.md` | this customer's procedure. Never installed globally. |

In a Pattern 24 company tree the equivalent is a `SKILL.md` that stays in that company's folder. See [`../architect-company/`](../architect-company). Do not copy a customer skill into `~/.claude/skills`, into the agent, or onto a Grok Bot as a global skill.

Customer-facing copy never says "AI agent", "AI platform", or "AI OS".
