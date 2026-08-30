# Placeholder Syntax

> **Ported from the Model Workspace Protocol.** This file is a port of
> `_core/placeholder-syntax.md` by Jake Van Clief and David McDermott.
> Upstream: https://github.com/RinDig/Model-Workspace-Protocol-MWP-
>
> The `{{SCREAMING_SNAKE}}` convention, the conditional section rule, and the replacement
> contract are theirs. This port adds the layer rules for where placeholders may and may not
> appear, and ties the sweep to this toolkit's excluded folder list. Full licence text is in
> `NOTICE.md`.

This is the onboarding contract. A workspace ships with placeholders in its files. The
onboarding agent replaces them with real content when the user runs `setup`. Onboarding is
finished when zero placeholders remain.

---

## Basic Syntax

Double braces, screaming snake case:

```
{{BRAND_NAME}}
{{TARGET_AUDIENCE}}
{{PRIMARY_COLOUR}}
```

They are literal strings in markdown files. They are not code variables and nothing evaluates
them. The onboarding agent finds them and replaces them with the user's answers by plain
string substitution.

The braces are the whole detection mechanism. That is why the sweep at the end just looks for
`{{`, and why nothing else in a shipped workspace may contain a double brace.

---

## Replacement Rules

1. The onboarding agent reads the questionnaire for the list of questions.
2. Each question maps to one or more placeholders.
3. Each question names the files its placeholders appear in.
4. The agent asks the questions conversationally and collects the answers.
5. The agent replaces every instance of each placeholder with the corresponding answer.
6. After every replacement, the agent sweeps the whole workspace for any remaining `{{`.
7. Anything left over gets flagged and the user is asked for the missing information.
8. Onboarding is complete only when the sweep comes back empty.

Step 6 is not optional and it is not a formality. A workspace shipped with one unreplaced
placeholder produces one confidently wrong output per run until somebody notices.

---

## Where Placeholders May Appear

By layer, because the layer decides.

| Layer | May hold placeholders | Why |
|---|---|---|
| 0 `IDENTITY.md` | No | It has to work before onboarding runs |
| 1 `CONTEXT.md` routing | No | The routes must resolve before setup starts |
| 2 job card, Inputs values | Yes, values only | Paths and headings stay literal |
| 3 `_config/` rule books | Yes, freely | This is where workspace specifics live |
| 4a `raw/` | Never | A placeholder in a source is a fabricated fact |
| 4b `wiki/` | Never | A placeholder in an article is an ungrounded claim |
| 4b `output/` | Never | Output is produced at run time, not shipped |

Two of those are hard prohibitions rather than conventions.

**Never in `raw/`.** Layer 4a is immutable evidence. A placeholder there would be a fact
nobody sourced, sitting in the folder the whole grounding invariant rests on. See
`spec/grounding-invariant.md`.

**Never in `wiki/`.** A wiki article's facts trace to raw files. A placeholder traces to a
questionnaire answer, which is not evidence. If a workspace needs a seeded article, seed it
after onboarding, from real sources.

The layer 0 and layer 1 prohibition is practical. Those files are how the onboarding agent
finds its way around. If they are full of unreplaced braces, the agent that is meant to do the
replacing cannot read its own map.

Inside a job card, placeholders belong in the values of an Inputs or Outputs table, never in
the structure. The heading names are fixed by `icm.defaults.json` under `required_sections`,
and the file paths have to resolve for anything to work.

```markdown
| Rule book | `../../_config/voice.md` | "{{VOICE_SECTION}}" | Tone for this stage |
```

That is fine. A placeholder standing in for the path is not.

The questionnaire itself never holds placeholders. It is the source of the answers, not a
target of them.

---

## Conditional Sections

A conditional block wraps content that gets removed when the user says it is not needed.

```markdown
{{?SECTION_NAME}}

## Section Heading

Content that may or may not apply.

{{/SECTION_NAME}}
```

**A conditional block may only wrap whole sections.** A section means a heading plus
everything under it, down to the next heading of the same or higher level.

Valid:

