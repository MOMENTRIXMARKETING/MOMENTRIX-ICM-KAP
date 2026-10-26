# examples

Four worked instances. Each one is a real workspace on disk, not a description of one, and each passes `scripts/icm-check.sh` clean.

Read an example when a spec sentence is clear but the shape it produces is not.

| Example | Archetype | Shows |
|---|---|---|
| [`raw/`](raw) and [`wiki/`](wiki) | `wiki` | one source capture and the article compiled from it, the grounding invariant end to end |
| [`architect-company/`](architect-company) | `quick`, extended into Pattern 24 | a three department company where the folders are the workers |
| [`content-pipeline/`](content-pipeline) | `full` | a staged pipeline that hands off through files |
| [`orchestra-pipeline/`](orchestra-pipeline) | `wiki`, extended with Orchestra | reserved intake, typed workflow edges, strict preflight, and an evidence-based final report |

Archetype names are the ones `icm-plan.sh --archetype` takes. `spec/CLI-CONTRACT.md` owns them.

## raw and wiki: the evidence pair

The smallest thing this methodology asserts: every load bearing fact in a compiled article exists word for word in an immutable source the article links to.

[`raw/2026-08-30-icm-defaults-budgets.md`](raw/2026-08-30-icm-defaults-budgets.md) is layer 4a, captured once and never edited. [`wiki/icm-defaults-budgets.md`](wiki/icm-defaults-budgets.md) is layer 4b, compiled from it, carrying a Raw line that points back. `scripts/check_evidence.py` verifies the link when python3 is present.

## architect-company: Pattern 24 worked

Riverbend Supply, a three person tool hire business with finance, sales and marketing. Start at [`architect-company/IDENTITY.md`](architect-company/IDENTITY.md), then [`ARCHITECT.md`](architect-company/ARCHITECT.md).

What it demonstrates, and each of the four corrections in `spec/CONVENTIONS.md` Pattern 24:

- **The folders are the agents.** A department is a folder with a job card, its own rule books, its own reports and its own numbered stages. Nothing sits above them.
- **`ARCHITECT.md` is a layer 2 job card for the root folder, not a new layer.** It has the same five sections every job card has. The stack is still 0, 1, 2, 3, 4a, 4b.
- **Reports are append only.** Each department writes into its own `reports/` under the run date and a slug. `report.md` holds one link at the newest and nothing else. Read [`finance/reports/`](architect-company/finance/reports) in date order to see a later report reading an earlier one instead of replacing it.
- **`status.md` is compiled and never authoritative.** [`status.md`](architect-company/status.md) says so in its own body. The architect report for 2026-08-29 shows the rule in use: the rollup said one thing, the agent opened the folder to confirm it.
- **The architect does small floor work itself and logs it.** The floor is written down in [`_config/conventions.md`](architect-company/_config/conventions.md), in words, so it is not re-argued each morning. [`reports/2026-08-29-architect-day.md`](architect-company/reports/2026-08-29-architect-day.md) carries a table of the below floor jobs it did rather than spawning for.

It also shows layers 1 to 3 recursing: the company has `_config/`, and so does every department, and a department rule book binds only inside that department.

## content-pipeline: the full archetype worked

Explainer Desk, a two person desk that turns one reader question into a five minute narrated video. Start at [`content-pipeline/CONTEXT.md`](content-pipeline/CONTEXT.md).

What it demonstrates:

- **One stage, one job.** [`01-research`](content-pipeline/01-research) sources, [`02-script`](content-pipeline/02-script) writes, [`03-production`](content-pipeline/03-production) plans shots. None of them does another's work.
- **Handoff through `output/` folders.** This legacy example shows the normal forward chain: each stage reads the prior stage's output, and a human can edit that file before the next stage starts. Orchestra makes the relationship explicit instead of treating one-way flow as universal: Inputs create `LOAD` dependencies, `NEXT` carries forward flow, and `REWORK` permits declared backward repair.
- **Job cards carry Purpose, Inputs, Process, Outputs and Routing.** Two of them also carry the optional sections: a checkpoint in `01-research`, an audit in `02-script` and `03-production`.
- **Selective section routing.** Inputs tables name the section of a rule book, not just the file.
- **Rule books over outputs.** `_config/` says how to build. An `output/` file is an artifact, never a template.

