# LOOP LEDGER

Append only. Never rewrite history. A wrong line is corrected by a new line. Every line of every kind goes at the end of the file, under Lines, in time order. The sections above Lines are the shapes, not the places. Task, call and weekly review shapes are fixed by the out-of-the-loop skill. Miss, use and patched shapes are fixed by the toolkit's icm-log skill. Do not invent columns.

## Task lines

One line per closed task.

| Date | Task | Tier | Anchor | Verify cycles | Holes: plan/hunt/review/audit | Workarounds | Call fired | Artifact |
|---|---|---|---|---|---|---|---|---|

## Call lines

One line per call fired. The last column is filled at the weekly review. Necessary means the human changed something because of it.

| Date | Trigger | What fired it | Decision | Was the call necessary |
|---|---|---|---|---|

## Miss lines

One line per miss, at Session Close. The literal word Miss in column two is the selector. Sev is 3 wrong output shipped or a decision made on bad information, 2 cost time, 1 cosmetic, 2 when unsure. At fault is a rule book, job card or skill path as it exists on disk, or the word none. A returning fault after a patch starts What missed with RECURRENCE: and that is the strongest signal in the file.

| Date | Miss | Sev | At fault | What missed | Fix that would have prevented it |
|---|---|---|---|---|---|

## Skill lines

One use line per skill or job card a task ran under, at Session Close. The literal word Use in column two is the selector. Outcome is ok, rework or abandoned. Misses is how many miss lines this run wrote against it. One patched line whenever a human approves a proposal that changes a file; the forge writes it, the index reads it, and every miss dated before it counts as closed.

| Date | Use | Skill or job card | Path | Task | Outcome | Misses |
|---|---|---|---|---|---|---|

| Date | Patched | Path | Proposal id |
|---|---|---|---|

## Weekly review

Appended at each review, one block per week:

Week of, calls fired and how many were necessary, catch counts for pre-mortem, hunt, review and audit, workarounds taken, the recurring blocker if there is one, the anchor decay check, floor misses, and any threshold proposal with the operator's decision.

## Lines

