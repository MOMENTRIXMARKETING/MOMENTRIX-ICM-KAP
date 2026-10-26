# ICM Orchestra Contract

This is the binding structural, graph, capability, scope, and preflight contract for ICM Orchestra. `spec/CLI-CONTRACT.md` owns the command line and output envelopes. This file owns what the checker parses and what its answers mean.

The end user's repository is the only brain and workspace. Orchestra reads it in place. GitHub can mirror that same repository for versioned distribution and collaboration; it is not a second brain, a second live master, or a required service.

## 1. Non-negotiable behavior

1. Orchestra is part of `scripts/icm-check.sh`. There is no sixth runtime script.
2. Structural, view, and strict modes use one parser and one freshly derived graph. None reads or writes a stored graph or backlink index.
3. Every Orchestra mode is report-only. It creates no `.icm`, plan, graph, backlink, cache, ledger, sentinel, or other target file. Temporary parser storage lives outside the target and is removed on exit.
4. `RUN` means the selected job is ready to start. It does not mean the job completed, its output is correct, or an external action is approved. Human approval gates remain unchanged.
5. POSIX `sh` is mandatory. Python 3.10 or newer remains optional and is never required for Orchestra.
6. Existing generic checks keep their behavior unless this contract explicitly adds the `## Preflight` exclusion or the non-failing depth note to `routes`.
7. Full workspace-relative paths are identity. Numeric prefixes are filing and ordering aids only. Routing-table order is execution authority.

## 2. Workspace and pipeline discovery

The target is the workspace root. Its `IDENTITY.md` is layer 0 and its root `CONTEXT.md` is the first routing card.

A directory below the target with its own `IDENTITY.md` is a nested workspace. The outer walk excludes that entire subtree, including its cards, outputs, skills, and knowledge links. Each nested workspace is checked independently by naming it as the target. The target's own root is not nested inside itself.

Orchestra recognises exactly these four stage layouts:

| Layout | Routing card | Stage job card |
|---|---|---|
| Root direct | `CONTEXT.md` | `NN-slug/CONTEXT.md` |
| Root stages | `CONTEXT.md` | `stages/NN-slug/CONTEXT.md` |
| Department direct | `DEPARTMENT/CONTEXT.md` | `DEPARTMENT/NN-slug/CONTEXT.md` |
| Department stages | `DEPARTMENT/CONTEXT.md` | `DEPARTMENT/stages/NN-slug/CONTEXT.md` |

`DEPARTMENT` may be a nested non-workspace directory path. A directory containing a department `CONTEXT.md` is a department, not a stage, unless its own basename and position match one of the four stage layouts.

Pipeline identity is the pair of:

1. the nearest routing `CONTEXT.md`, which is the target root or a department card; and
2. the physical stage container, which is the routing card's directory or its direct `stages/` child.

Consequences:

- Root direct and root `stages/` are different pipelines.
- Two departments are different pipelines even when their directory names or stage prefixes match.
- Department direct and department `stages/` are different pipelines.
- A stage belongs to exactly one pipeline. A card outside the four layouts is not silently promoted to a stage.
- Duplicate prefixes are invalid inside one pipeline and legal across different pipelines.

## 3. Card grammar

### 3.1 Generic sections remain unchanged

A stage job card still has the five generic required sections from `icm.defaults.json`: Purpose, Inputs, Process, Outputs, and Routing. Orchestra adds `## Preflight` to Orchestra cards. It does not make Preflight a generic required section and does not change the generic frontmatter contract.

Root and department routing cards keep their generic role. Their Orchestra `## Routing` table has a trailing `Edge` column:

```markdown
| Job | Where | Load first | Edge |
|---|---|---|---|
| Intake the request | `00-intake/CONTEXT.md` | - | NEXT |
```

A stage Routing table also has a trailing `Edge` column:

```markdown
| When | Go to | Edge |
|---|---|---|
| Brief accepted | `01-draft/CONTEXT.md` | NEXT |
| Repair the brief | `00-intake/CONTEXT.md` | REWORK |
| Stop here | - | - |
```

