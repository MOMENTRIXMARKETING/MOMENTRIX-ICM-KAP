---
name: icm-wiki
description: "This skill should be used when the user asks to 'add this to the wiki', 'ingest this source', 'what do I know about X', 'summarise everything I have on Y', 'lint the wiki', 'archive that answer', or mentions an 'LLM wiki' or a 'Karpathy wiki'. Saves sources into immutable raw/ (Layer 4a), compiles them into wiki/ articles (Layer 4b), answers questions with citations, and verifies the grounding invariant with the optional scripts/check_evidence.py."
user-invocable: true
argument-hint: "ingest <url|path> | query <question> | lint"
---

# ICM Wiki

Build and maintain a compiled knowledge base inside an ICM workspace. You manage two Layer 4 folders. Sources land in `raw/`. You compile them into `wiki/`. The wiki compounds.

The idea is Andrej Karpathy's: the LLM writes and maintains the wiki, the human reads and asks questions, and the wiki is a persistent artifact that gets more valuable every time it is touched.

## Resolve the toolkit first

The templates, the spec and the optional deep check live in the toolkit, not in the workspace. Resolve the root once, then use `$ICM_HOME` for every read and every command.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

## The two halves of Layer 4

`$ICM_HOME/spec/layers.md` splits Layer 4 in two, and the split is the whole discipline.

**Layer 4a is `raw/`.** Immutable source material. You read it, you never modify it. One level of topic subdirectories: `raw/<topic>/<file>.md`. Because raw is immutable, anything verified against it stays verified.

**Layer 4b is `wiki/`** (and `output/` in a stage pipeline). Compiled. You own it completely. One level of topic subdirectories: `wiki/<topic>/<article>.md`, plus two special files:

- `wiki/index.md` — one row per article, grouped by topic, link plus summary plus Updated date.
- `wiki/log.md` — append only operation log. The path is the `log.wiki_log` key in `$ICM_HOME/icm.defaults.json`.

Templates are in `$ICM_HOME/interview-templates/wiki/`: `raw.md.tmpl`, `article.md.tmpl`, `index.md.tmpl`, `archive.md.tmpl`, `log.md.tmpl`. Read the one you need when you need the exact format. That directory is interview material a human and a model fill in together; no script reads it. Article size is governed by `budgets["wiki_article.md"]` in `$ICM_HOME/icm.defaults.json`.

Never walk into anything matching `excluded_globs` in `$ICM_HOME/icm.defaults.json`. `$ICM_HOME/spec/excluded-folders.md` is the human rendering of that list.

### Initialization

Triggers only on the first ingest. Check whether `raw/` and `wiki/` exist. Create only what is missing. Never overwrite:

- `raw/` with a `.gitkeep`
- `wiki/` with a `.gitkeep`
- `wiki/index.md`, heading `# Knowledge Base Index`, empty body
- `wiki/log.md`, heading `# Wiki Log`, empty body

If query or lint cannot find the structure, say "run an ingest first to initialize the wiki" and stop. Do not auto-create on a read path.

## The grounding invariant

Every load-bearing fact in a `wiki/` article — every number, date and direct quote — exists verbatim in a `raw/` file that the article's Raw field links to. The rule in full is `$ICM_HOME/spec/grounding-invariant.md`.

Compile **establishes** the invariant: locate the value in raw before you write it. Lint **verifies** it. The verification is a deep check, and it is optional infrastructure; the compile-time rule is not optional and carries the load on its own.

---

## Ingest

Fetch a source into `raw/`, then compile it into `wiki/` unless it adds nothing. Always fetch. Whether to compile depends on the triage.

### Fetch, into Layer 4a

1. Get the source with whatever web or file tools this environment gives you. If nothing can reach it, ask the user to paste it.
2. Pick a topic directory. Check the existing `raw/` subdirectories first and reuse one if the topic is close enough. Create a new subdirectory only for a genuinely distinct topic.
3. Save as `raw/<topic>/YYYY-MM-DD-descriptive-slug.md`.
   - Slug from the source title, kebab case, 60 characters at most.
   - Published date unknown: drop the date prefix from the filename. The metadata Published field still appears, set to `Unknown`.
   - Filename already taken: append a numeric suffix, `descriptive-slug-2.md`.
   - Include the metadata header: source URL, collected date, published date.
   - Preserve the original text. Clean formatting noise. Do not rewrite opinions.

   Format: `$ICM_HOME/interview-templates/wiki/raw.md.tmpl`.

