# FORGE PROPOSALS

What the forge proposes, waiting on a human decision. The forge never edits. The logger never judges. The human holds the only pen that touches a rule book.

## Proposals

One block per proposal, appended by icm-forge below the Authority section, body never edited after it is written. The Status line is the only line that changes, and only when a human names the id. The shape, indented here so the example is never counted as a proposal:

    ## FP-<YYYY-MM-DD>-<NN> | <path>
    - Status: proposed | proposed (unattended run) | approved <date> | rejected <date>, <reason>
    - Kind: edit | new | archive | rewrite
    - Hole: <one line>
    - Evidence: <the ledger lines, pasted verbatim, at least two for edit>
    - Smallest edit: <the exact replacement text, or the exact path and shape for new>
    - Test that proves it: <a measurable check, or none possible and why>

A proposal heading starts at column one with two hashes and FP-. No other heading in this file may start with FP-.

## Authority

Authority is one of three, and the word chosen decides who may act.

- **safe fix** - deterministic and reversible, applied by a script, recorded here after the fact.
- **mechanical report** - a script found it and a script must not fix it. A human decides.
- **judgment report** - a model's opinion. Always a proposal, never a change.

A proposal with no evidence column is not a proposal, it is an opinion. Give it the file and the line.

## FP-2026-10-24-01 | spec/excluded-folders.md
- Status: approved 2026-10-24 (build loop, owner directive)
- Kind: edit
- Hole: the skip list rule book told scripts to build a find expression string from excluded_globs at run time, and icm_walk_files passed that string to eval, so a committed workspace icm.defaults.json could run code when anyone ran a check. No rule book said config is data.
- Evidence: scripts/icm_lib.sh icm_prune_expr and icm_walk_files / icm_walk_dirs (the eval of the built find string, before step S00). In tests/run-tests.sh section S00 the excluded_globs entry x'$(touch${IFS}PWNED)'y created PWNED under the old walker ("FAIL no payload created a PWNED file"), and no script refused any of the three payloads. A fixture in a folder named build passed --links with exit 0 over a dead link, because the old walk pruned the root itself.
- Rung: 4 (one new rule in an existing rule book)
- Where: spec/excluded-folders.md, new section What an Entry May Hold, the Copy the prune expression note, and the Refusing a Write example
- Smallest edit: spec/excluded-folders.md gains "What an Entry May Hold" (the alphabet A-Z a-z 0-9 . _ * ? -, a space written ?, exit 2 naming the key, the target's own name never tested) and its prune expression note says each name is a separate quoted find argument, never a built string, never eval. spec/CLI-CONTRACT.md 3.0 gains the KEEP rule "config is data", 3.1 names the refusal under exit 2, and 13.2 gains the "config is data" test row. BUILD-CONTRACT.md non-negotiable 5 gains the same rule. The Refusing a Write example tests each path component against each never_write entry as a case pattern and reads the entries one per line, never with for x in $(...).
- Test that proves it: tests/run-tests.sh section S00. All three payloads make icm-check.sh, icm-plan.sh, icm-loop.sh --index, icm-apply.sh and icm-rollback.sh exit 2 naming the key, and no PWNED file appears. A never_write entry and a newline-split entry are refused too. A wildcard entry still prunes, an entry spelled -delete deletes nothing, a target named build and an entry .* still walk the tree, and no script calls eval. Run from a cwd holding a matching name, the plan survey still drops .* and drafts* folders, and a never_write entry IDENT?TY.md refuses IDENTITY.md.
- Would have prevented: the eval sink and the build-root clean pass

## FP-2026-10-24-02 | spec/CLI-CONTRACT.md
- Status: approved 2026-10-24 (build loop, owner directive)
- Kind: edit
- Hole: section 13.2 lists the tests that stop drift, but nothing ran them except a person on one machine. No gate ran under the macOS BSD userland or busybox, and as root the harness could never pass, so the Session Start rule "harness passed and no FAIL" was out of reach for a root runner.
- Evidence: the harness as root printed PASS 358 / FAIL 2 before step S01, the two failures being "the checker exits 2 on a target it cannot list, never clean" and "the loop exits 2 on a target it cannot list", because root lists a mode 0300 folder anyway. Commit 0963eb0 fixed issue 5 (macOS awk aborting on a byte under a UTF-8 locale) after it shipped; nothing ran its regression test on a macOS awk on each push. The repo held no .github/ and no .gitattributes before step S01.
- Rung: 4 (one new row in an existing rule book's test table)
- Where: spec/CLI-CONTRACT.md, section 13.2, a new row after "config is data"
- Smallest edit: spec/CLI-CONTRACT.md 13.2 gains the row "CI and line endings": .github/workflows/ci.yml runs on every push and pull request with a read-only token and three jobs (ubuntu with dash as sh, macos with the BSD userland, ubuntu with every busybox applet first on PATH), each running sh -n and dash -n where present on every script and example shell body, the harness, the python tests when python3 3.10 or newer exists, and the checker on the repo; .gitattributes holds "* text=auto eol=lf" and "*.pdf binary"; as root the two unlistable-target tests are skipped with a note line.
- Test that proves it: tests/run-tests.sh section S01 reads the workflow for its triggers, token, three jobs, busybox PATH, syntax sweep, harness, python and self check lines and for a tab, reads .gitattributes for both lines, and reads them back with git check-attr. As root the harness reports FAIL 0. CI green on all three jobs is the CI-only half.
- Would have prevented: the root-only FAIL 2 baseline, and a macOS-only defect like issue 5 shipping before any test ran on macOS