```markdown
{{?VIDEO_PRODUCTION}}

## Video Production Settings

Resolution, frame rate, and export format.

- Resolution: 1920x1080
- Frame rate: 30fps
- Export format: MP4

{{/VIDEO_PRODUCTION}}
```

Not valid, do not do this:

```markdown
- Item one
{{?OPTIONAL_ITEM}}
- Item two
{{/OPTIONAL_ITEM}}
- Item three
```

Not valid, do not do this either:

```markdown
The voice is {{?FORMAL}}formal and authoritative{{/FORMAL}}{{?CASUAL}}casual{{/CASUAL}}.
```

The reason is mechanical. Removing inline content leaves orphaned list markers, broken
sentences, and half formed tables. Removing a whole section always leaves valid markdown, no
matter which sections go.

The same applies inside tables. A conditional may remove a whole table, never one row of one,
because a table with its header removed is not a table.

---

## Naming

Descriptive names. `{{BRAND_NAME}}`, not `{{BN}}`.

Group related placeholders with a shared prefix:

- `{{VOICE_DESCRIPTION}}`, `{{VOICE_ADJECTIVES}}`, `{{VOICE_BANNED_WORDS}}`
- `{{PRIMARY_COLOUR}}`, `{{SECONDARY_COLOUR}}`, `{{ACCENT_COLOUR}}`
- `{{DEPARTMENT_1}}`, `{{DEPARTMENT_2}}`, `{{DEPARTMENT_3}}`

Conditional names describe what they wrap: `{{?BUILD_STAGE}}`, `{{?PILLAR_4}}`,
`{{?SECOND_DEPARTMENT}}`.

Screaming snake case, always. It makes a placeholder visible in a wall of prose and it never
collides with anything a user would legitimately type.

---

## Questionnaire Mapping

The questionnaire is the bridge between a question and the files it fills. Each entry names:

- The question text, which is what the agent actually asks
- The placeholder or placeholders it fills
- The files those placeholders appear in
- The input type: free text, choice, yes or no
- Optionally, a follow up for vague answers
- Optionally, conditional logic: if the answer is X, remove section Y

Questionnaire design rules are pattern 8 in `spec/CONVENTIONS.md`. The short version: flat
list, all at once, system level only, derive rather than ask, defaults on everything, ask once
and never again.

---

## The Sweep

The last step of onboarding, and worth running by hand any time a workspace is edited.

Using the prune expression from `spec/excluded-folders.md`, abbreviated here to keep the shape
readable:

```sh
find . \( -name .git -o -name node_modules -o -name .icm \) -prune -o \
  -name '*.md' -exec grep -n '{{' {} +
```

Take the full prune list from `spec/excluded-folders.md`. Do not retype it from memory and do
not extend it here.

Use `-exec ... {} +` rather than piping to `xargs`, so paths containing spaces survive.

Empty output means onboarding is complete. Any output is a list of things the user still has
to answer.

To check the two folders that must never contain a placeholder at all:

```sh
grep -rn '{{' raw/ wiki/
```

A hit there is not an unfinished onboarding. It is a defect, and it is a different and worse
problem than an unanswered question. See the layer table above.

---

## Placeholders and the Never Overwrite Rule

Replacement edits files in place, which looks like it contradicts pattern 19 in
`spec/CONVENTIONS.md`. It does not, and the distinction is worth being precise about.

Placeholder replacement happens in the interview. A skill fills a file from
`interview-templates/` in conversation with a human and writes the result, during the
setup the user asked for. Those are the toolkit's files until onboarding hands them over.

No script ever expands a placeholder. The bodies `icm-apply.sh` writes are compiled into
`scripts/icm_lib.sh` and carry none, and a body that did would be refused at render time.

Never overwrite protects files the user already had. When the scaffolder wants to create a
file that already exists, it writes its version to `.icm/proposed/` at the same relative path
and reports the collision. The existing file, placeholders or not, is untouched.

So: a template being filled in is normal onboarding. An existing file being rewritten is a
collision, and a collision always goes to `.icm/proposed/` for the user to diff.

Paths in the `never_write` list in `spec/excluded-folders.md` are never touched by either
path.