One worked run is on disk end to end, slug `why-bread-goes-stale`: a brief with a claim table, a script whose every beat names the brief row it rests on, a shot list, and the [assembled package](content-pipeline/output/why-bread-goes-stale-package.md). The open questions the research could not settle are carried all the way through to delivery rather than smoothed over.

The subject matter is illustrative. The source rows in the brief name the kind of source a researcher opened, because this example ships without a source library. In a live run each row carries the edition and the page.

## orchestra-pipeline: typed flow and strict preflight

A public-safe fictional bicycle workshop turns one request into a small evidence-based orientation report. Start at [`orchestra-pipeline/IDENTITY.md`](orchestra-pipeline/IDENTITY.md), then [`orchestra-pipeline/CONTEXT.md`](orchestra-pipeline/CONTEXT.md). The human guide is [`docs/orchestra.md`](../docs/orchestra.md).

What it demonstrates:

- **Reserved intake and binding.** [`00-intake/CONTEXT.md`](orchestra-pipeline/00-intake/CONTEXT.md) declares external `@request`. The public-safe [`example-request.md`](orchestra-pipeline/00-intake/output/example-request.md) is already materialised for `--input`, and [`request-brief.md`](orchestra-pipeline/00-intake/output/request-brief.md) is the declared intake handoff.
- **Full-path identity and typed edges.** Root routing order is explicit. The cards use `LOAD`, `NEXT`, and `REWORK`, including a legal forward and repair pair in `02-draft`.
- **Capabilities and scope.** Intake and research declare `None`. Draft and review declare versioned `icm-orchestra` skills and a `No touch` boundary. Inputs and outputs are real files, so strict runs can check actual scope.
- **Evidence and central learning.** Immutable public-safe captures sit in `raw/workshop/`; [`wiki/workshop/orientation.md`](orchestra-pipeline/wiki/workshop/orientation.md) links both. The wiki log and central `_log/` files record the worked example.
- **A complete handoff chain.** Every positive stage consumes a declared prior output. The last one is [`final-report.md`](orchestra-pipeline/03-review/output/final-report.md), with evidence ids retained beside each claim.

The root routing card carries an on-demand `--orchestra-view` instruction. Workflow and knowledge backlinks are derived when requested, never maintained as a second handwritten index.

## Running the checker

Stand in the repo root and point `ICM_HOME` at it, the same way `README.md` does for the toolkit's own self-check. Run the generic checks on each complete workspace:

```sh
ICM_HOME=$(pwd)
sh "$ICM_HOME/scripts/icm-check.sh" examples/architect-company
sh "$ICM_HOME/scripts/icm-check.sh" examples/content-pipeline
sh "$ICM_HOME/scripts/icm-check.sh" examples/orchestra-pipeline
```

Add `--only <id>` to run one generic check, for example `--only routes`.

The evidence pair is checked as part of the repo itself, because `raw/` and `wiki/` here are folders of this repo rather than a workspace root of their own:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" .
```

Run Orchestra explicitly for structural validation and the deterministic view:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra examples/orchestra-pipeline
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra-view examples/orchestra-pipeline
```

The canonical strict intake command binds the materialised public-safe request. The positive stages need no input bindings because their prior outputs are already present:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job 00-intake/CONTEXT.md --input request=00-intake/output/example-request.md examples/orchestra-pipeline
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job 01-research/CONTEXT.md examples/orchestra-pipeline
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job 02-draft/CONTEXT.md examples/orchestra-pipeline
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job 03-review/CONTEXT.md examples/orchestra-pipeline
```

`RUN` means ready to start. It is not a completion claim or approval for an external action.

A worked example is a test. If you change the shape the specs describe, one of these stops being clean, and that is the point of shipping them.

## Why the checker grades these correctly

`architect-company`, `content-pipeline`, and `orchestra-pipeline` each carry their own `IDENTITY.md`, which makes each one a workspace root nested inside this repo. The checker reads that: a `CONTEXT.md` sitting beside an `IDENTITY.md` is layer 1, graded against the root budget and the root section list, and the tree under it is mapped by its own `IDENTITY.md` rather than by this repo's. Every number in that sentence lives in `icm.defaults.json`.
