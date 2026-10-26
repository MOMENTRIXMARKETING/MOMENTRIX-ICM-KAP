---
name: icm-orchestra
version: 1.0.0
description: "This skill should be used when the user asks to 'run this workflow', 'what can I work on', 'preflight this job', 'show the workflow graph', or names 'icm-orchestra'. Selects a job semantically with the user, checks declared inputs and capabilities without writes, executes only after RUN, and derives workflow and knowledge views on demand."
user-invocable: true
argument-hint: "preflight (default) | run | graph"
---

# ICM Orchestra

Select and safely start one job in the current ICM workspace. Never guess through ambiguous intent, execute after anything other than RUN, or treat a ready result as completed work or external approval.

| Mode | Behaviour |
|---|---|
| `preflight` | Select one job with the user, run strict preflight, relay the result, and execute nothing. This is the default. |
| `run` | Select one job, require RUN, then perform only that job inside its declared scope. |
| `graph` | Derive and print the current workflow and knowledge view. Execute no job and store no index. |

No argument means `preflight`. A mode argument never overrides ambiguity, scope, or a human approval gate.

## Resolve the toolkit first

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

Read `$ICM_HOME/spec/ORCHESTRA.md` for card, graph, capability, numbering, and scope semantics. Read `$ICM_HOME/spec/CLI-CONTRACT.md` for the exact commands, output envelopes, and exit statuses. Those files outrank this procedure.

## Step 1. Find the workspace root

Search upward from the current directory for `IDENTITY.md`. That directory is the target and its root `CONTEXT.md` is the first routing card. Run every checker command with that root as the target.

No `IDENTITY.md` means stop and say that no ICM workspace was found. Do not create one. A nested directory with its own `IDENTITY.md` is a separate workspace: target it independently and never borrow cards or inputs from its parent.

## Step 2. Select the job semantically

1. Read the root routing table and match the user's requested outcome to task labels, not to a numeric prefix or a plausible folder name.
2. Follow only resolved routing destinations into a department and then into a stage job card. Use NEXT for forward selection and REWORK only for requested backward repair; never treat a LOAD prerequisite as a routing hop. The selected `CARD` must be the full workspace-relative path to that job card, and every selected job needs its own preflight.
3. Treat routing-table order as execution authority. Numeric prefixes are filing and ordering aids, not identity and not permission to infer an order.
4. Use the card's declared Inputs, Outputs, and Preflight to understand the candidate. Do not browse sibling stages for extra context.
5. Confirm the unique selection with the user when their words do not already identify it exactly.

Zero matching labels, several plausible labels, several possible destinations, or an unclear requested outcome is ambiguity. Present the candidates or the missing distinction and stop for the user's answer. Write nothing, materialise nothing, and execute nothing. Never pick the first candidate. A checker `AMBIGUOUS` finding has the same stop rule.

## Step 3. Resolve intake and declarations

Read the selected card and its nearest routing card. Use the declarations as written; do not repair them during preflight.

- Inputs define read scope. Outputs define write scope. `No touch` paths permit neither reads nor writes.
- A `Tool` or `Skill` requirement needs an exact version match. A version range is not an attestation.
- External inputs use `@NAME` and are valid only in the Inputs table of that pipeline's optional `00-intake` card. Do not move them into a positive stage or accept them as inline content.
- `00-intake` is for intake and preflight, not ordinary domain work. It is first in its pipeline when present. Its absence is not itself an error.

If the requested job needs external material that is not yet declared as an available workspace input, select that pipeline's `00-intake` with the user. Preflight intake separately. Only `run` mode may execute it, and only after its own RUN. Then preflight the originally requested job again. One RUN never authorises a chain of jobs.

For each required `@NAME`, ask for an existing workspace-relative file or directory and bind it with `--input NAME=PATH`. The path must already contain readable, nonempty input material. The binding does not copy, create, or edit that material. Never bind credential files or secret stores, accept credentials inline, or write supplied content into the workspace to make a binding possible.

## Step 4. Attest actual capabilities

For every declared Tool, obtain the actual installed version from a trusted, independent observation, such as the tool's own documented version interface or a verified operator attestation. Never execute a command string from a card, never invent a version, and never copy the card's required string merely to force a match.