Once written, that file is immutable. Later corrections arrive as a new raw file, never as an edit to an old one.

### Triage

After saving the raw file, before touching `wiki/`, search the wiki for the source's key entities and their synonyms. Then state the disposition out loud:

- **New** — creates one or more new articles.
- **Update** — merges into existing articles.
- **Disputed** — contradicts existing content. May combine with New or Update.
- **No material** — adds nothing the wiki does not already hold. Keep the raw file, log it, stop. Do not force an article out of a thin source.

New, Update and Disputed combine freely. No material is exclusive.

### Compile, into Layer 4b

Decide where the content belongs:

- **Same core thesis as an existing article** → merge. Add the new source to Sources and Raw. Update the affected sections.
- **New concept** → new article in the most relevant topic directory. Name the file after the concept, not after the raw file.
- **Spans several topics** → place it in the most relevant directory, then add See Also cross references to the related articles elsewhere.

These are not exclusive. One source can merge into an article and also justify a separate article for a distinct concept it introduces.

Check for factual conflict in every case. When the new source contradicts existing content, mark the contested claim with a **Status: Disputed** block. When the conflicting claims live in separate articles, mark both and cross-link them.

**Source fidelity.** Every number, date and direct quote gets located in the raw file, by grep or by reading, *before* it is written. Write the value exactly as it appears: if the source says 42K, write 42K, not 42,000. A derived value shows its components, so each component is findable in raw. If you cannot locate a value, do not write its exact form. Drop it, or state it without precision.

Format: `$ICM_HOME/interview-templates/wiki/article.md.tmpl`. Two things it is easy to get wrong:

- The Sources field is author, organization or publication plus date, semicolon separated. The Raw field is markdown links to `raw/` files, semicolon separated.
- Paths from `wiki/<topic>/` back to raw are `../../raw/<topic>/<file>.md`, two levels up to the project root. The deep check refuses a Raw link that escapes `raw/`, so get the depth right.

### Cascade updates

After the primary article, hunt the ripples. Do not trust the index alone. Search the whole wiki for the source's key entities, aliases and the claims it touches, then update every non-archive article that is materially affected. Each one gets its Updated date refreshed.

When the new source supersedes or contradicts an old claim, keep the old claim on the record and mark it:

- **Status: Outdated** with a date, when something newer replaces it.
- **Status: Disputed**, when sources disagree and neither has won.

Never silently rewrite history. The old claim plus the reason it fell is worth more than a clean page.

Archive pages are never cascade updated. They are point-in-time snapshots and they are allowed to age.

### Post-ingest

Update `wiki/index.md`: add or update a row for every article you touched. A new topic section gets a one-line description. The Updated date reflects when the article's knowledge changed, not the filesystem timestamp. Format: `$ICM_HOME/interview-templates/wiki/index.md.tmpl`.

Then append to `wiki/log.md`:

```
## [YYYY-MM-DD] ingest | <primary article title>
- Disposition: <New; Update; Disputed>
- Raw: <raw file path>
- Updated: <cascade-updated article title>
```

Drop the `- Updated:` lines when nothing cascaded. For no material, log this exact shape and stop:

```
## [YYYY-MM-DD] ingest | no material: <project-root-relative raw path>
- Disposition: No material
```

That heading is a machine-readable inventory key. `scripts/check_evidence.py` reads it to tell a deliberate no-material file apart from a backlog item, so the wording is fixed. The Disposition line stays required for the human reading the log.

### Research, multi-source ingest

Only when the user explicitly asks you to research a topic or gather sources. An ordinary knowledge question goes to query, which writes nothing.

1. Split the topic into a few angles. Search each with a wide net: official names, abbreviations, synonyms, not just the literal keywords.
2. For any core claim you expect to reach, deliberately search the other side: failures, criticism, failed replications.
3. Save the sources you keep into `raw/` as usual. Searching can run in parallel. **Compiling cannot.** Compile one source at a time, because `index.md`, `log.md` and the cascade all touch shared state.

---

## Query

Search the wiki and answer. Triggers: "what do I know about X", "summarise everything on Y", "compare A and B from my wiki".

1. Read `wiki/index.md` to find candidates, then full-text search `wiki/` for the topic's key terms **and their synonyms**. Never say the wiki has nothing until both the index and the full-text search come back empty, and say that you searched both.
2. Read what you found and synthesise.
3. Prefer wiki content over your own training knowledge. Cite with markdown links: `[Article Title](wiki/topic/article.md)`, project-root-relative in conversation.
4. Answer in the conversation. Write no files unless asked.

