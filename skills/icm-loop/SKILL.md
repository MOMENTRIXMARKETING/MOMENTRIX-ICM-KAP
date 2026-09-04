---
name: icm-loop
description: "This skill should be used when the user asks to 'make this system recursive', 'install the loop', 'add the write back', 'overlay this on', 'get the agents logging their mistakes', 'is the loop firing', 'prove it fired', or 'why is the ledger empty'. Installs the Session Close, the one block that makes a workspace log its own misses, into whatever file the host loads on every run, proves it fired with a deliberate miss, and checks it for starvation afterwards. Works on an ICM workspace, on a repo that has never seen the toolkit, on a Codex or Cursor project, on an n8n flow, or on a human SOP. Not for logging a miss (icm-log) or reading the ledger for patterns (icm-forge)."
user-invocable: true
argument-hint: "install | prove | starve | block"
---

# ICM Loop

Recursion means the output feeds back in as input. An agent has none by default: static instructions, no record of its own failures, so it fails the same way in month six as on day one. The loop is three files and one obligation. `icm-log` records into `_log/LOOP-LEDGER.md`. `icm-forge` reads it and proposes. A human approves. And the obligation is the Session Close: the block that makes whatever does the work write the miss before it replies.

## THE PART THAT ACTUALLY MATTERS

A ledger nobody writes to produces a forge with nothing to read. Every failure of this loop is the same failure: the misses never got recorded. Installing the loop is one job, **making the write back obligatory for whatever does the work**. Everything else is downstream, and this skill does nothing else.

Do not describe the loop to a host and hope. Inject the block into the file that host loads on every single run, then prove it fired with a deliberate miss, then watch it for starvation.

## Resolve the toolkit first

```sh
# Resolve the toolkit root once, before any icm command.
ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"
[ -f "$ICM_HOME/scripts/icm_lib.sh" ] || {
    printf 'FAIL cannot find the ICM toolkit. Set ICM_HOME to the toolkit root.\n' >&2
    exit 2
}
```

The block itself comes from the toolkit, never from memory and never from this file:

```sh
sh "$ICM_HOME/scripts/icm-loop.sh" --block
```

That prints the Session Close between `<!-- ICM-LOOP:START -->` and `<!-- ICM-LOOP:END -->`. It is the same bytes `icm-apply.sh` writes into a generated `CONTEXT.md`, from the same body in `scripts/icm_lib.sh`. There is one copy of the block in the world and the script is how you get it. Paraphrasing it is the single most common way the loop dies: a paraphrased block loses the mechanism rule, the ledger fills with "output was wrong", and the forge has nothing to count.

---

## Mode: install

### Step 1. Decide which engine owns the loop

Two ledgers means neither is authoritative. Look before you write.

| What you find | Engine | Do |
|---|---|---|
| `IDENTITY.md` and a `CONTEXT.md` with a Session Close | Already installed | Skip to `prove`. Do not inject a second block |
| `IDENTITY.md` and a `CONTEXT.md` without one | An older toolkit install | Re-render: `icm-plan.sh` then `icm-apply.sh` will not touch a `CONTEXT.md` you own, so paste the block from `--block` above `## Rule Books` by hand, and add the ledger sections `_log/LOOP-LEDGER.md` is missing from `skills/icm-log/SKILL.md` |
| `LOOP-LEDGER.md` with task lines and no toolkit | out-of-the-loop is running here alone | Install the toolkit (`icm-plan.sh`, `icm-apply.sh`, which classify the existing ledger COLLIDE and park a candidate) or, if the user refuses the toolkit, inject the block into the host file below and let the miss lines join that ledger under a `## Lines` heading |
| Neither | Nothing yet | Plan and apply the toolkit if the user wants the layers. Otherwise inject the block alone, and bootstrap the ledger with the fallback in `skills/icm-log/SKILL.md` |

Never invent a second ledger file. One `_log/LOOP-LEDGER.md` per workspace. Misses join it as their own line kind; they do not get their own file.

### Step 2. Find the always loaded file

Every host has one file it reads before every run. That is the only place the block can go.

| Host | File |
|---|---|
| An ICM workspace, any harness | `CONTEXT.md`, layer 1. The harness alias (`CLAUDE.md`, `AGENTS.md`, `.cursorrules`) points at `IDENTITY.md`, which points here. Never the alias itself: an alias that grows a block has become a copy |
| Claude Code or Cowork, no ICM | `CLAUDE.md` at the project root |
| Codex, OpenAI agents | `AGENTS.md` at the project root |
| Cursor | `.cursorrules` |
| A custom agent or an API wrapper | The system prompt string, or a post-run hook that always executes |
| n8n, Zapier, Make | A final node on every branch, including the error branch |
| A human operator | The SOP itself, as its last step. Not a separate reminder |

No always loaded file means the host cannot be made recursive. Find or create one before going further, and say so if you cannot.