The header and separator rows are not data. A data row with an empty destination is malformed. A destination of `-` is non-path prose and must have edge `-`; it creates no edge. Any other destination is path-bearing and requires exactly `LOAD`, `NEXT`, or `REWORK`. A missing Edge column, `-` on a path-bearing row, or any other edge word is an Orchestra finding. Generic checks do not infer an edge type and continue to accept the untyped legacy form.

### 3.2 Inputs, Outputs, and Load first

The existing table shapes stay in use:

```markdown
## Inputs

| Source | File | Scope | Why |
|---|---|---|---|
| Brief | `intake/brief.md` | full file | the requested work |

## Outputs

| Artifact | Location | Format |
|---|---|---|
| Draft | `output/draft.md` | Markdown |
```

The reference is the File cell in Inputs, the Location cell in Outputs, and the Load first cell in a root or department Routing row. An empty reference table declares no references. A single row whose reference cell is `-` also declares no reference. Any other content is a reference, including plain prose. It is not exempt merely because it lacks backticks or Markdown link syntax.

A reference may be written as a backticked path, a Markdown link, or a bare cell. For a Markdown link, the destination is the reference and the label is not. A cell holding multiple references separates them with commas. A comma inside a Markdown link label does not split the cell. No other prose is a separator. This grammar is deliberately small so paths containing spaces remain intact.

An external input is written `@NAME`. It is a bindable input leaf, not inline content. It is valid only in the Inputs table of that pipeline's `00-intake` card. External inputs are forbidden in Outputs, Load first, Routing destinations, and every positive stage.

### 3.3 Preflight and capabilities

An Orchestra stage card adds one Preflight table:

```markdown
## Preflight

| Kind | Reference | Version |
|---|---|---|
| Tool | git | 2.39.2 |
| Skill | icm-stage | 1.0.0 |
| No touch | .git/ | - |
```

The valid kinds are exactly `Tool`, `Skill`, `No touch`, and `None`.

- `None | - | -` is the explicit empty declaration. It must be the only data row.
- Tool and Skill rows require nonempty Reference and Version cells. Version is an exact string, never a range.
- A No touch row requires a nonempty workspace-relative Reference and Version `-`.
- Unknown kinds, duplicate declarations for the same kind and reference, malformed rows, and a None row beside any other row are `CAPABILITY` findings, except an unsafe No touch path, which is `SCOPE`.
- An unrelated third-party skill does not need a `version:` key. Version metadata is required only when an Orchestra card declares that skill.

## 4. Reference resolution and ambiguity

All paths in reports are normalised workspace-relative paths. Absolute paths, workspace escapes, empty path components created only to hide `..`, and symlink components are scope errors, not alternative candidates.

For a safe reference, the parser independently forms:

1. a file-relative candidate, relative to the directory of the referring Markdown file; and
2. a root-relative candidate, relative to the workspace target.

`./` and interior `.` components are removed. `..` is resolved lexically only while it remains inside the target. The two candidates are compared after normalisation. Two spellings of the same normalised path are one physical candidate, not two.

Resolution rules depend on the field:

- A Routing destination must exist. Zero candidates is `ROUTE`. Two distinct candidates is `AMBIGUOUS`.
- An existing input with two candidates is `AMBIGUOUS`. An absent input is a strict `INPUT` finding after producer matching, not a structural reason to prevent graph display.
- An output may be absent. A candidate is viable when it exists or its parent already exists. Zero viable candidates is `SCOPE`. Two distinct viable candidates is `AMBIGUOUS`.
- A knowledge link is not a workflow route. The generic `links` check remains responsible for dead-link enforcement.

A duplicate declaration of the same candidate is still a duplicate declaration and returns `AMBIGUOUS`; deduplication of two spellings must not hide repeated route rows or path claims.

