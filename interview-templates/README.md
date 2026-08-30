# Interview Templates

Material a skill fills in **in conversation with a human**, and then writes into the
workspace itself. No script reads this directory. Nothing here is ever stamped into a
project by `icm-plan.sh`, `icm-apply.sh` or any other script, and there is no lookup,
precedence rule or override hook that would let it be.

That is the whole contract, and it is why the directory is not called `templates/`.

## Why no script may read these

Every file here carries at least one of three things that only a human answer can resolve:

- double-brace onboarding placeholders such as `{{AUDIENCE}}` or `{{CANONICAL_PATH}}`
- single-brace fill instructions such as `{topic-name}`
- a leading HTML authoring comment that says what to delete before saving

A script that stamped one of those into a live workspace would ship a hole and call it
clean. Apply is not an interview. The only bodies apply can write are the `icm_body_*`
functions compiled into `scripts/icm_lib.sh`, which is the single source of truth for
every byte the toolkit writes.

## What is in here

| File | Filled by | Written to |
|---|---|---|
| `IDENTITY.md.tmpl` | `icm-scaffold` | `IDENTITY.md` |
| `CONTEXT.root.md.tmpl` | `icm-scaffold` | `CONTEXT.md` |
| `CONTEXT.stage.md.tmpl` | `icm-stage` | a stage `CONTEXT.md` |
| `CONTEXT.folder.md.tmpl` | `icm-context` | a folder `CONTEXT.md` |
| `LOOP-LEDGER.md.tmpl` | `icm-log` | `_log/LOOP-LEDGER.md` |
| `questionnaire.md.tmpl` | `icm-scaffold` | the interview itself, not the workspace |
| `config/conventions.md.tmpl` | `icm-scaffold` | `_config/conventions.md` |
| `config/glossary.md.tmpl` | `icm-scaffold` | `_config/glossary.md` |
| `config/voice.md.tmpl` | `icm-scaffold` | `_config/voice.md` |
| `config/style.md.tmpl` | `icm-scaffold` | `_config/style.md` |
| `wiki/article.md.tmpl` | `icm-wiki` | a `wiki/` article |
| `wiki/index.md.tmpl` | `icm-wiki` | `wiki/index.md` |
| `wiki/log.md.tmpl` | `icm-wiki` | `wiki/log.md` |
| `wiki/raw.md.tmpl` | `icm-wiki` | a `raw/` file header |
| `wiki/archive.md.tmpl` | `icm-wiki` | a `wiki/` archive page |

The five rule book names are fixed: `conventions.md`, `glossary.md`, `voice.md`,
`style.md`, `grounding.md`. `grounding.md` has no interview template because its content
is the grounding invariant itself, which is not a per-project answer. It ships as a
built-in body only.

## Rules for editing a file in here

1. Every file keeps the `.tmpl` suffix. The suffix is what marks it as interview material
   and what exempts it from the placeholder check.
2. A destination-named file, for example `wiki/index.md`, must never appear in this
   directory. Nothing would read it, and its presence would suggest something does.
3. If a shape here disagrees with the body in `scripts/icm_lib.sh`, one of them is wrong.
   The body wins for anything a script writes. Fix the template, or fix the body, but do
   not leave both standing and different.