### Archiving an answer

Only when the user explicitly asks to archive or save the answer.

1. Write the answer as a new wiki page using `$ICM_HOME/interview-templates/wiki/archive.md.tmpl`. Rewrite the conversation citations to file-relative paths: `../topic/article.md` across topics, bare `article.md` in the same directory.
   - Sources: markdown links to the wiki articles you cited.
   - No Raw field. This content did not come from raw.
   - Filename from the query topic. Place it in the most relevant topic directory.
2. Always a new page. Never merge an archived answer into an existing article. It is synthesis, not source material.
3. Update `wiki/index.md`, prefixing the Summary with `[Archived]`.
4. Append to `wiki/log.md`:

```
## [YYYY-MM-DD] query | Archived: <page title>
```

---

## Lint

Three categories, three different authorities. Do not mix them.

### Safe fixes, applied by you, then reported

No script applies any of these. You run the search, you make the edit, and you say you did. There is no auto-fix script in this toolkit.

**Index consistency** — compare `wiki/index.md` against the actual files in `wiki/`, excluding `index.md` and `log.md`. Nothing in `scripts/` reads `wiki/index.md`, and the deep check deliberately skips it, so this whole sweep is yours:

- File exists, missing from the index → add a row with `(no summary)`. For Updated, use the article's metadata Updated date, or the Archived date for an archive page, and fall back to the file's modified time.
- Index row points at a file that does not exist → mark the row `[MISSING]`. Do not delete it. The user decides.
- Index row's Updated disagrees with the article's metadata → update the index to match the article.

**Internal links** — every markdown link in a wiki article, body and Sources, excluding Raw links and See Also links and excluding `index.md` and `log.md`:

- Target missing → search `wiki/` for a file with that name. Exactly one match, fix the path. Zero or several, report it.

**Raw references** — every link in a Raw field must resolve to an existing `raw/` file:

- Target missing → search `raw/` for that filename. Exactly one match, fix the path. Zero or several, report it.

**See Also** — inside each topic directory:

- Target missing → search `wiki/`. One match, fix it. Zero matches, remove the link, because a dead cross reference is not load-bearing. Several matches, report it.

`icm-check.sh --routes` will not find any of these for you. It walks only files literally named `CONTEXT.md`, so no link inside a wiki article is checked by any script.

### Mechanical reports, never fixed

The deep check is `scripts/check_evidence.py`. It is the **only** optional piece of this toolkit, and it is optional on purpose. It is report-only and never modifies a file.

Two ways to run it. Through the checker, which handles the guards for you:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --evidence .
```

That runs the script only when both `python3` and a `wiki/` directory are present, relays the first sixty lines of its report, and prints the skip explicitly when either is missing. Or run it directly when you want the full report or a narrowed scope:

```sh
if command -v python3 >/dev/null 2>&1; then
  python3 "$ICM_HOME/scripts/check_evidence.py" .
else
  echo "python3 not found: deep evidence check skipped"