Everything below this heading is the record. Append here. Never edit above it except to fix a shape, and never edit a line below it for any reason.
| 2026-09-04 | Miss | 3 | spec/layers.md | no layer owned the write back, so a generated workspace had no session close and nothing obliged an agent to log a miss | a Session Close section in layer 1, required by icm.defaults.json |
| 2026-09-04 | Miss | 2 | skills/icm-log/SKILL.md | said the miss line shape lived in out-of-the-loop references/ledger.md, which holds no miss shape at all, so three files each defined their own | the toolkit owns the miss, use and patched shapes, the skill says so |
| 2026-09-04 | Miss | 2 | scripts/icm_lib.sh | icm_body_forge_proposals emitted a six column table while icm-forge wrote FP blocks, two shapes for one file | one shape, the block, stated in the body |
| 2026-09-04 | Miss | 2 | scripts/icm_lib.sh | the ledger body had no section for miss lines, so an appended miss landed under Weekly review | Miss lines, Skill lines and a Lines section to append under |
| 2026-09-04 | Miss | 2 | skills/icm-forge/SKILL.md | counted misses with no severity, so one shipped wrong output weighed the same as a cosmetic slip | a Sev column and thresholds in icm.defaults.json |
| 2026-09-04 | Patched | spec/layers.md | commit the-loop-librarian, human edit, no proposal |
| 2026-09-04 | Patched | skills/icm-log/SKILL.md | commit the-loop-librarian, human edit, no proposal |
| 2026-09-04 | Patched | scripts/icm_lib.sh | commit the-loop-librarian, human edit, no proposal |
| 2026-09-04 | Patched | skills/icm-forge/SKILL.md | commit the-loop-librarian, human edit, no proposal |
| 2026-09-10 | Miss | 3 | scripts/icm-loop.sh | ghost ranked below hole and rewrite, so a sev 3 miss on a mistyped path was reported as a hole and the forge would edit a file that does not exist | rank ghost first in the verdict chain |
| 2026-09-10 | Miss | 2 | scripts/icm-loop.sh | a miss dated the patch day and appended after the patch counted as closed, so a same day recurrence was invisible | count a miss open when its date is on or after the patch |
| 2026-09-10 | Miss | 2 | scripts/icm_lib.sh | icm_today stamped UTC while every skill stamps local date, so windows counted a day behind before 10am AEST | one clock, local date, in icm_today |
| 2026-09-10 | Miss | 1 | .claude-plugin/plugin.json | homepage and repository pointed at the old repo name after the GitHub rename | update to MOMENTRIX-ICM-KAP |
| 2026-09-10 | Patched | scripts/icm-loop.sh | commit ghost-first-same-day-open, human directed edit, no proposal |
| 2026-09-10 | Patched | scripts/icm_lib.sh | commit ghost-first-same-day-open, human directed edit, no proposal |
| 2026-09-10 | Patched | .claude-plugin/plugin.json | commit ghost-first-same-day-open, human directed edit, no proposal |
| 2026-09-10 | Use | icm-loop | skills/icm-loop/SKILL.md | audit the loop and fix the index | ok | 3 |
| 2026-09-10 | loop audit and index fixes | 2 | Date | 0 | 0/4/0/0 | 0 | none | scripts/icm-loop.sh |
| 2026-10-24 | Miss | 3 | spec/excluded-folders.md | told scripts to build a find expression string from excluded_globs at run time, and the walker passed it to eval, so a committed workspace icm.defaults.json could run code on check | each entry one quoted find argument after a load time alphabet check, and a rule that config is data |
| 2026-10-24 | Patched | spec/excluded-folders.md | FP-2026-10-24-01 |
| 2026-10-24 | Patched | spec/CLI-CONTRACT.md | FP-2026-10-24-01 |
| 2026-10-24 | Patched | BUILD-CONTRACT.md | FP-2026-10-24-01 |
| 2026-10-24 | S00 config is data, no eval of globs | 2 | ship date | 3 | 0/6/0/0 | 0 | none | scripts/icm_lib.sh |
| 2026-10-24 | S00 fix round, never_write patterns and safe list reads | 2 | ship date | 1 | 0/0/4/0 | 0 | none | scripts/icm_lib.sh |
| 2026-10-24 | Patched | spec/CLI-CONTRACT.md | FP-2026-10-24-02 |
| 2026-10-24 | S01 CI on three userlands, LF line endings | 2 | ship date | 4 | 0/2/0/0 | 0 | none | .github/workflows/ci.yml |
| 2026-10-24 | Patched | spec/CLI-CONTRACT.md | FP-2026-10-24-03 |
| 2026-10-24 | Patched | spec/excluded-folders.md | FP-2026-10-24-03 |
| 2026-10-24 | S02 defaults merge, the toolkit under the workspace | 2 | ship date | 4 | 0/6/0/0 | 0 | none | scripts/icm_lib.sh |
| 2026-10-24 | S02 fix round, a defaults file that is not valid JSON is refused | 2 | ship date | 1 | 0/0/1/0 | 0 | none | scripts/icm_lib.sh |
| 2026-10-24 | Patched | spec/CLI-CONTRACT.md | FP-2026-10-24-04 |
| 2026-10-24 | S02 follow-up, never_write union only, macOS physical temp path | 2 | ship date | 1 | 0/0/1/0 | 0 | none | scripts/icm_lib.sh |
| 2026-10-26 | Miss | 2 | scripts/icm_lib.sh | generated wiki duplicated grounding loads and made the raw output ambiguous while the incoming directory was unmanaged | one grounding load and a managed raw/incoming output with a generated-workspace gate |
| 2026-10-26 | Miss | 2 | scripts/icm_lib.sh | skill fallback tested existence before every symlink component, so parent and dangling links bypassed scope | check workspace and selected-home symlinks before fallback and existence |
| 2026-10-26 | Miss | 2 | scripts/icm_lib.sh | one root NEXT traversal accepted department stages without a route from their nearest pipeline router | traverse NEXT independently from each pipeline router |
| 2026-10-26 | Miss | 1 | CONTEXT.md | pointed the Orchestra view at the legacy untyped toolkit root | point at the typed Orchestra example and name the legacy boundary |
| 2026-10-26 | Miss | 1 | skills/icm-retrofit/SKILL.md | denied every checker never_write check after Orchestra added Output scope enforcement | separate the write guard from Orchestra reporting and excluded walks |
| 2026-10-26 | Miss | 1 | spec/authority-model.md | the tier table said mechanical reports were model applied while the rule said never auto applied | assign mechanical remedies to human review |
| 2026-10-26 | Use | icm-orchestra | skills/icm-orchestra/SKILL.md | ICM Orchestra review repair and release | ok | 0 |
| 2026-10-26 | Use | icm-log | skills/icm-log/SKILL.md | ICM Orchestra review repair and release | ok | 0 |
| 2026-10-26 | ICM Orchestra review repair and release | 3 | customer result | 1 | 0/0/6/0 | 0 | none | tests/orchestra-tests.sh |
| 2026-10-26 | Bug | icm-generator | 2 | scripts/icm_lib.sh:1516,1600 duplicate load and ambiguous raw output | 0 | 0 | 3/3 | 1 (generated-workspace gate) | GENERATED-wiki-ORCHESTRA | tests/orchestra-tests.sh |
| 2026-10-26 | Bug | icm-skill-scope | 2 | scripts/icm_lib.sh:3226 fallback preceded component safety | 0 | 0 | 4/4 | 1 (symlink fixtures) | CAP-SKILL-PARENT-SYMLINK-REFUSED | tests/orchestra-tests.sh |
| 2026-10-26 | Bug | icm-pipeline-router | 2 | scripts/icm_lib.sh:2852 global NEXT traversal | 0 | 0 | 4/4 | 1 (nearest-router fixture) | ROUTE-NEAREST-PIPELINE-ROUTER | tests/orchestra-tests.sh |
| 2026-10-27 | Miss | 2 | tests/run-tests.sh | fixture used literal wiki delimiters and the banned word local, tripping the self scan | generate delimiters at runtime and keep test descriptions free of shell keywords |
| 2026-10-27 | Miss | 2 | scripts/icm-check.sh | typed token case patterns used an unescaped pipe, routing every token through the wiki path | escape type separators and exercise the direct repro before the full suite |
| 2026-10-27 | Miss | 2 | scripts/icm-check.sh | single-backtick scanning leaked nested code targets into wiki checks | handle variable-length code spans and fences with direct token probes |
| 2026-10-27 | Miss | 2 | scripts/icm_lib.sh | validation covered emitted fields and AWK numbers, missing empty containers and integer precision | validate every typed key and compare exact decimal strings |
| 2026-10-27 | Miss | 2 | tests/run-tests.sh | red evidence referenced mutable harnesses and fixtures, so historical counts could not be replayed | pin harness snapshots and separate original and fixed fixtures with hashes |
| 2026-10-27 | Use | icm-log | skills/icm-log/SKILL.md | ICM existing-collections upgrade | rework | 0 |
| 2026-10-27 | ICM existing-collections upgrade | 3 | customer result | 2 | 0/2/6/0 | 2 (fresh builder recovery, immutable replay) | T3 (Matty selected fresh builder) | https://github.com/MOMENTRIXMARKETING/MOMENTRIX-ICM-KAP/pull/23 |
| 2026-10-27 | T3 | two independent review failures | fresh builder repair and independent PASS |  |
| 2026-10-27 | Bug | icm-links | 2 | scripts/icm-check.sh Markdown-only extraction and incomplete target normalization | 0 | 2 | 0/0 | 0 | hunt wiki links and residual URL forms | https://github.com/MOMENTRIXMARKETING/MOMENTRIX-ICM-KAP/pull/23 |
| 2026-10-27 | Bug | icm-path-budgets | 2 | scripts/icm_lib.sh emitted-field validation and AWK numeric conversion | 0 | 2 | 0/0 | 0 | hunt path budgets and config refusals | https://github.com/MOMENTRIXMARKETING/MOMENTRIX-ICM-KAP/pull/23 |
