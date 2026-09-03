# BUILD CONTRACT — read this before writing any file

Repo: `momentrix-icm-kap-toolkit` — the **Momentrix ICM KAP Toolkit**.
KAP = Karpathy. It merges three upstreams (see `NOTICE.md`) into one drop-in package.

## NON-NEGOTIABLES

1. **Zero runtime dependencies.** Every script is POSIX `sh`. NO bashisms (`[[`, arrays, `local`, `${x^^}`, process substitution). NO python, NO node required. The tool list is three tiers, not one:
   - **Always required, all POSIX:** `sh, grep, sed, awk, wc, find, sort, diff, cat, head, tail, mkdir, cp, mv, rm, printf, date, basename, dirname, tr, rmdir, cmp, ls`. `cmp` is soft (`icm_same` falls back to `diff -q`); `ls` is reached only in the degraded hash path.
   - **Hashing, first found:** `shasum`, else `sha256sum`, else a size+mtime fingerprint. Neither hasher is POSIX; macOS, coreutils Linux and busybox/Alpine each supply one, so the fallback is an edge case. It must be announced out loud and stamped into the manifest. It weakens **rollback's tamper detection only**. Apply's never-overwrite is a byte compare in `icm_classify`/`icm_same` and is hash-independent. Do not conflate the two.
   - **Optional, both guarded, neither ever blocking:** `git` (`command -v` guard, drives only `icm-plan.sh`'s dirty-repo refusal) and `python3` 3.10+ (`scripts/check_evidence.py`, the one deep check). Every script must work without them.

   Adding a tool to a script means adding it here. The list is generated-checkable: grep `scripts/` before you change this line.
2. **Vocabulary.** `_config/` files are **RULE BOOKS**, never "skills". Never write "skills library". Toolkit skills are the eight `skills/icm-*/SKILL.md` files in this repo. A customer skill is a `SKILL.md` in `customers/<name>/` of that customer's workspace (Pattern 25), never in this repo's `skills/`, never in `~/.claude/skills`, never as a Grok Bot global skill. A stage `CONTEXT.md` is a **job card**. The five disposition words are `CREATE, ADOPT, COLLIDE, SKIP, REFUSE` and there are no others; `spec/CLI-CONTRACT.md` owns every command name, flag, exit code and artifact path.
3. **Never overwrite.** Your files are never rewritten. `CLAUDE.md` and `.gitignore` get a marked block appended, backed up first. Everything else that exists is parked in `.icm/proposed/` for you. A script may create a rule book that does not exist, once, as part of an install; no script and no agent ever edits one that exists.
4. **Numbers come from `icm.defaults.json`.** Never restate a budget as a literal in prose. Cite the file. Characters are counted with `wc -c`, in prose and in `icm_chars` alike.
5. **Skip list comes from `icm.defaults.json`**, keys `excluded_globs` and `never_write`. `spec/excluded-folders.md` is the human rendering of those keys and no script reads it. Never restate the list anywhere.
6. **Voice.** Plain, short declaratives. Second person. Lowercase folder names. No em-dashes in user-facing deck copy.

## FRONTMATTER (every skills/<name>/SKILL.md)

```
---
name: <MUST equal the directory name>
description: "This skill should be used when the user asks to '<trigger>', '<trigger>'... <what it does>."
user-invocable: true
argument-hint: "<modes>"
---
```
`user-invocable` is HYPHENATED. `user_invocable` (underscore) is banned and the checker fails on it.

## LAYERS (spec/layers.md is authoritative)

| Layer | Where | Question |
|---|---|---|
| 0 | `IDENTITY.md` | Where am I? |
| 1 | root `CONTEXT.md` | Where do I go? |
| 2 | stage/folder `CONTEXT.md` (the job card) | What do I do? |
| 3 | `_config/` rule books | What rules apply? |
| 4a | `raw/` — immutable sources | What is true? |
| 4b | `wiki/` + `output/` — compiled | What do we know / what did we make? |

Layers 1-3 RECURSE: a company holds departments, each department repeats the same pattern inside.

## THE GROUNDING INVARIANT
Every load-bearing fact (number, date, quote) in a `wiki/` article exists verbatim in a `raw/` file that article links to. Instruction enforces it at write time; `scripts/check_evidence.py` verifies it when python3 exists.

## THE AUTHORITY MODEL (one model, used by both lint and forge)
- **Safe fix** — deterministic, auto-applied (dead link with exactly one match, index out of sync).
- **Mechanical report** — a script found it, never auto-fixed (fact mismatch, budget breach).
- **Judgment report** — model opinion, always a proposal (missing cross-reference, doctrine hole).
The logger never judges. The forge never edits. The human holds the only pen that touches rule books.

## PATHS
- `_log/LOOP-LEDGER.md` — append-only ledger (format: `references/ledger.md` of out-of-the-loop).
- `_log/FORGE-PROPOSALS.md` — what the forge proposes, awaiting approval.
- `.icm/` — plan, backups, proposed collisions. Gitignored.
