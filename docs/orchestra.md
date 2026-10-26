# ICM Orchestra

The human guide to selecting and starting a compatible workflow. [`../spec/ORCHESTRA.md`](../spec/ORCHESTRA.md) owns the parsed graph, numbering, capability, and scope rules. [`../spec/CLI-CONTRACT.md`](../spec/CLI-CONTRACT.md) owns flags, output envelopes, and exit codes. Those specifications are the machine authority; this page does not replace them.

## What Orchestra does

Orchestra reads the context files already in a project and answers three different questions:

- **Structural mode:** are the cards, typed routes, numbering, capabilities, and scope declarations coherent?
- **View mode:** what workflow and knowledge projections can be derived from those files right now?
- **Strict mode:** is one selected job ready to start, or what structured input, capability, route, scope, or ambiguity finding remains?

All three modes are report-only. They derive fresh answers and write nothing inside the target workspace. Orchestra is not a supervisor process, daemon, scheduler, sandbox, or agent runtime. It does not spawn work, watch a process, approve an external action, or keep a second state store.

`RUN` means the selected job is ready to start. It does not mean the job ran, the output is correct, or an external action is approved.

## One repository is the brain and workspace

Your own project repository holds `IDENTITY.md`, routing cards, job cards, rule books, sources, knowledge, outputs, and logs. That repository is the only brain and workspace. The toolkit reads it in place.

Local execution and GitHub distribution use the same files. Run locally against a checkout, then commit and distribute that checkout through GitHub if you want versioned collaboration. A collaborator clones the same files and runs the same checks. There is no export step, second brain repository, live mirror, required cloud service, database, or telemetry path.

The toolkit installation is tooling, not another brain. Keep its scripts in the toolkit clone or plugin root and point `ICM_HOME` there. Cloud execution is a separate optional runner that may be evaluated later; it is not required and is not part of this local contract.

## Run the public example

Resolve the toolkit root once. The target is the example workspace, while the scripts remain in the toolkit.

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

From the toolkit root, run structural validation:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra examples/orchestra-pipeline
```

`--only orchestra` selects the same structural mode. Generic checks and explicit `--all` do not select Orchestra implicitly.

Generate the read-only Markdown view:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra-view examples/orchestra-pipeline
```

The example's `00-intake` card declares external `@request`. Its public-safe request has already been materialised at `00-intake/output/example-request.md`, so this is the canonical strict intake command:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job 00-intake/CONTEXT.md --input request=00-intake/output/example-request.md examples/orchestra-pipeline
```

The positive stages consume declared prior outputs. Their materialised example artifacts support direct strict checks:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job 01-research/CONTEXT.md examples/orchestra-pipeline
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job 02-draft/CONTEXT.md examples/orchestra-pipeline
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job 03-review/CONTEXT.md examples/orchestra-pipeline
```

The draft and review cards declare `Skill | icm-orchestra | 1.0.0`, so their strict checks also prove that the installed skill name and version match. No tool attestation is needed by this example.

## A cold start, in order

A cold agent can enter a compatible repository without a prior conversation:

1. Read the target's `IDENTITY.md` and root `CONTEXT.md`.
2. Select exactly one job by its full workspace-relative card path. Do not select by a numeric prefix alone.
3. Run structural mode. Fix or report structural findings before selection.
4. Confirm required external input is already materialised as ordinary workspace data. If it is absent, stop: only a separately authorised setup step may create it, before preflight. Preflight and `MISSING` never materialise or write input.
5. Bind the existing material with `--input`, then run literal `--orchestra --job "$CARD"` strict preflight with every required binding and attestation. Do not paste inline content or credentials into a binding.
6. On `MISSING`, do not execute or write. Relay the structured type, path, and detail. Any further materialisation needs a separately authorised setup step before another preflight.
7. On `RUN`, execute only the selected job. Read its declared Inputs, write its declared Outputs, and append Session Close entries to the existing ledger after execution. Report placement proposals for separate human handling and preserve every human approval gate.
8. Judge the resulting artifact separately. Preflight did not execute it and cannot grade it.

The view is useful when selection is unclear because it exposes the same freshly parsed graph rather than asking the agent to reconstruct it mentally.

## Intake and external inputs

`00-intake` is optional when converting a legacy pipeline. When present, that exact name is reserved, the card is first in its pipeline's routing order, and it performs intake rather than ordinary domain work.

Only a pipeline's `00-intake` Inputs table may declare an external `@NAME`. A strict `--input NAME=PATH` binding names an already materialised, readable, nonempty file or qualifying directory inside the target. The checker does not copy, create, edit, or accept inline content. Positive stages consume declared workspace artifacts instead of accepting new external bindings.

The example intentionally ships both sides of that handoff: the external request file for binding and the intake brief that `01-research` consumes.

## Typed edges replace blanket one-way doctrine

Files still hand off through declared paths, but the relationship is explicit:

| Edge | Human meaning | Main constraint |
|---|---|---|
| `LOAD` | a prerequisite must be available before the dependent job | the `LOAD` projection is acyclic |
| `NEXT` | normal forward control flow | reachability and cycles are checked in this projection independently |
| `REWORK` | intentional backward repair | the destination is earlier in routing-table order |