Task labels are normalised by trimming leading and trailing whitespace, collapsing each internal whitespace run to one ASCII space, and folding ASCII uppercase to lowercase with `LC_ALL=C`. Two rows in one Routing table with the same normalised label are `AMBIGUOUS`, even when their destinations differ. Labels in different routing tables do not collide merely because they match.

Duplicate route rows, ambiguous route chains, duplicate path candidates, and multiple producers are all `AMBIGUOUS`. Two rows in one card with the same source, destination, and edge type are duplicate routes even when their labels differ. The checker never picks the first candidate to make a workspace look ready.

## 5. Typed workflow graph

### 5.1 Edge construction

The workflow graph is rebuilt from cards on every run.

- `NEXT` points from the card containing the Routing row to its destination card.
- `REWORK` points from the card containing the Routing row to its destination card, but is valid only when the destination is earlier in the selected pipeline's routing-table order.
- An explicit `LOAD` row names a prerequisite in its destination. The edge points from that prerequisite to the card containing the row.
- A stage Inputs reference produces a producer-derived `LOAD` edge when exactly one stage Outputs declaration owns it. The edge points from the producer stage to the consuming stage.
- A root or department Load first reference produces a dependency for the job named by that row. A unique producer points to that destination job. If the Load first reference itself resolves to a job card, that job is the prerequisite.
- With no producer, an input is an external input leaf. It creates no producer edge. Multiple producers are `AMBIGUOUS`.

Output ownership is lexical and uses path-component boundaries. An Outputs declaration owns an input when both resolve to the same path, or when the declaration is a directory that contains the input. Nested or identical declarations that both own one input are multiple producers. Ownership is derived before checking whether the input has been materialised, so a missing handoff still has the right graph and then returns `MISSING INPUT` in strict mode.

LOAD edges point prerequisite to dependent everywhere, including in the view and inverse index. The checker never reverses an edge merely to make a cycle look impossible.

### 5.2 Independent projections and cycle rules

- The LOAD projection must be acyclic. Inputs and Load first participate through producer-derived edges, so real output-handoff cycles are detectable without any explicit LOAD row.
- The NEXT projection is checked independently for cycles. NEXT plus REWORK is not converted into a LOAD cycle.
- REWORK is explicit backward repair flow. It must target an earlier card in routing-table order, not merely a card with a smaller numeric prefix. A forward REWORK is a `REWORK` finding.
- Reachability from each pipeline's nearest routing card uses NEXT only. A stage reachable only through LOAD or REWORK is unreachable and returns `ROUTE`.
- LOAD references are never routing hops.

Structural findings use the codes `CARD`, `NUMBERING`, `ROUTE`, `LOAD`, `NEXT`, `REWORK`, `INPUT`, `CAPABILITY`, `SCOPE`, and `AMBIGUOUS`. Strict mode maps these only to its public missing types: INPUT, CAPABILITY, ROUTE, SCOPE, and AMBIGUOUS. CARD, NUMBERING, LOAD, NEXT, and REWORK map to ROUTE. Existing AMBIGUOUS stays AMBIGUOUS rather than being hidden behind a generic route error.

## 6. Depth

Depth describes nested routing levels after `IDENTITY.md`:

| Card | Depth |
|---|---|
| Target root `CONTEXT.md` | 1 |
| Department `CONTEXT.md` | 2 |
| Stage job card | 3 |

A fourth nested routing card below a stage is too deep. Inputs and output loads do not add depth. NEXT between sibling stages does not add a nesting level; otherwise an ordinary multi-stage pipeline would be impossible.

The generic `routes` check reports a non-failing `note` when resolving a route would require a fourth nested context card. It still exits 0 when all legacy targets exist. Structural Orchestra emits a `DEPTH` note for that card. Strict preflight for a job whose selection requires that fourth card returns `MISSING ROUTE`. Generic legacy checks do not reject recursion.

## 7. Numbering, insertion, and rename

### 7.1 Stage names and order