### Step 3. Inject the block, verbatim, between the markers

Append the output of `--block` to the file from step 2. The markers are what let it be updated or removed cleanly later. Never edit inside them by hand; regenerate with `--block` and replace the whole marked span. Never shorten it.

On an ICM workspace the block is already inside `CONTEXT.md` under `## Session Close` without markers, because the file is generated and regenerating it is the update path. Only a host file that is not generated gets the markers.

### Step 4. Sub agents and handoffs

Multi agent systems starve the ledger faster than anything else, because the agent that hit the problem is not the one that replies. The block already carries the sub agent rule. Your job at install is to check the host honours it:

1. Every sub agent loads the same always-loaded file, or carries the block in its own prompt. A sub agent that cannot write files reports its lines in its final message, and the orchestrator appends them.
2. The orchestrator logs handoff failures itself: wrong sub agent picked, context lost between agents, a sub agent that returned nothing usable. At fault is the routing file that picked it.
3. One shared ledger per workspace. Never one per agent. Per-agent ledgers are four partial truths.

### Step 5. Prove it fired

Go to `prove`. The install is not done until a row has appeared.

---

## Mode: prove

This is a test, not a review.

1. Run the host on a real, small task and deliberately withhold something it should already have, so it has to ask for it. Asking for information already available is the first item in the miss check.
2. Read the ledger:

```sh
grep '| Miss |' _log/LOOP-LEDGER.md | tail -n 3
```

3. A row should be there, sev 2, naming the file that should have held the withheld thing.
4. Nothing there means the block sits in a file the host does not actually load. Move it and repeat.
5. Two failed placements means stop guessing. Read the host's own docs for its context loading order, and say what you found.

Then record the install itself as a use line, so the index knows the day the loop started:

```sh
printf '| %s | Use | icm-loop | skills/icm-loop/SKILL.md | install the loop | ok | 0 |\n' "$(date +%Y-%m-%d)" >> _log/LOOP-LEDGER.md
```

The install date is what lets the index tell an empty ledger from a young one. Without it, week one and a broken install look identical.

---

## Mode: starve

Run this before every forge cycle, and whenever the ledger looks too clean.

```sh
sh "$ICM_HOME/scripts/icm-loop.sh" --starve .
```

Exit 0 firing or quiet, 1 starved, 2 no ledger. The script counts. You read:

| Signal | Read it as |
|---|---|
| `STARVED`: task or use lines in the window, zero miss lines | The block is not loading. Reinstall, do not tune rule books |
| Only sev 1 rows | The host is logging politely and hiding the real faults. Push on the severity definitions in the block |
| Every row blames the same path | Either it is genuinely broken, or it is the only name anyone remembers |
| Rows stop after a host update | The update overwrote the always loaded file. Regenerate with `--block` and replace the marked span |
| Rows all say "output was wrong" with no mechanism | The block has been paraphrased. Reinject it verbatim |

A thin ledger under heavy work is never a sign the work went well. It means the write back is not firing. Fix that before touching a single rule book.

---

## Mode: block

Print the block and stop. For a human who wants to paste it somewhere this skill cannot reach.

```sh
sh "$ICM_HOME/scripts/icm-loop.sh" --block
```

---

## Refusals

- No paraphrasing the block. It comes from `--block` or it does not go in.
- No second ledger, per agent or per skill.
- No injecting into a harness alias on an ICM workspace. The alias points, `CONTEXT.md` holds.
- No calling an install done before a miss row exists.
- No tuning a rule book on a starved ledger, and no letting the forge do it either.
- No editing a rule book, a job card or a skill. This skill installs the obligation to log. It never acts on what gets logged.

## What is machine enforced and what is judgment

Authority model: `$ICM_HOME/spec/authority-model.md`.

**Machine-enforced by a toolkit script.** `icm-loop.sh --block` is the only source of the block, so the bytes cannot drift. `icm-loop.sh --starve` counts work lines and miss lines in the window from `icm.defaults.json` and exits 1 when work happened and nothing was logged. `icm-check.sh --sections` fails a generated `CONTEXT.md` that lacks `## Session Close`, which is how an old install announces itself:

| Check | check-id | What it verifies |
|---|---|---|
| Required sections | `sections` | The root `CONTEXT.md` carries `## Session Close` and the ledger carries its line-kind sections |
| Adapter shape | `adapters` | `CLAUDE.md` is an alias of `IDENTITY.md`, not a copy that has grown a block |

**Safe fix, applied by you, then reported.** Appending the marked span to a host file that is not generated. Regenerating it when the markers are present. Appending the install use line.

**Mechanical report, found by a check, never fixed.** A starved window. A missing Session Close on a generated `CONTEXT.md`, which means re-render, not hand edit.

**Judgment, and it is the user's, not yours.** Which host file is the always loaded one when the table above does not name it. Whether a host with no such file should get one. Whether a system with no ledger should get the whole toolkit or the block alone.