Inputs and routing-card Load first references can produce `LOAD` dependencies from unique declared outputs. An explicit `LOAD` row names a prerequisite directly. `LOAD` is not a routing hop.

A forward `NEXT` beside a backward `REWORK` is a legal repair pair, not a combined-graph cycle. Routing-table order, not numeric order alone, decides whether repair points backward.

Ordinary Markdown links outside workflow fields form a separate knowledge projection. Knowledge cycles, orphans, and backlinks are informational and do not turn an otherwise ready job into `MISSING`.

## Generated views and backlinks

Every invocation rebuilds workflow and knowledge projections from the current cards and Markdown links. View mode shows forward edges and sorted inverse indexes for both projections. It never reads or writes a stored graph, backlink index, cache, ledger, or sentinel in the target.

The root `CONTEXT.md` in the example carries an on-demand `--orchestra-view` command instruction. This replaces a hand-maintained workflow or backlink index, which would become a second copy of derived truth.

The knowledge contents page and the learning index have different jobs. `wiki/index.md` points people to compiled articles. `_log/SKILL-INDEX.md`, when the loop generates it, summarises learning evidence. Neither is an Orchestra graph store.

## Four layouts and nested workspaces

Orchestra recognises these stage layouts:

| Layout | Routing card | Stage job card |
|---|---|---|
| Root direct | `CONTEXT.md` | `NN-slug/CONTEXT.md` |
| Root stages | `CONTEXT.md` | `stages/NN-slug/CONTEXT.md` |
| Department direct | `DEPARTMENT/CONTEXT.md` | `DEPARTMENT/NN-slug/CONTEXT.md` |
| Department stages | `DEPARTMENT/CONTEXT.md` | `DEPARTMENT/stages/NN-slug/CONTEXT.md` |

Pipeline identity combines the nearest routing card with the physical stage container. The same prefix can therefore be legal in separate pipelines. A directory with its own `IDENTITY.md` is a nested workspace: the outer walk excludes that subtree, and you check it independently by naming it as the target.

The public example uses root direct layout. The other three layouts use the same card grammar and graph rules rather than different runtimes.

## Numbering, insertion, and rename

Full workspace-relative paths are identity. Numeric prefixes help filing and ordering; routing-table order is execution authority.

Positive stages use `01` through `99` with lowercase slugs. Gaps are legal, and positive stages need not appear in numeric order. Duplicate prefixes are invalid inside one pipeline and legal across different pipelines.

Stage creation and renumbering remain conversational and human-confirmed. `after:00` means the first positive stage, whether or not an intake card exists. Other insertion targets must identify one existing stage in the selected pipeline. There is no automatic renumber script and no operation renames `00-intake`.

A standalone slug rename applies only to a positive stage and preserves its prefix. Insertion and rename require the full path-change map, reference inventory, explicit confirmation, and reference repair described by the specifications and skill guidance.

## Scope and No touch

Inputs declare read scope. Outputs declare write scope. `No touch` declares neither read nor write access, with overlap decided on path-component boundaries.

The checker validates existing input material, output types and parents, workspace escapes, absolute paths, and symlink components. An absent output can be valid only when its real parent already exists and is writable; preflight never creates that parent. Global `never_write` rules apply to Outputs only.

Strict preflight is not a sandbox around later execution. The selected agent must still honour the declared scope, and human approval remains necessary for external actions.

## Capability declarations and attestations

Preflight rows use `None`, `Tool`, `Skill`, or `No touch`.

- `None | - | -` is the explicit empty capability declaration and stands alone.
- A Tool requires both `command -v NAME` and a strict `--tool-version NAME=VERSION` attestation exactly equal to the card's version string.
- A Skill resolves from the workspace first, then the toolkit, and must have matching `name:` and exact `version:` metadata.
- A No touch row names a safe workspace-relative path and uses `-` in its Version cell.

The general Tool attestation shape is:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job "$CARD" --tool-version "$TOOL_ATTESTATION" .
```

Set `CARD` to the full workspace-relative job card and `TOOL_ATTESTATION` to `NAME=VERSION` with the trusted actual tool version. The checker compares the attested string; it does not run `NAME --version`, evaluate a version range, or execute a command named by the card. Unrelated third-party skills do not gain a version requirement merely because Orchestra exists.

## Deterministic reports and exits

Structural, view, and strict modes use one parser and freshly derived graph. Paths in their reports are workspace-relative, records are sorted, and output contains no target-specific absolute path, temporary path, timestamp, or mirror-specific default. Repeated runs and mirrored clones can therefore be compared byte for byte.

At the human level, exit 0 means structural clean, view clean, or strict `RUN`; exit 1 means structural findings, view findings, or strict `MISSING`; exit 2 means usage or environment refusal. The exact envelopes and missing types are owned by [`../spec/CLI-CONTRACT.md`](../spec/CLI-CONTRACT.md), not paraphrased into a second machine contract here.

## Claims need runs, not invented percentages

Use executed fixtures, real strict runs, mirrored clones, and cold-start transcripts as evidence. Record what actually ran and what was not exercised. Do not publish a speed, accuracy, adoption, or token-saving percentage without a benchmark that supports that exact claim. This guide makes no such percentage claim.

Start with [`../examples/orchestra-pipeline/`](../examples/orchestra-pipeline/), then use the two specifications above when a precise parsing or output question matters.