A positive stage basename is `NN-slug`, where `NN` is `01` through `99` and slug is one or more lowercase ASCII alphanumeric groups separated by single hyphens. Gaps are legal. Positive stages need not appear in numeric order because routing-table order is authoritative.

`00` is optional in a legacy conversion and reserved whenever present:

- The basename is exactly `00-intake`.
- It is first in its pipeline's Routing table.
- It is used for intake and preflight, not ordinary domain work.
- There is at most one per pipeline.
- Its Inputs table is the only place that may declare external `@NAME` inputs.
- Append numbering ignores it and begins at `01`.

A misordered, duplicated, or differently named `00` card is `NUMBERING`. Duplicate positive prefixes in one pipeline are also `NUMBERING`.

### 7.2 Conversational insertion

Stage creation and renumbering remain conversational and human-confirmed. There is no automatic renumber script.

`after:00` is a sentinel meaning the first positive stage. It is valid with or without an actual `00-intake`, and the new positive stage always goes after any existing intake. Any other `after:NN` target must exist uniquely in the selected pipeline. Insertion shifts only higher positive prefixes in that pipeline.

A missing or ambiguous target stops before any write. Exhaustion after `99` stops for human direction. Duplicate prefixes in other departments and other pipelines are untouched. No operation changes `00-intake`.

### 7.3 Standalone positive-slug rename

A standalone slug rename applies only to positive stages. It preserves `NN` and the new slug must satisfy the same slug grammar. It never renames `00-intake`.

Insertion and rename use the same full old/new path map, reference inventory, explicit human confirmation, highest-first collision rollback, and map repair protocol. Reference repair covers Inputs, Outputs, Load first, Routing destinations, and knowledge links. Immutable raw files and append-only history are never rewritten during reference repair.

## 8. Capability and input preflight

### 8.1 Tools

A Tool is ready only when both are true:

1. `command -v NAME` finds the tool; and
2. strict mode received `--tool-version NAME=VERSION` and the attested string is exactly equal to the card's Version cell.

There is no version-range evaluation and no implicit call to `NAME --version`. The checker never executes a tool or command string named by a card. A tool name containing a slash, whitespace, or shell metacharacters is unsafe and is not executed or looked up as a command string. Missing tools, missing or unequal attestations, and unsafe tool declarations return `CAPABILITY`.

### 8.2 Skills

Skill resolution tries the workspace's `skills/NAME/SKILL.md` first, then `$ICM_HOME/skills/NAME/SKILL.md`. The selected file must be safe, have frontmatter `name:` exactly equal to NAME, and have `version:` exactly equal to the card's Version cell.

A missing skill, a name mismatch, a missing version, or a version mismatch returns `CAPABILITY`. An absolute path, workspace escape, or symlink component in a skill path returns `SCOPE`. Workspace precedence must be observable: the home copy is never allowed to repair a mismatch in the workspace copy.

### 8.3 Bound inputs

`--input NAME=PATH` binds one external `@NAME` to an already materialised workspace input. The binding does not copy, create, edit, or accept inline content. It never accepts credentials as content.

The bound PATH follows the same workspace-relative scope, file, directory, and symlink rules as a direct Inputs reference. An unbound external input, a binding to a missing or unreadable path, and a binding left needed by another job return `INPUT`. An external input outside `00-intake` is an `INPUT` finding even if a binding was supplied.

## 9. Scope and path safety

### 9.1 Inputs and outputs

Inputs define read scope. Outputs define write scope.

- An input file must exist, be a regular non-symlink file, be readable, and be nonempty.
- An input directory must exist, be a real non-symlink directory, and contain at least one readable regular file whose basename is not `.gitkeep`. The search may descend through real subdirectories but never follows symlinks.
- An output file may be absent. Its parent must already exist as a real directory and be writable. The checker never creates that parent.
- An existing output file must be a regular writable non-symlink file.
- A trailing `/` declares an output directory. An existing output directory must be real and writable. An absent output directory follows the same existing-parent rule as an absent output file.
- Existing output type must match the declaration. A file is not accepted for a directory declaration or vice versa.
- Empty existing output files and directories are allowed. Outputs do not have the input nonempty rule.