fi
```

The first argument is the project root and it defaults to the current directory. Any further arguments are article paths, absolute or root-relative, which narrow the scope. The default scope is every `wiki/**/*.md` except `index.md` and `log.md`. It needs python3 3.10 or newer. The exit code carries no information; the report is the interface, so read it rather than testing the status.

It reports three things:

- **Source fidelity** — literals in an article that it could not find in the linked raws. These are *suspects, not verdicts*. Derived values, product names and deliberate paraphrase all surface here. Judge each one against the raw context and report only the real mismatches.
- **Evidence errors** — articles it cannot verify at all: no Raw field, Raw links that do not resolve, Raw links that escape `raw/`. Each one needs a decision, not a fix.
- **Unreferenced raw files** — files no article's Raw field points at. Anything logged as No material is excluded, so what is left is a genuine backlog.

**When python3 is absent, degrade explicitly and say so.** Do not pretend the check ran and do not skip it in silence. Instead:

1. Print `deep evidence check skipped: python3 not found` in the lint report.
2. Write the same note into the `wiki/log.md` lint line, so the gap is on the record.
3. Do the shallow version by hand instead: for each article touched in this session, confirm every Raw link resolves to an existing file, and grep the linked raws for the article's most load-bearing literal. `grep -F` on one number per article costs seconds and catches the worst class of drift.
4. Say plainly that the grounding invariant is currently resting on the compile-time locate-before-write rule alone.

The invariant does not weaken when the script is missing. Only the verification does, and the honest report is what keeps that distinction visible.

### Judgment reports, never fixed

Yours to spot, yours to propose, never yours to apply:

- Factual contradictions between articles.
- Claims superseded by a newer source but still presented without a Status block.
- Missing conflict annotation where sources disagree.
- Obviously missing cross references between related articles. Suggest them. Do not add them silently.
- Malformed Status blocks: Outdated with no date, either block with no explanation.
- Orphan pages with no inbound link from any other article.
- Missing cross-topic references.
- Concepts mentioned constantly with no page of their own.
- Archive pages whose cited articles have changed substantially since the snapshot.

### Post-lint

Append to `wiki/log.md`:

```
## [YYYY-MM-DD] lint | <N> issues found, <M> auto-fixed
```

Add `, deep check skipped (no python3)` to that line when it applies.

---

## Conventions

- Standard markdown, relative links throughout.
- `wiki/` allows one level of topic subdirectory. No deeper nesting.
- Inside `wiki/` files, every link is relative to the current file. In conversation output, use project-root-relative paths.
- Today's date for log entries, Collected dates and Archived dates. Updated reflects when the knowledge changed. Published comes from the source, `Unknown` when there is none.
- Ingest writes `wiki/index.md` and `wiki/log.md`. A no-material ingest writes only the log. Archiving writes both. Lint writes the log, and the index only when you fixed an index row. A plain query writes nothing.
- Never write "skills library". `_config/` holds rule books; a folder's own `CONTEXT.md` is a job card.

## What is machine enforced and what is judgment

Authority model: `$ICM_HOME/spec/authority-model.md`. Every row below was verified against the scripts in this checkout.

**Machine-enforced by `scripts/icm-check.sh`.** Each check has a flag of the same name, and `--only <id>` selects one by id.

| Check | check-id | What it verifies in a wiki workspace |
|---|---|---|
| Character budgets | `budgets` | Every `wiki/*.md` article except `index.md` and `log.md`, against the `wiki_article.md` ceiling in `icm.defaults.json` |
| Code fences | `fences` | Backtick and tilde fence counts are even in every `.md`, articles included |
| Placeholders | `placeholders` | No unfilled double-brace placeholder in live prose, outside any `*.tmpl` file and outside code fences and backticks |
| Workspace map drift | `drift` | `raw/` and `wiki/` appear in the fenced workspace map in `IDENTITY.md` |
| Grounding invariant, optional | `evidence` | Runs `scripts/check_evidence.py` when both `python3` and `wiki/` exist, relays its report, and reports the skip otherwise rather than counting it as a pass |

**Mechanical report, found by `scripts/check_evidence.py`, never fixed**

| Check | What the script does |
|---|---|
| High-signal literals in an article appear verbatim in its linked raws | Extracts quotes of fifteen characters or more, ISO dates and specific numbers, and looks for each one in the linked raw bodies |
| Articles with no Raw field, unresolvable Raw links, or Raw links escaping `raw/` | Reported as evidence errors, one decision each |
| Raw files no article references, minus the set logged as no material | Reported as inventory, a backlog rather than an error |

Every row in that table is a *report*. The script never edits a wiki file and neither do you on the strength of its output alone. A fidelity suspect is a question to answer, not a fact to correct.

**Not checked by anything.** Say so rather than implying a machine is watching.

- Whether `wiki/index.md` agrees with the files on disk. Nothing in `scripts/` reads the index, and `check_evidence.py` skips `index.md` and `log.md` by design. The index sweep in this file is yours.
- Any link inside a wiki article. `icm-check.sh --routes` walks only files named `CONTEXT.md`.
- The one-level nesting rule under `wiki/` and `raw/`. You check it with `find -type d` or nobody does.
- The compile-time locate-before-write rule. No script watches you write. It is the grounding invariant's only load-bearing enforcement, and it is instruction, not machinery. Treat it accordingly.

**Judgment, yours, always a proposal**

- The triage disposition: New, Update, Disputed, No material.
- Whether a topic directory should be reused or created.
- Whether two claims genuinely contradict, or only look like it.
- Whether a suspect from the deep check is a real mismatch or a derived value.
- Which articles a new source materially affects, for the cascade.
- Whether a concept has earned its own page.
- The wording of every Status block.