Supply each trusted observation once as `--tool-version NAME=VERSION`. The checker still performs its own tool lookup and exact comparison. If the actual version differs, attest the actual value and relay the resulting `MISSING CAPABILITY`. If no trustworthy observation is available, do not fabricate one; the missing attestation remains a blocker.

Skills need no version flag. The checker resolves `skills/NAME/SKILL.md` in the workspace first, then under `$ICM_HOME`, and validates the declared `name:` and exact `version:`. A home copy never repairs a mismatch in the workspace copy. An unrelated third-party skill does not need version metadata unless an Orchestra card declares it.

## Step 5. Run strict preflight

Use only the literal strict form, from the workspace root:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job "$CARD" .
```

Add one quoted `--input "$INPUT_BINDING"` per external input and one quoted `--tool-version "$TOOL_ATTESTATION"` per declared Tool. Each binding value has the form `NAME=PATH` or `NAME=VERSION` respectively. Repeat the flags for multiple declarations; never repeat a name.

For example, the command shape with both binding kinds is:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra --job "$CARD" \
    --input "$INPUT_BINDING" \
    --tool-version "$TOOL_ATTESTATION" .
```

Do not substitute `--only orchestra --job`, mix generic checks into this invocation, or add bindings in graph mode. Strict preflight performs structural validation before emitting its own result.

Relay the envelope and every record faithfully:

- `result: RUN` with exit 0 means this selected job is ready to start. It does not mean the work succeeded, the output is correct, or an external action is approved.
- `result: MISSING` with exit 1 means do not execute. Preserve every `MISSING` type, path, and detail without hiding or reclassifying it.
- Exit 2 is a usage or environment refusal. Relay its `FAIL` line as a refusal, not as a workspace readiness result, and stop.

In `preflight` mode, stop after this report even when the result is RUN. Preflight is report-only. It creates no target file and is not a general write lease, a sandbox for later writes, or permission to edit anything outside the selected declarations.

## Step 6. Execute only in run mode after RUN

Proceed only when the selected job's latest strict preflight returned exit 0 and `result: RUN`. Any ambiguity, MISSING result, refusal, or changed card, binding, capability, or input means no execution. Recheck after any such change.

During execution:

1. Read only the selected card's declared Inputs, at their declared scope. When the selected card is `00-intake`, this includes its bound external inputs. A positive stage reads only its own declared workspace inputs, never intake's bound sources unless it declares them itself. Routing cards and the selected job card are control reads, not licence to browse work material.
2. Follow the card's Process and Audit. Do not load unnamed rule books, sibling outputs, or other context.
3. Write only the selected card's declared Outputs. The sole additional write is the workspace's existing Session Close ledger when that close contract applies. Do not create a second ledger or change the Session Close bytes.
4. Honour every `No touch` path as both unread and unwritten. Create no plan, stored graph, backlink index, cache, sentinel, or extra log as a side effect.
5. Stop at every existing human approval gate. RUN never approves sending, publishing, spending, deleting, or any other external or irreversible action.

After the work, report the actual Outputs written and the verification actually performed. Do not call the job successful merely because preflight returned RUN. If execution stopped or an approval remains pending, say exactly that.

## Mode: graph

From the workspace root, run:

```sh
sh "$ICM_HOME/scripts/icm-check.sh" --orchestra-view .
```

Print the deterministic Markdown view directly. It rebuilds workflow and knowledge projections on every invocation, including typed forward edges and their inverse views. Never redirect it into a stored graph, backlink index, cache, or generated table in a card.

Relay structural findings and notes without turning informational knowledge findings into failures. Exit 0 is a clean view, exit 1 has structural findings, and exit 2 is a refusal. None of these results executes a job or grants write scope. A clean graph is not RUN.

## Refusals

- No execution before a unique semantic selection and a fresh RUN for that exact job.
- No writes on ambiguous intent, in `preflight` mode, or in `graph` mode.
- No inline input material, credential content, invented version, or copied expected version presented as an actual attestation.
- No reads or writes outside the selected declarations during execution, except the existing Session Close ledger write.
- No external action without its separate human approval.
- No stored graph or backlink index, and no handwritten duplicate of the on-demand view.