Missing input material returns `INPUT`. Output parent, type, permission, and scope failures return `SCOPE`.

### 9.2 No touch and never_write

`No touch` means no read and no write. Overlap is tested on path-component boundaries, never string prefixes. `private/` overlaps `private/x.md` and does not overlap `private-old/x.md`.

An Input or Output that overlaps a No touch path in the selected job returns `SCOPE`. The overlap decision precedes any attempt to read the input. A No touch declaration that is absolute, escapes the workspace, or contains a symlink component also returns `SCOPE`.

Global `never_write` entries from the merged `icm.defaults.json` apply to Outputs only. They do not implicitly create read restrictions on Inputs.

Absolute scoped paths, workspace escapes, and any symlink component in a scoped path return `SCOPE`. This includes internal symlinks, escaping symlinks, dangling symlinks, and symlinks in an existing parent. Lexical normalisation must not require `realpath`, `readlink -f`, `stat`, Python, or `sort -V`.

Paths containing spaces are ordinary paths. A leading dash is data, not an option. Prefix lookalikes outside the workspace do not count as inside it.

## 10. Knowledge projection and inverse indexes

References inside Inputs, Load first, and Routing destination fields are workflow references regardless of Markdown syntax. They never become knowledge edges merely because they use `[label](path)` form.

Ordinary Markdown links elsewhere form the separate knowledge projection. Fenced code and inline code examples are not links. Knowledge edges are derived independently from workflow edges on every run.

The view exposes both forward edges and sorted inverse projections:

- Workflow Backlinks answer which cards point into a card, with the edge type preserved.
- Knowledge Backlinks answer which Markdown files link into a target.

Knowledge cycles, knowledge orphans, and backlinks are informational. They never change structural or view exit status and never turn strict `RUN` into `MISSING`. A knowledge cycle beside a LOAD cycle must not hide the LOAD finding. An ordinary link between two cards does not create a NEXT or LOAD cycle.

`GRAPH.md`, `BACKLINKS.md`, and duplicate handwritten Pipeline or backlink tables are not generated or checked in. The front or root `CONTEXT.md` exposes the view through a command instruction containing `--orchestra-view`, never through a Markdown link whose destination is a flag.

## 11. Generated bodies and budgets

`icm_body_context_root`, `icm_body_raw_context`, `icm_body_output_context`, and route-row generation change together.

For quick, full, and wiki:

- Generated Routing tables carry the typed trailing Edge column.
- Generated root text includes the literal command instruction `sh "$ICM_HOME/scripts/icm-check.sh" --orchestra-view .`.
- Generated text does not create or reference `GRAPH.md`, `BACKLINKS.md`, or a duplicate handwritten Pipeline or backlink table.
- Generated raw and output job cards carry a valid Preflight table, typed Routing rows, and resolvable scope declarations.
- Generated Session Close bytes are unchanged.
- Scripts still never read interview templates.
- Existing budgets and line ceilings stay in `icm.defaults.json` and are not raised to make the new rows fit. Generated bodies must satisfy the existing `budgets` check.

The four generated-body concerns are tested together: typed routing, Preflight, the view instruction, and the existing byte and line budgets. A body that is merely shorter but drops one of them does not conform.

## 12. Read-only evidence

Every Orchestra invocation is safe to run before an agent has earned write access. A conformance run snapshots the complete target before and after structural, view, and strict modes. The snapshot covers file hashes, directories, symlinks and their targets, other file types, explicit `.icm` absence, and a preexisting `.icm` sentinel with its contents.

Mirrored workspaces at different absolute paths produce byte-identical Orchestra output. No output header or row contains an absolute target, toolkit defaults path, temporary path, timestamp, or mirror-specific default. No target write is part of producing that evidence.
