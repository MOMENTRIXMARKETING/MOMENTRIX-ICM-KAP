#!/bin/sh
# tests/run-tests.sh - the POSIX test harness for the shell layer.
#
# No pytest. No python. No bash. Builds throwaway fixture workspaces under a
# temp directory, drives the real scripts against them, and asserts on exit
# codes, output text and bytes on disk.
#
# usage: tests/run-tests.sh [-v]
# Prints "PASS n / FAIL n" and exits non-zero when anything failed.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPTS="$ROOT/scripts"
ICM_HOME="$ROOT"
. "$ROOT/scripts/icm_lib.sh"
icm_init "$ROOT"

VERBOSE=0
if [ "${1:-}" = "-v" ]; then
    VERBOSE=1
fi

# The work directory carries a space on purpose. Every fixture path in every
# test below therefore contains one, so an unquoted variable anywhere in the
# shell layer fails a test instead of failing quietly in someone's repo.
WORK="${TMPDIR:-/tmp}/icm tests $$"
rm -rf "$WORK"
mkdir -p "$WORK"
# Some fixtures deliberately go read-only, mode 000 or 555, because that is the
# defect under test. Widen everything back before the sweep, or the sweep fails
# and leaves the fixtures behind.
trap 'chmod -R u+rwX "$WORK" 2>/dev/null; rm -rf "$WORK"; icm_cleanup' EXIT INT TERM

PASSN=0
FAILN=0
OUT=""
RC=0

t_pass() {
    PASSN=$((PASSN + 1))
    printf 'ok   %s\n' "$1"
}

t_fail() {
    FAILN=$((FAILN + 1))
    printf 'FAIL %s\n' "$1"
    printf '%s\n' "$2" | sed 's/^/     | /' | head -n 15
}

run() {
    OUT=$("$@" 2>&1)
    RC=$?
    if [ "$VERBOSE" -eq 1 ]; then
        printf '     $ %s\n' "$*"
        printf '%s\n' "$OUT" | sed 's/^/     > /'
    fi
    return 0
}

assert_rc() {
    if [ "$RC" -eq "$2" ]; then
        t_pass "$1"
    else
        t_fail "$1" "expected exit $2, got $RC
$OUT"
    fi
}

assert_out() {
    if printf '%s\n' "$OUT" | grep -q -F -- "$2"; then
        t_pass "$1"
    else
        t_fail "$1" "output did not contain: $2
$OUT"
    fi
}

assert_same() {
    if cmp -s "$2" "$3"; then
        t_pass "$1"
    else
        t_fail "$1" "$2 and $3 are not byte identical"
    fi
}

assert_differs() {
    if cmp -s "$2" "$3"; then
        t_fail "$1" "$2 and $3 are identical, they should not be"
    else
        t_pass "$1"
    fi
}

assert_file() {
    if [ -f "$2" ]; then
        t_pass "$1"
    else
        t_fail "$1" "missing file: $2"
    fi
}

assert_nofile() {
    if [ -e "$2" ]; then
        t_fail "$1" "file should be gone: $2"
    else
        t_pass "$1"
    fi
}

fixture() {
    _fx="$WORK/$1"
    rm -rf "$_fx"
    mkdir -p "$_fx"
    printf '%s\n' "$_fx"
}

# Every file under a workspace with its hash, ignoring .icm/ which is the
# toolkit's own scratch space.
snapshot() {
    ( cd "$1" && find . -type f -print ) \
        | sed 's|^\./||' \
        | grep -v '^\.icm/' \
        | sort \
        | while IFS= read -r _sn_f; do
              [ -n "$_sn_f" ] || continue
              printf '%s %s\n' "$_sn_f" "$(icm_sha "$1/$_sn_f")"
          done
}

skill_file() {
    # skill_file <path> <name-value> [extra-key-line]
    {
        printf '%s\n' '---'
        printf 'name: %s\n' "$2"
        printf 'description: "This skill should be used when the user asks to test."\n'
        printf 'user-invocable: true\n'
        printf 'argument-hint: "<mode>"\n'
        if [ -n "${3:-}" ]; then
            printf '%s\n' "$3"
        fi
        printf '%s\n' '---'
        printf '\n# %s\n\nA body.\n' "$2"
    } > "$1"
}

printf '# icm shell layer tests\n'
printf 'root: %s\n' "$ROOT"
printf 'work: %s\n\n' "$WORK"

# --------------------------------------------------------- 1 sh -n everywhere --

printf '%s\n' '-- syntax --'
for F in "$SCRIPTS"/icm_lib.sh "$SCRIPTS"/icm-check.sh "$SCRIPTS"/icm-plan.sh \
         "$SCRIPTS"/icm-apply.sh "$SCRIPTS"/icm-rollback.sh "$ROOT"/tests/run-tests.sh; do
    B=$(basename "$F")
    if [ ! -f "$F" ]; then
        t_fail "$B exists" "no such file: $F"
        continue
    fi
    run sh -n "$F"
    assert_rc "$B passes sh -n" 0
done

# The self check is the standing guard: it reruns sh -n and sweeps every
# script for bashisms. Reach for a bash-only test, keyword or array and it
# fails here, before it reaches anyone's machine.
run "$SCRIPTS/icm-check.sh" --self "$ROOT"
assert_rc "the toolkit passes its own --self check" 0

# Dogfood. The toolkit carries its own layer 0 and layer 1, and the full check
# has to pass on this repo, not only on the workspaces it builds.
run "$SCRIPTS/icm-check.sh" "$ROOT"
assert_rc "the toolkit passes its own full check" 0
assert_out "the full self check reports clean" "result: clean"
assert_file "the toolkit has its own IDENTITY.md" "$ROOT/IDENTITY.md"
assert_file "the toolkit has its own CONTEXT.md" "$ROOT/CONTEXT.md"
if [ "$(icm_lines "$ROOT/CLAUDE.md")" -eq 2 ] && grep -q -F '@IDENTITY.md' "$ROOT/CLAUDE.md"; then
    t_pass "CLAUDE.md is a two line alias, not a copy"
else
    t_fail "CLAUDE.md is a two line alias, not a copy" "$(cat "$ROOT/CLAUDE.md")"
fi

# The degraded hash path has to work on a box with no sha tool at all.
DEGRADED=$(ICM_SHA_MODE=degraded; printf 'contents\n' > "$WORK/h1"; icm_sha "$WORK/h1")
case "$DEGRADED" in
    nohash:*) t_pass "icm_sha degrades to size and mtime when no sha tool exists" ;;
    *)        t_fail "icm_sha degrades to size and mtime when no sha tool exists" "got: $DEGRADED" ;;
esac
if [ -n "$(ICM_SHA_MODE=degraded; icm_sha_mode_note)" ]; then
    t_pass "the degraded hash mode says so out loud"
else
    t_fail "the degraded hash mode says so out loud" "icm_sha_mode_note printed nothing"
fi

# ------------------------------------------------------------- 2 frontmatter --

printf '\n%s\n' '-- frontmatter --'

D=$(fixture t-fm-missing)
mkdir -p "$D/skills/foo"
printf 'name: foo\ndescription: no fence above me\n' > "$D/skills/foo/SKILL.md"
run "$SCRIPTS/icm-check.sh" --frontmatter "$D"
assert_rc "missing frontmatter fails the check" 1
assert_out "missing frontmatter is named in the report" "does not open with frontmatter"

D=$(fixture t-fm-banned)
mkdir -p "$D/skills/bar"
BANNED_KEY=$(printf 'user%sinvocable' '_')
skill_file "$D/skills/bar/SKILL.md" bar "$BANNED_KEY: true"
run "$SCRIPTS/icm-check.sh" --frontmatter "$D"
assert_rc "the banned underscore key fails the check" 1
assert_out "the banned key is named in the report" "uses the banned key"

D=$(fixture t-fm-name)
mkdir -p "$D/skills/baz"
skill_file "$D/skills/baz/SKILL.md" qux
run "$SCRIPTS/icm-check.sh" --frontmatter "$D"
assert_rc "name that does not equal the directory fails the check" 1
assert_out "the name mismatch is named in the report" "it must equal the directory name"

D=$(fixture t-fm-good)
mkdir -p "$D/skills/good-skill"
skill_file "$D/skills/good-skill/SKILL.md" good-skill
run "$SCRIPTS/icm-check.sh" --frontmatter "$D"
assert_rc "clean frontmatter passes" 0

# ----------------------------------------------------------------- 3 budgets --

printf '\n%s\n' '-- budgets --'

D=$(fixture t-budget)
awk 'BEGIN { for (i = 0; i < 400; i++) print "a line that is quite long, and repeated many times over" }' \
    > "$D/IDENTITY.md"
run "$SCRIPTS/icm-check.sh" --budgets "$D"
assert_rc "an over-budget IDENTITY.md fails the check" 1
assert_out "the ceiling breach is named in the report" "over the IDENTITY.md ceiling"

# ---------------------------------------------------------------- 4 adapters --

printf '\n%s\n' '-- adapters --'

D=$(fixture t-adapter)
{
    printf '# fixture - Identity\n\n'
    printf '## Workspace Map\n\n'
    printf 'The map of this workspace lives here, and it is long enough to count.\n'
    printf 'A second line of body text that is comfortably over twenty characters.\n'
    printf 'A third line of body text that is comfortably over twenty characters.\n'
    printf 'A fourth line of body text that is comfortably over twenty characters.\n\n'
    printf '## Rules\n\n'
    printf 'A rule line that is comfortably over twenty characters long as well.\n'
} > "$D/IDENTITY.md"
cp "$D/IDENTITY.md" "$D/CLAUDE.md"
run "$SCRIPTS/icm-check.sh" --adapters "$D"
assert_rc "a CLAUDE.md that copies IDENTITY.md fails the check" 1
assert_out "the copy is named in the report" "duplicates the IDENTITY.md body"

# ------------------------------------------------------------------ 5 fences --

printf '\n%s\n' '-- fences --'

D=$(fixture t-fences)
{
    printf '# notes\n\n'
    printf '```\n'
    printf 'closed block\n'
    printf '```\n\n'
    printf '```\n'
    printf 'this one never closes\n'
} > "$D/notes.md"
run "$SCRIPTS/icm-check.sh" --fences "$D"
assert_rc "an odd fence count fails the check" 1
assert_out "the open fence is named in the report" "an odd count leaves a block open"

# ------------------------------------------------------------ 6 placeholders --

printf '\n%s\n' '-- placeholders --'

D=$(fixture t-place)
printf '# brief\n\nOwned by %s.\n' '{{BRAND_NAME}}' > "$D/brief.md"
run "$SCRIPTS/icm-check.sh" --placeholders "$D"
assert_rc "an unfilled placeholder fails the check" 1
assert_out "the placeholder is named in the report" "unfilled placeholder"

# -------------------------------------------------------- 7 plan is read only --

printf '\n%s\n' '-- plan --'

D=$(fixture t-plan)
printf 'keep me exactly as i am\n' > "$D/keep.txt"
mkdir -p "$D/src"
printf 'a src file\n' > "$D/src/a.txt"
snapshot "$D" > "$WORK/plan.before"
run "$SCRIPTS/icm-plan.sh" "$D"
assert_rc "plan on a fresh project exits clean" 0
snapshot "$D" > "$WORK/plan.after"
assert_same "plan wrote nothing outside .icm/" "$WORK/plan.before" "$WORK/plan.after"
assert_file "plan wrote .icm/plan.txt" "$D/.icm/plan.txt"

# ------------------------------------------------------- 8 apply never stomps --

printf '\n%s\n' '-- apply --'

D=$(fixture t-collide)
printf 'my own routing notes, written by a human\n' > "$D/CONTEXT.md"
cp "$D/CONTEXT.md" "$WORK/collide.orig"
run "$SCRIPTS/icm-plan.sh" "$D"
assert_rc "plan reports the collision" 1
assert_out "the collision is named in the plan" "COLLIDE"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_rc "apply reports the collision" 1
assert_same "apply left the existing CONTEXT.md byte identical" "$D/CONTEXT.md" "$WORK/collide.orig"
assert_file "apply parked the candidate in .icm/proposed/" "$D/.icm/proposed/CONTEXT.md"
snapshot "$D" > "$WORK/collide.1"
run "$SCRIPTS/icm-plan.sh" "$D"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_rc "reapplying still reports the collision" 1
assert_out "reapplying has nothing left to write" "nothing to do"
snapshot "$D" > "$WORK/collide.2"
assert_same "reapplying over a collision changed nothing" "$WORK/collide.1" "$WORK/collide.2"

# -------------------------------------------------------- 9 apply is a no-op --

D=$(fixture t-idem)
run "$SCRIPTS/icm-plan.sh" "$D"
assert_rc "plan on an empty project exits clean" 0
run "$SCRIPTS/icm-apply.sh" "$D"
assert_rc "first apply exits clean" 0
snapshot "$D" > "$WORK/idem.1"
run "$SCRIPTS/icm-plan.sh" "$D"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_rc "second apply exits clean" 0
assert_out "second apply says there is nothing to do" "nothing to do"
snapshot "$D" > "$WORK/idem.2"
assert_same "applying twice changed nothing on disk" "$WORK/idem.1" "$WORK/idem.2"

# ------------------------------------------------ 10 a fresh install verifies --

run "$SCRIPTS/icm-check.sh" "$D"
assert_rc "a freshly applied workspace passes icm-check --all" 0

# --------------------------------------------------------------- 11 rollback --

printf '\n%s\n' '-- rollback --'

D=$(fixture t-rollback)
{
    printf '# House rules\n\n'
    printf 'These are the instructions this project already had.\n'
} > "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$WORK/rollback.orig"
run "$SCRIPTS/icm-plan.sh" "$D"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_rc "apply over an existing CLAUDE.md exits clean" 0
assert_out "the existing CLAUDE.md was adopted" "adopted  CLAUDE.md"
assert_differs "apply changed CLAUDE.md" "$D/CLAUDE.md" "$WORK/rollback.orig"
assert_file "apply created IDENTITY.md" "$D/IDENTITY.md"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_rc "rollback exits clean" 0
assert_same "rollback restored CLAUDE.md byte identical" "$D/CLAUDE.md" "$WORK/rollback.orig"
assert_nofile "rollback removed the created IDENTITY.md" "$D/IDENTITY.md"
assert_nofile "rollback removed the created _config/ folder" "$D/_config"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_rc "rolling back twice is a no-op" 0
assert_out "the second rollback says the run is already undone" "already rolled back"
run "$SCRIPTS/icm-rollback.sh" --list "$D"
assert_rc "rollback --list exits 0" 0
assert_out "rollback --list marks the undone run" "already rolled back"

D=$(fixture t-rollback-edited)
run "$SCRIPTS/icm-plan.sh" "$D"
run "$SCRIPTS/icm-apply.sh" "$D"
printf '\nedited by a human after apply\n' >> "$D/IDENTITY.md"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_rc "rollback reports that it left an edited file alone" 1
assert_file "rollback did not delete the edited file" "$D/IDENTITY.md"
assert_out "rollback says the file is yours now" "it is yours now"

# ----------------------------------------------- 12 the one source of truth --

printf '\n%s\n' '-- one source of truth --'

D=$(fixture t-render)

# There is no template lookup any more, so a destination-named file planted in a
# toolkit directory cannot win, and an empty one cannot ship a zero-byte file.
TPLH="$WORK/tplhome"
mkdir -p "$TPLH/templates/wiki" "$TPLH/interview-templates/wiki"
cp "$ROOT/icm.defaults.json" "$TPLH/icm.defaults.json"
printf 'PLANTED OVERRIDE\n' > "$TPLH/templates/wiki/log.md"
printf 'PLANTED OVERRIDE\n' > "$TPLH/interview-templates/wiki/log.md"
: > "$TPLH/templates/wiki/index.md"
: > "$TPLH/interview-templates/wiki/index.md"

OUT=$( ( ICM_HOME="$TPLH"; icm_render wiki/log.md "$D" ) 2>&1 ); RC=$?
assert_rc "a planted destination-named file does not disturb the render" 0
assert_out "the built-in body is what gets written" "# Wiki Log"
if printf '%s\n' "$OUT" | grep -q 'PLANTED OVERRIDE'; then
    t_fail "nothing outside icm_lib.sh can win the render" "$OUT"
else
    t_pass "nothing outside icm_lib.sh can win the render"
fi

OUT=$( ( ICM_HOME="$TPLH"; icm_render wiki/index.md "$D" ) 2>&1 ); RC=$?
assert_rc "an empty planted file cannot ship a zero-byte managed file" 0
assert_out "the empty planted file lost to the built-in body" "# Knowledge Index"

# An empty body is refused loudly and nothing is written.
OUT=$( ( icm_body_wiki_log() { :; }; icm_render wiki/log.md "$D" ) 2>&1 ); RC=$?
assert_rc "an empty body is refused with exit 2" 2
assert_out "the empty-body refusal names the path" "wiki/log.md"
assert_out "the empty-body refusal says what was wrong" "rendered empty"

# A truncated body is refused by the required-section gate.
OUT=$( ( icm_body_wiki_index() { printf '# Knowledge Index\n'; }; icm_render wiki/index.md "$D" ) 2>&1 ); RC=$?
assert_rc "a truncated body is refused with exit 2" 2
assert_out "the truncation refusal names the missing section" "missing a required section"

# A body that still carries a double-brace placeholder is refused.
OUT=$( ( icm_body_gitignore_block() { printf '# {{TOOLKIT}}\n.icm/\n'; }; icm_render .gitignore "$D" ) 2>&1 ); RC=$?
assert_rc "a body with an unfilled placeholder is refused with exit 2" 2
assert_out "the placeholder refusal says what was wrong" "unfilled placeholder"

# A path with no body is refused, never improvised.
OUT=$( icm_render docs/whatever.md "$D" 2>&1 ); RC=$?
assert_rc "a path with no body is refused with exit 2" 2
assert_out "the closed set names the path it will not render" "no renderer for"

# Every path the manifest owns renders clean through the same gate.
icm_manifest | awk '{ print $2 }' > "$WORK/manifest.paths"
ALLBAD=""
while IFS= read -r _mp; do
    [ -n "$_mp" ] || continue
    if ( icm_render "$_mp" "$D" ) >/dev/null 2>&1; then
        :
    else
        ALLBAD="$ALLBAD $_mp"
    fi
done < "$WORK/manifest.paths"
if [ -z "$ALLBAD" ]; then
    t_pass "every managed path has a body that passes the render gate"
else
    t_fail "every managed path has a body that passes the render gate" "failed:$ALLBAD"
fi

# The demotion is self-enforcing: nothing under scripts/ may name the interview
# directory, and the lookup that used to read it may not come back.
if grep -rl 'interview-templates' "$SCRIPTS" >/dev/null 2>&1; then
    t_fail "no file under scripts/ names the interview template directory" "$(grep -rn 'interview-templates' "$SCRIPTS")"
else
    t_pass "no file under scripts/ names the interview template directory"
fi
if grep -q 'icm_template_for' "$SCRIPTS/icm_lib.sh"; then
    t_fail "the template lookup stays deleted" "icm_template_for is back in icm_lib.sh"
else
    t_pass "the template lookup stays deleted"
fi

# The shipped interview directory: every file is interview material, and nothing
# in it is named for a destination a script writes.
assert_file "the interview directory ships its own contract" "$ROOT/interview-templates/README.md"
if [ -d "$ROOT/templates" ]; then
    t_fail "there is no directory called templates/ next to the renderer" "$ROOT/templates still exists"
else
    t_pass "there is no directory called templates/ next to the renderer"
fi
find "$ROOT/interview-templates" -type f -print > "$WORK/tpl.files"
TPLBAD=""
TPLN=0
while IFS= read -r _tf; do
    [ -n "$_tf" ] || continue
    TPLN=$((TPLN + 1))
    case "$(basename "$_tf")" in
        *.tmpl|README.md) ;;
        *) TPLBAD="$TPLBAD $_tf" ;;
    esac
done < "$WORK/tpl.files"
if [ "$TPLN" -gt 0 ] && [ -z "$TPLBAD" ]; then
    t_pass "every shipped interview template carries .tmpl and none is destination-named"
else
    t_fail "every shipped interview template carries .tmpl and none is destination-named" "count=$TPLN bad:$TPLBAD"
fi

# Rule book agreement: every _config row in the manifest has a body and an arm.
icm_manifest | awk '$1 == "create" && index($2, "_config/") == 1 { print $2 }' > "$WORK/rulebooks"
RBN=0
while IFS= read -r _rb; do
    [ -n "$_rb" ] || continue
    RBN=$((RBN + 1))
    _rbf="icm_body_$(basename "$_rb" .md)"
    if grep -q "^$_rbf() {" "$SCRIPTS/icm_lib.sh" && grep -qF "$_rb)" "$SCRIPTS/icm_lib.sh"; then
        t_pass "$_rb has a body and a render arm"
    else
        t_fail "$_rb has a body and a render arm" "missing $_rbf or the icm_render arm for $_rb"
    fi
done < "$WORK/rulebooks"
if [ "$RBN" -eq 5 ]; then
    t_pass "the manifest installs exactly the five canonical rule books"
else
    t_fail "the manifest installs exactly the five canonical rule books" "found $RBN _config rows"
fi

# Routing closure: every path the root CONTEXT.md points at is installed by the
# manifest or already on disk. This does not compare two sources, it asserts the
# one remaining source is internally closed.
D=$(fixture t-closure)
icm_body_context_root "$D" > "$WORK/ctx.md"
awk -F'`' '/^\| / { for (i = 2; i <= NF; i += 2) { if ($i != "") print $i } }' "$WORK/ctx.md" \
    | sort -u > "$WORK/ctx.routes"
ROUTEBAD=""
while IFS= read -r _rt; do
    [ -n "$_rt" ] || continue
    case "$_rt" in
        */)
            if icm_manifest | awk -v d="$_rt" 'index($2, d) == 1 { f = 1 } END { exit f ? 0 : 1 }'; then
                continue
            fi
            ROUTEBAD="$ROUTEBAD $_rt"
            continue
            ;;
        */*|*.md) ;;
        *) continue ;;
    esac
    if [ -n "$(icm_role_of "$_rt")" ] || [ -e "$D/$_rt" ]; then
        continue
    fi
    ROUTEBAD="$ROUTEBAD $_rt"
done < "$WORK/ctx.routes"
if [ -z "$ROUTEBAD" ]; then
    t_pass "every routing target in the generated root CONTEXT.md is installed or exists"
else
    t_fail "every routing target in the generated root CONTEXT.md is installed or exists" "dangling:$ROUTEBAD"
fi

# ------------------------------------------------------------ 13 dirty repo --

printf '\n%s\n' '-- git --'

if command -v git >/dev/null 2>&1; then
    D=$(fixture t-dirty)
    ( cd "$D" && git init -q ) >/dev/null 2>&1
    printf 'uncommitted work\n' > "$D/wip.txt"
    run "$SCRIPTS/icm-plan.sh" "$D"
    assert_rc "plan refuses a dirty git repo" 2
    assert_out "the refusal explains itself" "uncommitted changes"
    run "$SCRIPTS/icm-plan.sh" --allow-dirty "$D"
    assert_rc "--allow-dirty overrides the refusal" 0
else
    printf 'note git is not on PATH, the dirty repo test was skipped\n'
fi

# ---------------------------------------------------------------- 14 spaces --

printf '\n%s\n' '-- spaces --'

case "$WORK" in
    *' '*) t_pass "the fixture root itself contains a space" ;;
    *)     t_fail "the fixture root itself contains a space" "WORK has no space: $WORK" ;;
esac

D=$(fixture "a project with spaces/deep folder")
# --archetype wiki on purpose: quick is the default and installs no job card,
# and this block exists to prove a nested managed path survives a space.
run "$SCRIPTS/icm-plan.sh" --archetype wiki "$D"
assert_rc "plan handles a target path with spaces" 0
run "$SCRIPTS/icm-apply.sh" "$D"
assert_rc "apply handles a target path with spaces" 0
assert_file "apply wrote IDENTITY.md under a spaced path" "$D/IDENTITY.md"
assert_file "apply wrote the job card under a spaced path" "$D/raw/CONTEXT.md"
run "$SCRIPTS/icm-check.sh" "$D"
assert_rc "check passes on a workspace under a spaced path" 0
assert_out "the spaced path survives into the report" "a project with spaces"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_rc "rollback handles a target path with spaces" 0
assert_nofile "rollback removed IDENTITY.md under a spaced path" "$D/IDENTITY.md"

# ----------------------------------------------------------------- 15 usage --

printf '\n%s\n' '-- usage --'

for S in icm-check icm-plan icm-apply icm-rollback; do
    run "$SCRIPTS/$S.sh" --help
    assert_rc "$S.sh --help exits 0" 0
    run "$SCRIPTS/$S.sh" --no-such-flag
    assert_rc "$S.sh rejects an unknown flag" 2
done

run "$SCRIPTS/icm-apply.sh" "$WORK"
assert_rc "apply refuses to run without a plan" 2
assert_out "apply says to run the plan first" "run icm-plan.sh first"

# =============================================================================
# Regression tests for the verified defect set (HUNT-FINDINGS.json), written
# against spec/CLI-CONTRACT.md. Every assertion below is on observable
# behaviour: bytes on disk, a file's type or mode, an exit code, or a printed
# line. Nothing here reaches into a shell function to ask it what it thinks.
#
# The suite that shipped passed 89/89 while eleven blockers were live. These
# are the holes it had.
# =============================================================================

# ---------------------------------------------------------- extra assertions --

assert_eq() {
    if [ "$2" = "$3" ]; then
        t_pass "$1"
    else
        t_fail "$1" "expected [$3], got [$2]"
    fi
}

assert_not_out() {
    if printf '%s\n' "$OUT" | grep -q -F -- "$2"; then
        t_fail "$1" "output should not have contained: $2
$OUT"
    else
        t_pass "$1"
    fi
}

assert_dir() {
    if [ -d "$2" ]; then
        t_pass "$1"
    else
        t_fail "$1" "missing directory: $2"
    fi
}

assert_symlink() {
    if [ -L "$2" ]; then
        t_pass "$1"
    else
        t_fail "$1" "not a symlink any more: $2 ($(ls -ld "$2" 2>&1))"
    fi
}

# The first ten characters of ls -l, which is the file type plus the mode.
# Portable across the BSD and GNU spellings, and it ignores a trailing @ or .
mode_of() {
    ls -ld "$1" 2>/dev/null | awk 'NR == 1 { print substr($1, 1, 10) }'
}

assert_mode() {
    _am_got=$(mode_of "$2")
    if [ "$_am_got" = "$3" ]; then
        t_pass "$1"
    else
        t_fail "$1" "expected mode $3 on $2, got $_am_got"
    fi
}

link_target() {
    ls -ld "$1" 2>/dev/null | sed 's/.* -> //'
}

link_count() {
    ls -ld "$1" 2>/dev/null | awk 'NR == 1 { print $2 + 0 }'
}

bytes_of() {
    [ -f "$1" ] || { printf '0\n'; return 0; }
    wc -c < "$1" | awk '{ print $1 + 0 }'
}

files_under() {
    find "$1" -type f 2>/dev/null | wc -l | awk '{ print $1 + 0 }'
}

# The disposition the plan artifact records for one managed path. The plan is
# a documented artifact (CLI-CONTRACT section 4), so reading it is fair game;
# the field split is whitespace so this holds for the space-separated format
# and for the tab-separated five-column one.
plan_status() {
    [ -f "$1/.icm/plan.txt" ] || { printf 'NO-PLAN\n'; return 0; }
    awk -v p="$2" '
        $1 == "#" { next }
        /^#/      { next }
        { for (i = 1; i <= NF; i++) if ($i == p) { print $1; exit } }
    ' "$1/.icm/plan.txt"
}

newest_run() {
    [ -d "$1/.icm/backup" ] || return 0
    ( cd "$1/.icm/backup" && ls ) 2>/dev/null | sort | tail -n 1
}

# Run a command with a wall-clock cap, so a defect that hangs fails the suite
# instead of freezing it. Sets OUT, RC and TIMEDOUT.
run_capped() {
    _rc_lim="$1"
    shift
    _rc_out="$WORK/capped.out"
    _rc_st="$WORK/capped.status"
    rm -f "$_rc_out" "$_rc_st"
    ( "$@" > "$_rc_out" 2>&1; printf '%s\n' "$?" > "$_rc_st" ) &
    _rc_pid=$!
    _rc_i=0
    while [ "$_rc_i" -lt "$_rc_lim" ]; do
        [ -f "$_rc_st" ] && break
        sleep 1
        _rc_i=$((_rc_i + 1))
    done
    if [ -f "$_rc_st" ]; then
        RC=$(cat "$_rc_st")
        TIMEDOUT=0
    else
        RC=124
        TIMEDOUT=1
        kill -9 "$_rc_pid" 2>/dev/null || true
    fi
    OUT=$(cat "$_rc_out" 2>/dev/null)
    wait "$_rc_pid" 2>/dev/null || true
    if [ "$VERBOSE" -eq 1 ]; then
        printf '     $ %s\n' "$*"
        printf '%s\n' "$OUT" | sed 's/^/     > /'
    fi
    return 0
}

AM_ROOT=0
if [ "$(id -u 2>/dev/null || printf 1)" = "0" ]; then
    AM_ROOT=1
fi

# ------------------------------------------------ 16 concurrent applies ICM-01 --

printf '\n%s\n' '-- concurrency --'

# The lock is the mutex. CLI-CONTRACT 5.3: apply takes .icm/lock immediately
# after the plan-target check and before the stamp, and a second run refuses.
D=$(fixture "t-lock held")
printf '# Acme\n\nTHE ONLY COPY OF OUR RULES\n' > "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$WORK/lock.orig"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
mkdir -p "$D/.icm/lock"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_rc "apply refuses to run while another apply holds the lock" 2
assert_out "the lock refusal says another apply is running" "another apply is running"
assert_same "the locked-out apply changed nothing" "$D/CLAUDE.md" "$WORK/lock.orig"
assert_nofile "the locked-out apply wrote no managed file" "$D/IDENTITY.md"
rmdir "$D/.icm/lock" 2>/dev/null || rm -rf "$D/.icm/lock"

# Two applies racing over one target must never leave the user's original
# bytes nowhere on disk. Roll every recorded run back, then compare.
D=$(fixture "t-concurrent apply")
printf '# Acme\n\nTHE ONLY COPY, hand written\n' > "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$WORK/conc.orig"
"$SCRIPTS/icm-plan.sh" "$D" --quiet > /dev/null 2>&1
"$SCRIPTS/icm-apply.sh" "$D" > "$WORK/conc.a" 2>&1 &
CP1=$!
"$SCRIPTS/icm-apply.sh" "$D" > "$WORK/conc.b" 2>&1 &
CP2=$!
wait "$CP1" 2>/dev/null || true
wait "$CP2" 2>/dev/null || true
CI=0
while [ "$CI" -lt 4 ]; do
    "$SCRIPTS/icm-rollback.sh" "$D" > /dev/null 2>&1 || true
    CI=$((CI + 1))
done
assert_same "two concurrent applies leave the original CLAUDE.md recoverable" \
    "$D/CLAUDE.md" "$WORK/conc.orig"

# A stamp that is only a whole second is not unique. CLI-CONTRACT 5.2 makes it
# <UTC>-<pid>, so the run directory name carries a suffix.
D=$(fixture "t-stamp unique")
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
STAMP1=$(newest_run "$D")
case "$STAMP1" in
    *Z-*) t_pass "the backup stamp carries a per-process suffix" ;;
    *)    t_fail "the backup stamp carries a per-process suffix" "stamp was: $STAMP1" ;;
esac

# CLI-CONTRACT 5.5: a MODIFIED row whose pre and post hashes are equal cannot
# be produced by a correct run. Rollback must refuse it, never restore from it.
D=$(fixture "t-pre equals post")
printf '# Acme\n\nORIGINAL HAND WRITTEN RULES\n' > "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
PPRUN=$(newest_run "$D")
if [ -n "$PPRUN" ] && [ -f "$D/.icm/backup/$PPRUN/manifest.txt" ]; then
    cp "$D/CLAUDE.md" "$WORK/prepost.applied"
    cp "$D/CLAUDE.md" "$D/.icm/backup/$PPRUN/files/CLAUDE.md"
    awk '
        $1 == "MODIFIED" && $2 == "CLAUDE.md" {
            if (NF >= 5) { printf "%s\t%s\t%s\t%s\t%s\n", $1, $2, $4, $4, $5 }
            else         { printf "%s %s %s %s\n", $1, $2, $4, $4 }
            next
        }
        { print }
    ' "$D/.icm/backup/$PPRUN/manifest.txt" > "$WORK/prepost.manifest"
    cp "$WORK/prepost.manifest" "$D/.icm/backup/$PPRUN/manifest.txt"
    run "$SCRIPTS/icm-rollback.sh" "$D"
    assert_same "rollback refuses a MODIFIED row whose pre and post hashes match" \
        "$D/CLAUDE.md" "$WORK/prepost.applied"
    assert_rc "that refusal is reported, not swallowed" 1
    assert_not_out "rollback does not call that run clean" "result: clean"
else
    t_fail "rollback refuses a MODIFIED row whose pre and post hashes match" \
        "no manifest was written for run [$PPRUN], so the row could not be tested"
fi

# ------------------------------------- 17 interrupted or aborted apply ICM-02 --

printf '\n%s\n' '-- interruption --'

if [ "$AM_ROOT" -eq 0 ]; then
    D=$(fixture "t-abort midwrite")
    mkdir -p "$D/_config"
    printf 'vendored, do not touch\n' > "$D/_config/vendor-notes.md"
    cp "$D/_config/vendor-notes.md" "$WORK/vendor.orig"
    printf '# Acme\n\nhand written rules\n' > "$D/CLAUDE.md"
    cp "$D/CLAUDE.md" "$WORK/abort.orig"
    run "$SCRIPTS/icm-plan.sh" "$D" --quiet
    chmod 555 "$D/_config"
    run "$SCRIPTS/icm-apply.sh" "$D"
    ABORT_RC=$RC
    ABORT_OUT=$OUT
    chmod 755 "$D/_config"
    RC=$ABORT_RC
    OUT=$ABORT_OUT
    assert_rc "an apply that cannot finish exits 3, not the collision status" 3
    assert_out "the aborted apply says it aborted" "apply aborted"
    assert_out "the aborted apply names the rollback command" "icm-rollback.sh"
    ARUN=$(newest_run "$D")
    assert_file "an aborted apply still leaves a durable manifest" \
        "$D/.icm/backup/$ARUN/manifest.txt"
    assert_nofile "an aborted run is not marked COMPLETE" \
        "$D/.icm/backup/$ARUN/COMPLETE"
    run "$SCRIPTS/icm-rollback.sh" "$D"
    if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q -F 'result: clean' \
       && [ -e "$D/IDENTITY.md" ]; then
        t_fail "rollback never reports clean while an interrupted run's files remain" "$OUT"
    else
        t_pass "rollback never reports clean while an interrupted run's files remain"
    fi
    assert_same "the vendored file in the read-only folder is untouched" \
        "$D/_config/vendor-notes.md" "$WORK/vendor.orig"
else
    printf 'note running as root, the read-only abort test was skipped\n'
fi

# A run directory with no manifest must not be advertised as rollback-able.
D=$(fixture "t-list incomplete")
mkdir -p "$D/.icm/backup/20200101T000000Z-1"
run "$SCRIPTS/icm-rollback.sh" --list "$D"
assert_out "--list marks a run with no manifest as unusable" "cannot be rolled back"
assert_not_out "--list does not offer a run that --stamp would refuse" "ok   20200101T000000Z-1"

# Ctrl-C. CLI-CONTRACT 5.4: a trap handler that does not exit returns to the
# script, so SIGINT has to stop the run, not just delete its work directory.
INTOUT="$WORK/sigint.out"
# POSIX: a non-interactive shell sets INT and QUIT to SIG_IGN for every job in
# an asynchronous list while job control is off, and a script cannot trap a
# signal that was ignored on entry. `set -m` fixes that in some shells and does
# nothing in dash, which has no job control, so launching apply with & measures
# the harness rather than the toolkit and the result differs by shell.
#
# So apply is run in the FOREGROUND of a wrapper, where nothing has ignored INT
# for it, and a watcher inside that wrapper signals it once the run has taken
# its stamp. `$$` keeps the wrapper's pid inside the subshell, and `exec` gives
# that pid to apply, so the signal lands on the run itself.
INTWRAP="$WORK/sigint-wrapper.sh"
cat > "$INTWRAP" <<'ICM_INTWRAP'
OUTF=$1
TGT=$2
APPLY=$3
(
    _n=0
    while [ "$_n" -lt 20000000 ]; do
        [ -d "$TGT/.icm/backup" ] && break
        _n=$((_n + 1))
    done
    kill -INT $$ 2>/dev/null
) &
exec "$APPLY" "$TGT" > "$OUTF" 2>&1
ICM_INTWRAP
# The watcher and the run race, and on a loaded machine the run can finish
# first. That is a slow machine, not a passing toolkit, so retry rather than
# weaken the assertion. The wiki archetype is used because it has the most
# writes, which is the widest window to land the signal in.
INTTRY=0
while [ "$INTTRY" -lt 5 ]; do
    INTTRY=$((INTTRY + 1))
    D=$(fixture "t-sigint")
    printf '# Acme\n\nrules\n' > "$D/CLAUDE.md"
    run "$SCRIPTS/icm-plan.sh" --archetype wiki "$D" --quiet
    : > "$INTOUT"
    sh "$INTWRAP" "$INTOUT" "$D" "$SCRIPTS/icm-apply.sh"
    RC=$?
    OUT=$(cat "$INTOUT" 2>/dev/null)
    [ "$RC" -eq 130 ] && break
done
assert_rc "SIGINT stops apply with the conventional 130" 130
assert_not_out "an interrupted apply never claims it finished clean" "result: clean"

# ------------------------ 18 anything that is not a regular file ICM-03/06/07 --

printf '\n%s\n' '-- non regular files --'

# A dangling symlink: -e is false for it, so it used to be classified CREATE,
# overwritten with no backup, then deleted outright by rollback.
D=$(fixture "t-link dangling")
ln -s "generated/CLAUDE.md" "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
assert_eq "a dangling symlink at a managed path plans as COLLIDE" \
    "$(plan_status "$D" CLAUDE.md)" "COLLIDE"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_symlink "apply left the dangling symlink in place" "$D/CLAUDE.md"
assert_eq "the dangling link still points where it did" \
    "$(link_target "$D/CLAUDE.md")" "generated/CLAUDE.md"
assert_file "apply parked the candidate instead of writing through the link" \
    "$D/.icm/proposed/CLAUDE.md"
assert_file "the collide branch wrote the promised diff" \
    "$D/.icm/proposed/CLAUDE.md.diff"
DRUN=$(newest_run "$D")
assert_file "a run that collided still records a manifest" \
    "$D/.icm/backup/$DRUN/manifest.txt"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_symlink "rollback did not delete the user's symlink" "$D/CLAUDE.md"

# A live symlink into a shared file. rename(2) replaces the link itself.
D=$(fixture "t-link live")
mkdir -p "$WORK/shared house"
printf '# Monorepo house rules\n\nshared across twelve repos\n' > "$WORK/shared house/CLAUDE.md"
cp "$WORK/shared house/CLAUDE.md" "$WORK/shared.orig"
ln -s "$WORK/shared house/CLAUDE.md" "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
assert_eq "a live symlink at a managed path plans as COLLIDE" \
    "$(plan_status "$D" CLAUDE.md)" "COLLIDE"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_symlink "apply did not turn a symlinked CLAUDE.md into a regular file" "$D/CLAUDE.md"
assert_same "the shared file behind the link is untouched" \
    "$WORK/shared house/CLAUDE.md" "$WORK/shared.orig"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_symlink "rollback left the symlink a symlink" "$D/CLAUDE.md"

# A hard link. Either apply keeps the link, or it refuses and leaves the file
# byte identical. Silently severing it and reporting clean is the defect.
D=$(fixture "t-link hard")
mkdir -p "$WORK/hardlinked"
printf '# Shared rules\n\ntwo names, one inode\n' > "$WORK/hardlinked/CLAUDE.md"
cp "$WORK/hardlinked/CLAUDE.md" "$WORK/hard.orig"
ln "$WORK/hardlinked/CLAUDE.md" "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
if [ "$(link_count "$D/CLAUDE.md")" -ge 2 ] || cmp -s "$D/CLAUDE.md" "$WORK/hard.orig"; then
    t_pass "apply does not silently sever a hard-linked CLAUDE.md"
else
    t_fail "apply does not silently sever a hard-linked CLAUDE.md" \
        "link count is $(link_count "$D/CLAUDE.md") and the content changed"
fi
assert_same "the other name for a hard-linked file still holds its content" \
    "$WORK/hardlinked/CLAUDE.md" "$WORK/hard.orig"

# A directory sitting at a managed path.
D=$(fixture "t-link dir")
mkdir -p "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
assert_eq "a directory at a managed path plans as COLLIDE" \
    "$(plan_status "$D" CLAUDE.md)" "COLLIDE"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_dir "apply left the directory at the managed path alone" "$D/CLAUDE.md"
XRUN=$(newest_run "$D")
assert_file "a directory collision still records a manifest" \
    "$D/.icm/backup/$XRUN/manifest.txt"

# A FIFO. cp and the hashers block forever on one with no writer, so this test
# is capped: a hang fails the suite rather than freezing it.
D=$(fixture "t-link fifo")
if mkfifo "$D/CLAUDE.md" 2>/dev/null; then
    run "$SCRIPTS/icm-plan.sh" "$D" --quiet
    assert_eq "a FIFO at a managed path plans as COLLIDE" \
        "$(plan_status "$D" CLAUDE.md)" "COLLIDE"
    run_capped 20 "$SCRIPTS/icm-apply.sh" "$D"
    if [ "$TIMEDOUT" -eq 1 ]; then
        t_fail "apply never blocks on a FIFO at a managed path" \
            "apply was still running after 20 seconds and had to be killed"
        ( printf '' > "$D/CLAUDE.md" 2>/dev/null ) &
        UNBLOCK=$!
        sleep 1
        kill -9 "$UNBLOCK" 2>/dev/null || true
    else
        t_pass "apply never blocks on a FIFO at a managed path"
    fi
    if [ -p "$D/CLAUDE.md" ]; then
        t_pass "apply left the FIFO at the managed path alone"
    else
        t_fail "apply left the FIFO at the managed path alone" \
            "$(ls -ld "$D/CLAUDE.md" 2>&1)"
    fi
    rm -f "$D/CLAUDE.md"
else
    printf 'note mkfifo is unavailable, the FIFO test was skipped\n'
fi

# A managed folder that is a symlink pointing outside the target. The textual
# guard on the relative path cannot see this; only resolving the parent can.
D=$(fixture "t-dirlink escape")
OUTSIDE="$WORK/outside the target"
rm -rf "$OUTSIDE"
mkdir -p "$OUTSIDE"
ln -s "$OUTSIDE" "$D/_config"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
assert_eq "apply writes nothing outside the target through a symlinked folder" \
    "$(files_under "$OUTSIDE")" "0"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_dir "rollback does not remove a directory outside the target" "$OUTSIDE"
rm -f "$D/_config"

# ------------------------------------------- 19 the managed block is ICM-04 --

printf '\n%s\n' '-- managed block --'

# Begin marker, no end marker. icm_splice starts skipping at the begin marker
# and never stops, so everything after it used to be silently deleted.
D=$(fixture "t-block no end")
{
    printf '# Acme API\n\n'
    printf '%s\n' '<!-- icm:begin -->'
    printf '@IDENTITY.md\n\n'
    printf '## Deploy runbook\n\n'
    printf '1. freeze the queue\n'
    printf '2. migrations on the replica first\n\n'
    printf '## On call\n\n'
    printf 'Escalate to the DB owner after fifteen minutes.\n'
} > "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$WORK/block.noend.orig"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
assert_eq "a managed block with no end marker plans as COLLIDE" \
    "$(plan_status "$D" CLAUDE.md)" "COLLIDE"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_same "apply loses no line from a file whose end marker is missing" \
    "$D/CLAUDE.md" "$WORK/block.noend.orig"

# A lone end marker in ordinary prose was consumed and dropped.
D=$(fixture "t-block stray end")
{
    printf '# Project\n\nSome rules.\n\n'
    printf '%s\n' '<!-- icm:end -->'
    printf '\nMore rules after the stray marker.\n'
} > "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$WORK/block.strayend.orig"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
assert_same "a stray end marker in the user's prose is never deleted" \
    "$D/CLAUDE.md" "$WORK/block.strayend.orig"

# Two begin markers is also a malformed set.
D=$(fixture "t-block two begins")
{
    printf '# Project\n\n'
    printf '%s\n' '<!-- icm:begin -->'
    printf '@IDENTITY.md\n'
    printf '%s\n' '<!-- icm:begin -->'
    printf '@CONTEXT.md\n'
    printf '%s\n' '<!-- icm:end -->'
    printf '\nOur own rules below.\n'
} > "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$WORK/block.two.orig"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
assert_eq "a duplicated begin marker plans as COLLIDE" \
    "$(plan_status "$D" CLAUDE.md)" "COLLIDE"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_same "apply does not splice into a duplicated marker set" \
    "$D/CLAUDE.md" "$WORK/block.two.orig"

# The control. A well-formed block adopts, and everything outside it survives.
D=$(fixture "t-block wellformed")
printf '# Acme API\n' > "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
{
    printf '\n## Deploy runbook\n\n'
    printf 'Freeze the queue first.\n'
} >> "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$WORK/block.good.orig"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
assert_same "sections added below a well-formed block survive a reapply" \
    "$D/CLAUDE.md" "$WORK/block.good.orig"

# --------------------------------- 20 hand edited and stale plans ICM-05/11 --

printf '\n%s\n' '-- plan artifact --'

# A duplicated row used to be executed twice, the second pass storing the
# post-apply file as the pre-image.
D=$(fixture "t-plan duplicate row")
printf '# Acme\n\nTHE ONLY COPY OF OUR HAND WRITTEN RULES\n' > "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$WORK/dup.orig"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
awk '{ print; if ($1 != "#" && $3 == "CLAUDE.md") print }' "$D/.icm/plan.txt" > "$WORK/dup.plan"
cp "$WORK/dup.plan" "$D/.icm/plan.txt"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_rc "apply refuses a plan that lists the same path twice" 2
assert_out "the refusal names the duplication" "same path twice"
assert_same "a duplicated plan row changes nothing" "$D/CLAUDE.md" "$WORK/dup.orig"
assert_nofile "a refused plan writes no managed file at all" "$D/IDENTITY.md"

# A CRLF plan. The refusal used to name two strings that render identically.
D=$(fixture "t-plan crlf")
printf '# p\n' > "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
CR=$(printf '\r')
sed "s/\$/$CR/" "$D/.icm/plan.txt" > "$WORK/crlf.plan"
cp "$WORK/crlf.plan" "$D/.icm/plan.txt"
run "$SCRIPTS/icm-apply.sh" "$D"
if printf '%s\n' "$OUT" | grep -q 'the plan was written for [^[]'; then
    t_fail "a CRLF plan never produces a refusal naming two identical strings" "$OUT"
else
    t_pass "a CRLF plan never produces a refusal naming two identical strings"
fi

# A stale plan. CLI-CONTRACT 3.4: apply is not a staleness gate. It
# re-classifies every row live and warns, and it never writes over the change.
D=$(fixture "t-plan stale")
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
printf '# hand written identity, do not lose this\n' > "$D/IDENTITY.md"
cp "$D/IDENTITY.md" "$WORK/stale.orig"
run "$SCRIPTS/icm-apply.sh" "$D"
assert_out "apply warns when a row changed since the plan was written" \
    "changed since the plan was written"
assert_same "apply never writes over the file that changed" \
    "$D/IDENTITY.md" "$WORK/stale.orig"
assert_rc "apply reports the collision it found live" 1

# never_write matches at any depth, not only the first path component.
D=$(fixture "t-never write depth")
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
NWTAB=$(printf '\t')
{
    cat "$D/.icm/plan.txt"
    printf 'CREATE%screate%sdocs/sub/node_modules/x.md%s-%snever_write depth\n' \
        "$NWTAB" "$NWTAB" "$NWTAB" "$NWTAB"
    printf 'CREATE%screate%sa/.git/config%s-%snever_write depth\n' \
        "$NWTAB" "$NWTAB" "$NWTAB" "$NWTAB"
} > "$WORK/nw.plan"
run "$SCRIPTS/icm-apply.sh" --plan "$WORK/nw.plan" "$D"
assert_out "a never_write name below the first component is refused" \
    "refusing docs/sub/node_modules/x.md"
assert_out "a never_write name inside a nested path is refused" \
    "refusing a/.git/config"
assert_nofile "the refused nested node_modules path was not created" \
    "$D/docs/sub/node_modules/x.md"
assert_nofile "the refused nested .git path was not created" "$D/a/.git/config"

# ---------------------------------------------------- 21 file modes ICM-08 --

printf '\n%s\n' '-- modes --'

D=$(fixture "t-mode readonly")
printf '# Acme\n\nread only on purpose\n' > "$D/CLAUDE.md"
cp "$D/CLAUDE.md" "$WORK/mode444.orig"
chmod 444 "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
assert_mode "a read-only file keeps its mode through apply" "$D/CLAUDE.md" "-r--r--r--"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_mode "a read-only file keeps its mode through rollback" "$D/CLAUDE.md" "-r--r--r--"
chmod 644 "$D/CLAUDE.md" 2>/dev/null || true

D=$(fixture "t-mode private")
printf '# private instructions\n\nnot for other accounts\n' > "$D/CLAUDE.md"
chmod 600 "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
assert_mode "a mode 600 file is not widened to 644 by apply" "$D/CLAUDE.md" "-rw-------"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_mode "a mode 600 file is not widened to 644 by rollback" "$D/CLAUDE.md" "-rw-------"
chmod 644 "$D/CLAUDE.md" 2>/dev/null || true

# ------------------------------------- 22 rollback and existing dirs ICM-09 --

printf '\n%s\n' '-- rollback pruning --'

D=$(fixture "t-prune existing dirs")
mkdir -p "$D/_config" "$D/_log"
printf '# p\n' > "$D/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
run "$SCRIPTS/icm-rollback.sh" "$D"
assert_rc "rollback over pre-existing folders exits clean" 0
assert_dir "rollback kept the _config/ folder the project already had" "$D/_config"
assert_dir "rollback kept the _log/ folder the project already had" "$D/_log"

# ---------------------------------------------------- 23 bad targets ICM-10 --

printf '\n%s\n' '-- target refusals --'

DASHP="$WORK/dash parent"
rm -rf "$DASHP"
mkdir -p "$DASHP"
mkdir -- "$DASHP/-weird proj"
printf '# p\n' > "$DASHP/-weird proj/CLAUDE.md"
OUT=$( cd "$DASHP" && "$SCRIPTS/icm-plan.sh" "-weird proj" 2>&1 )
RC=$?
if { [ "$RC" -eq 0 ] && [ -f "$DASHP/-weird proj/.icm/plan.txt" ]; } \
   || { [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q '^FAIL'; }; then
    t_pass "a target whose name starts with a dash either plans or refuses with exit 2"
else
    t_fail "a target whose name starts with a dash either plans or refuses with exit 2" \
        "rc=$RC
$OUT"
fi
assert_not_out "a dash-named target never surfaces a raw shell cd error" "invalid option"
assert_not_out "a dash-named target never surfaces the shell's own cd usage" "usage: cd"

if [ "$AM_ROOT" -eq 0 ]; then
    NOTRAV="$WORK/no traverse"
    rm -rf "$NOTRAV"
    mkdir -p "$NOTRAV"
    chmod 000 "$NOTRAV"
    run "$SCRIPTS/icm-plan.sh" "$NOTRAV"
    assert_rc "a target that cannot be traversed is refused with exit 2" 2
    assert_out "the untraversable target refusal is framed as a FAIL" "FAIL"
    chmod 755 "$NOTRAV"
else
    printf 'note running as root, the untraversable target test was skipped\n'
fi

D=$(fixture "t-icm is a file")
printf 'not a directory\n' > "$D/.icm"
run "$SCRIPTS/icm-plan.sh" "$D"
assert_rc ".icm existing as a regular file is refused with exit 2" 2
assert_out "the .icm refusal is framed as a FAIL" "FAIL"

# ------------------------------- 24 drift and folder names with spaces F4 --

printf '\n%s\n' '-- drift with spaces --'

D=$(fixture "t-drift inside spaces")
mkdir -p "$D/01 - research notes" "$D/FINAL FINAL v3"
printf 'a note\n' > "$D/01 - research notes/a.md"
printf 'a draft\n' > "$D/FINAL FINAL v3/b.md"
printf 'a top level note\n' > "$D/notes.txt"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
run "$SCRIPTS/icm-check.sh" --drift "$D"
assert_rc "the drift check passes on a tree the toolkit generated seconds ago" 0
if printf '%s\n' "$OUT" | grep -q '^warn'; then
    t_fail "a folder name with spaces produces no drift warning" "$OUT"
else
    t_pass "a folder name with spaces produces no drift warning"
fi
assert_not_out "the drift check never reports a folder name truncated at its first space" \
    "not on disk: 01"
assert_not_out "the drift check never reports a truncated capitalised folder name" \
    "not on disk: FINAL"

# ------------------------------------------ 24b a workspace nested in a repo --

# A folder that carries its own IDENTITY.md is a workspace root in its own
# right. Its CONTEXT.md is layer 1, not a job card, and its tree is mapped by
# its own IDENTITY.md. Without that the toolkit could not ship the worked
# example workspaces under examples/ and still grade itself clean.

printf '\n%s\n' '-- nested workspace roots --'

D=$(fixture "t-nested root")
mkdir -p "$D/inner"
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
run "$SCRIPTS/icm-plan.sh" "$D/inner" --quiet
run "$SCRIPTS/icm-apply.sh" "$D/inner"

# The job card folder is created after the inner apply, so the inner map does
# not document it yet and the outer map never should.
mkdir -p "$D/inner/01-stage"
{
    printf '# 01 stage\n\n## Purpose\n\nA job card.\n\n## Inputs\n\n- none\n'
    printf '\n## Process\n\n1. Do it.\n\n## Outputs\n\n- none\n\n## Routing\n\n- done\n'
} > "$D/inner/01-stage/CONTEXT.md"

run "$SCRIPTS/icm-check.sh" --only sections "$D"
assert_rc "the nested root CONTEXT.md is graded as layer 1, not as a job card" 0
assert_not_out "the nested root CONTEXT.md is not asked for a Purpose section" \
    "inner/CONTEXT.md is missing"

run "$SCRIPTS/icm-check.sh" --only drift "$D"
assert_rc "the outer map is not asked to document a nested root's job cards" 0
assert_out "the drift check says the nested root grades itself" "nested workspace root"

run "$SCRIPTS/icm-check.sh" --only drift "$D/inner"
assert_rc "the nested root's own map must still cover its own job card folders" 1
assert_out "the nested root names its own undocumented job card folder" "01-stage"

# --------------------------------------- 25 the built-in bodies win TPL-1/7 --

printf '\n%s\n' '-- bodies --'

TKC="$WORK/toolkit copy"
rm -rf "$TKC"
mkdir -p "$TKC"
cp -R "$ROOT/." "$TKC/" 2>/dev/null || true
rm -rf "$TKC/.git" "$TKC/.icm"

if [ -f "$TKC/scripts/icm-plan.sh" ]; then
    mkdir -p "$TKC/templates"
    : > "$TKC/templates/IDENTITY.md"
    D=$(fixture "t-body empty template")
    run "$TKC/scripts/icm-plan.sh" "$D" --quiet
    run "$TKC/scripts/icm-apply.sh" "$D"
    if [ "$(bytes_of "$D/IDENTITY.md")" -gt 0 ]; then
        t_pass "an empty file in templates/ never ships a zero byte managed file"
    else
        t_fail "an empty file in templates/ never ships a zero byte managed file" \
            "$D/IDENTITY.md is $(bytes_of "$D/IDENTITY.md") bytes"
    fi
    run "$TKC/scripts/icm-check.sh" "$D"
    assert_rc "the workspace built that way still passes the full check" 0

    if [ "$AM_ROOT" -eq 0 ]; then
        printf '# %s\n\nA body.\n' '{{PROJECT_NAME}}' > "$TKC/templates/IDENTITY.md"
        chmod 000 "$TKC/templates/IDENTITY.md"
        D=$(fixture "t-body unreadable template")
        run "$TKC/scripts/icm-plan.sh" "$D"
        assert_rc "an unreadable file in templates/ does not abort the plan" 0
        assert_file "the plan was still written" "$D/.icm/plan.txt"
        assert_not_out "a template problem is never a bare awk error" "awk:"
        chmod 644 "$TKC/templates/IDENTITY.md"
    else
        printf 'note running as root, the unreadable template test was skipped\n'
    fi

    # REC-UNIFY, tested from the outside: deleting the template directory
    # outright must not change one byte of what a workspace receives.
    TKB="$WORK/toolkit bare"
    rm -rf "$TKB"
    mkdir -p "$TKB"
    cp -R "$ROOT/." "$TKB/" 2>/dev/null || true
    rm -rf "$TKB/.git" "$TKB/.icm" "$TKB/templates" "$TKB/interview-templates"
    rm -rf "$WORK/full home" "$WORK/bare home"
    mkdir -p "$WORK/full home/ws" "$WORK/bare home/ws"
    "$SCRIPTS/icm-plan.sh" "$WORK/full home/ws" --quiet > /dev/null 2>&1
    "$SCRIPTS/icm-apply.sh" "$WORK/full home/ws" > /dev/null 2>&1
    "$TKB/scripts/icm-plan.sh" "$WORK/bare home/ws" --quiet > /dev/null 2>&1
    "$TKB/scripts/icm-apply.sh" "$WORK/bare home/ws" > /dev/null 2>&1
    snapshot "$WORK/full home/ws" > "$WORK/tpl.full"
    snapshot "$WORK/bare home/ws" > "$WORK/tpl.bare"
    assert_same "a toolkit with no template directory writes the same bytes" \
        "$WORK/tpl.full" "$WORK/tpl.bare"
else
    t_fail "the toolkit can be copied for the template tests" "no scripts under $TKC"
fi

# ------------------------------------------------ 26 the rule books TPL-2 --

printf '\n%s\n' '-- rule books --'

D=$(fixture "t-rule books")
run "$SCRIPTS/icm-plan.sh" "$D" --quiet
run "$SCRIPTS/icm-apply.sh" "$D"
for RB in conventions glossary voice style; do
    assert_file "apply installs the canonical rule book _config/$RB.md" "$D/_config/$RB.md"
done
assert_nofile "the retired _config/writing-rules.md is not installed" "$D/_config/writing-rules.md"
assert_nofile "the retired _config/grounding-rules.md is not installed" "$D/_config/grounding-rules.md"
run "$SCRIPTS/icm-check.sh" --routes "$D"
assert_rc "every route in the generated CONTEXT.md resolves on disk" 0

# TPL-2 was a vocabulary split, and it has two halves. The two rule books the
# scripts installed were named in zero markdown files anywhere in the repo,
# and the four names the whole documentation set taught were installed by
# nothing. Both halves have to hold, so both are asserted.
#
# This is deliberately not "every _config/*.md named anywhere is canonical":
# spec/layers.md and spec/budgets.md rightly use a sales workspace's own
# _config/objections.md as a worked example, and a project's own rule books
# are its own business. What is under test is the set the toolkit installs.
doc_mentions() {
    find "$ROOT" -name '.git' -prune -o -name '*.md' -print 2>/dev/null \
        | grep -v '/spec/CLI-CONTRACT.md$' \
        | grep -v '/tests/' \
        | while IFS= read -r _dm_f; do
              if grep -q -F -- "$1" "$_dm_f" 2>/dev/null; then
                  printf 'hit\n'
              fi
          done | grep -q hit
}

RBMISS=0
for RB in conventions glossary voice style grounding; do
    if doc_mentions "_config/$RB.md"; then
        :
    else
        RBMISS=$((RBMISS + 1))
        printf '     | installed, but named in no shipped document: _config/%s.md\n' "$RB"
    fi
done
if [ "$RBMISS" -eq 0 ]; then
    t_pass "every rule book the toolkit installs is named in the documentation"
else
    t_fail "every rule book the toolkit installs is named in the documentation" \
        "$RBMISS installed rule book(s) that no document mentions"
fi

RBOLD=0
for RB in writing-rules grounding-rules; do
    if doc_mentions "_config/$RB.md"; then
        RBOLD=$((RBOLD + 1))
        printf '     | retired rule book still named in a document: _config/%s.md\n' "$RB"
    fi
    if grep -r -q -F "_config/$RB.md" "$SCRIPTS" 2>/dev/null; then
        RBOLD=$((RBOLD + 1))
        printf '     | retired rule book still named under scripts/: _config/%s.md\n' "$RB"
    fi
done
if [ "$RBOLD" -eq 0 ]; then
    t_pass "the retired rule book names survive nowhere in the toolkit"
else
    t_fail "the retired rule book names survive nowhere in the toolkit" \
        "$RBOLD surviving mention(s) of a name CLI-CONTRACT section 8 retires"
fi

# ------------------------------------------- 27 one name per artifact F2/F13 --

printf '\n%s\n' '-- artifact names --'

PLANBAD="$WORK/planname.bad"
: > "$PLANBAD"
find "$ROOT" -name '.git' -prune -o -name '*.md' -print 2>/dev/null \
    | grep -v '/spec/CLI-CONTRACT.md$' \
    | while IFS= read -r PNF; do
          if grep -q -F -e '.icm/plan.tsv' -e '.icm/plan.md' -e '.icm/applied-' "$PNF" 2>/dev/null; then
              printf '%s\n' "$PNF"
          fi
      done > "$PLANBAD"
if [ -s "$PLANBAD" ]; then
    t_fail "the only plan and manifest paths named anywhere are the real ones" \
        "$(cat "$PLANBAD")"
else
    t_pass "the only plan and manifest paths named anywhere are the real ones"
fi

D=$(fixture "t-rollback redirect")
run "$SCRIPTS/icm-apply.sh" --rollback "$D"
assert_rc "apply --rollback is refused with exit 2" 2
assert_out "the refusal names the script that does the job" "icm-rollback.sh"

# --------------------------------------------- 28 plan and the git tree F10 --

printf '\n%s\n' '-- plan and git --'

if command -v git >/dev/null 2>&1; then
    D=$(fixture "t-git plan trace")
    printf 'committed work\n' > "$D/a.txt"
    ( cd "$D" \
      && git init -q \
      && git add -A \
      && git -c user.email=t@example.com -c user.name=t commit -qm init ) > /dev/null 2>&1
    run "$SCRIPTS/icm-plan.sh" "$D"
    assert_out "plan says exactly what it left in the working tree" \
        "plan wrote only .icm/plan.txt"
    GST=$( cd "$D" && git status --porcelain )
    assert_eq "plan leaves nothing in the tree but .icm/" "$GST" "?? .icm/"
else
    printf 'note git is not on PATH, the plan trace test was skipped\n'
fi

# ------------------------------------------------------ 29 check ids CLI 3.2 --
#
# CLI-CONTRACT 3.2 fixes the check-id set at eleven and requires --only <id>.
# These assertions are what stops a phantom id or a phantom flag growing back
# into a SKILL.md, which is the defect class the hunt logged as
# only-flag-and-phantom-check-ids.

printf '\n%s\n' '-- check ids --'

ICM_IDS='self frontmatter budgets adapters drift sections routes links fences placeholders evidence'

for ID in $ICM_IDS; do
    run "$SCRIPTS/icm-check.sh" --only "$ID" "$ROOT"
    if [ "$RC" -eq 0 ] || [ "$RC" -eq 1 ]; then
        t_pass "--only $ID is accepted by icm-check.sh"
    else
        t_fail "--only $ID is accepted by icm-check.sh" "exit $RC
$OUT"
    fi
    run "$SCRIPTS/icm-check.sh" "--$ID" "$ROOT"
    if [ "$RC" -eq 0 ] || [ "$RC" -eq 1 ]; then
        t_pass "--$ID is accepted by icm-check.sh"
    else
        t_fail "--$ID is accepted by icm-check.sh" "exit $RC
$OUT"
    fi
done

run "$SCRIPTS/icm-check.sh" --only no-such-id "$ROOT"
assert_rc "an unknown check id is refused with exit 2" 2
assert_out "the refusal names the id, not the flag" "unknown check id: no-such-id"
assert_out "the refusal lists a valid id" "placeholders"

run "$SCRIPTS/icm-check.sh" --only
assert_rc "--only with no value is refused with exit 2" 2

# Every id in the check-id column of every check table in every SKILL.md must be
# one the script accepts. The table is found by its own header row, so an
# archetype name or a survey verdict elsewhere in the file is not mistaken for a
# check id.
IDBAD="$WORK/idbad.txt"
: > "$IDBAD"
for F in "$ROOT"/skills/*/SKILL.md; do
    awk '
        /^\| *Check *\| *check-id *\|/ { t = 1; next }
        t == 1 && /^\|[ :|-]*$/        { next }
        t == 1 && /^\|/ {
            n = split($0, f, "|")
            if (n >= 3) {
                id = f[3]
                gsub(/[ `]/, "", id)
                if (id != "") { print id }
            }
            next
        }
        { t = 0 }
    ' "$F" | sort -u | while IFS= read -r CID; do
            [ -n "$CID" ] || continue
            case " $ICM_IDS " in
                *" $CID "*) continue ;;
            esac
            printf '%s names a check id the script does not accept: %s\n' \
                "${F#"$ROOT"/}" "$CID" >> "$IDBAD"
        done
done
if [ -s "$IDBAD" ]; then
    t_fail "every check id named in a SKILL.md is one the script accepts" "$(cat "$IDBAD")"
else
    t_pass "every check id named in a SKILL.md is one the script accepts"
fi

# The retired ids must not come back.
IDPH="$WORK/idph.txt"
: > "$IDPH"
for PH in map paths index; do
    grep -rn "\`$PH\`" "$ROOT"/skills/*/SKILL.md 2>/dev/null \
        | grep -E '^\S+: *\| ' >> "$IDPH" || true
done
if [ -s "$IDPH" ]; then
    t_fail "the retired check ids map, paths and index are named in no check table" "$(cat "$IDPH")"
else
    t_pass "the retired check ids map, paths and index are named in no check table"
fi

# ------------------------------------------------------- 30 the links check --

printf '\n%s\n' '-- links --'

D=$(fixture "t-links dead")
printf '# X\n\nSee [the plan](docs/nope.md) and [this one](real.md).\n' > "$D/README.md"
printf 'real\n' > "$D/real.md"
run "$SCRIPTS/icm-check.sh" --only links "$D"
assert_rc "a dead relative link in a plain .md fails the links check" 1
assert_out "the dead link is named in the report" "docs/nope.md"

D=$(fixture "t-links quoted")
printf '# X\n\nCite with `[Title](wiki/topic/article.md)`, project-root-relative.\n' \
    > "$D/README.md"
printf '# Y\n\n```\n[a](nowhere/at/all.md)\n```\n' > "$D/other.md"
run "$SCRIPTS/icm-check.sh" --only links "$D"
assert_rc "a link inside backticks or a fence is not graded" 0

D=$(fixture "t-links external")
printf '# X\n\n[home](https://example.com/a.md) [anchor](#section) [mail](mailto:a@b.c)\n' \
    > "$D/README.md"
run "$SCRIPTS/icm-check.sh" --only links "$D"
assert_rc "http, anchor and mailto targets are skipped" 0

run "$SCRIPTS/icm-check.sh" --only links "$ROOT"
assert_rc "the toolkit's own markdown has no dead relative link" 0

# ------------------------------------------- 31 script resolution CONTRACT --
# spec/CLI-CONTRACT.md section 13.2: "script resolution" and "no bare
# invocation". Both were specified and neither was ever implemented, which is
# how three bare `sh scripts/icm-check.sh` lines shipped in examples/README.md.

printf '\n%s\n' '-- script resolution --'

PREAMBLE='ICM_HOME="${ICM_HOME:-${CLAUDE_PLUGIN_ROOT:-$HOME/src/momentrix-icm-kap-toolkit}}"'

MISSPRE="$WORK/preamble.bad"
: > "$MISSPRE"
for SKF in "$ROOT"/skills/*/SKILL.md; do
    [ -f "$SKF" ] || continue
    if grep -q -F 'scripts/icm-' "$SKF"; then
        if ! grep -q -F -- "$PREAMBLE" "$SKF"; then
            printf '%s\n' "$SKF" >> "$MISSPRE"
        fi
    fi
done
if [ -s "$MISSPRE" ]; then
    t_fail "every SKILL.md that names a script carries the resolution preamble" \
        "$(cat "$MISSPRE")"
else
    t_pass "every SKILL.md that names a script carries the resolution preamble"
fi

# No .md or .tmpl anywhere may invoke a script by a bare relative path. The
# contract file itself is exempt: it quotes the banned form in order to ban it.
BAREINV="$WORK/bare.bad"
: > "$BAREINV"
find "$ROOT" -name '.git' -prune -o \( -name '*.md' -o -name '*.tmpl' \) -print 2>/dev/null \
    | grep -v '/spec/CLI-CONTRACT.md$' \
    | while IFS= read -r BNF; do
          if grep -n -F 'sh scripts/icm-' "$BNF" 2>/dev/null | grep -q -v 'ICM_HOME'; then
              grep -n -F 'sh scripts/icm-' "$BNF" 2>/dev/null \
                  | grep -v 'ICM_HOME' \
                  | sed "s|^|$BNF:|"
          fi
      done > "$BAREINV"
if [ -s "$BAREINV" ]; then
    t_fail "no document invokes a script by a bare relative path" "$(cat "$BAREINV")"
else
    t_pass "no document invokes a script by a bare relative path"
fi


# ------------------------------------------------- CLI-CONTRACT section 13.2 --
# The conformance guards. Every one of these exists because the scripts, the
# skills and the docs once described three different programs. They are cheap
# and they are the only thing that stops that coming back.

printf '\n%s\n' '-- conformance: naming --'

# plan artifact name: one name only, .icm/plan.txt
# spec/CLI-CONTRACT.md and this harness name the banned spellings on purpose,
# because they are what forbids them. Everything else must say plan.txt.
BADPLAN=$(grep -rIn -- '\.icm/plan\.' "$ROOT" \
    --include='*.md' --include='*.tmpl' --include='*.sh' 2>/dev/null \
    | grep -v '\.icm/plan\.txt' \
    | grep -v 'spec/CLI-CONTRACT\.md' \
    | grep -v 'tests/run-tests\.sh' || true)
if [ -z "$BADPLAN" ]; then
    t_pass "the plan artifact is only ever called .icm/plan.txt"
else
    t_fail "the plan artifact is only ever called .icm/plan.txt" "$BADPLAN"
fi

# template demotion: no script may reach into the interview material
BADTPL=$(grep -rIn -- 'interview-templates' "$ROOT/scripts" 2>/dev/null || true)
if [ -z "$BADTPL" ]; then
    t_pass "no script reads interview-templates/"
else
    t_fail "no script reads interview-templates/" "$BADTPL"
fi

printf '\n%s\n' '-- conformance: vocabulary --'

# disposition vocabulary: only the six words, nothing invented
BADDISP=""
for f in "$ROOT"/docs/retrofit.md "$ROOT"/docs/deck-boards.md "$ROOT"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    for w in $(grep -v 'There is no' "$f" \
            | grep -v 'not a disposition' \
            | grep -oE '\b(CREATE|ADOPT|COLLIDE|SKIP|REFUSE|SURVEY|PRESENT|MERGE|REPLACE|OVERWRITE)\b' 2>/dev/null | sort -u); do
        case "$w" in
            CREATE|ADOPT|COLLIDE|SKIP|REFUSE|SURVEY) ;;
            *) BADDISP="$BADDISP
$f: $w" ;;
        esac
    done
done
if [ -z "$BADDISP" ]; then
    t_pass "every disposition word in the docs is one of the six"
else
    t_fail "every disposition word in the docs is one of the six" "$BADDISP"
fi

printf '\n%s\n' '-- conformance: flags --'

# flag existence: every --flag a doc shows for a script is in that script's usage
BADFLAG=""
for s in icm-check icm-plan icm-apply icm-rollback icm-loop; do
    USAGE=$("$SCRIPTS/$s.sh" --help 2>&1 || true)
    for fl in $(grep -rhoE "$s\.sh[^\`\"]*" "$ROOT"/skills/*/SKILL.md "$ROOT"/docs/*.md "$ROOT"/README.md "$ROOT"/QUICKSTART.md 2>/dev/null \
            | grep -oE '\-\-[a-z][a-z-]*' | sort -u); do
        printf '%s\n' "$USAGE" | grep -q -- "$fl" || BADFLAG="$BADFLAG
$s.sh does not accept $fl"
    done
done
if [ -z "$BADFLAG" ]; then
    t_pass "every documented flag exists on the script that is shown running it"
else
    t_fail "every documented flag exists on the script that is shown running it" "$BADFLAG"
fi

printf '\n%s\n' '-- conformance: the checker itself --'

# byte count: the checker counts bytes, not characters, so multibyte is honest
BC=$(fixture "bytecount")
printf 'caf\303\251 \342\200\224 \360\237\223\201\n' > "$BC/probe.md"
REALBYTES=$(wc -c < "$BC/probe.md" | tr -d ' ')
LIBBYTES=$(. "$SCRIPTS/icm_lib.sh" >/dev/null 2>&1; icm_chars "$BC/probe.md")
assert_eq "the checker counts bytes, not characters, on multibyte input" "$LIBBYTES" "$REALBYTES"

# locale: a file holding an invalid UTF-8 sequence must not kill the walk.
# Under a UTF-8 locale macOS awk aborts on it ("towc: multibyte conversion
# failure") and the checker died with exit 2 and no summary. icm_lib.sh pins
# LC_ALL=C, so the run below forces the bad locale from outside and expects
# the library to override it. (GitHub issue 5.)
BL=$(fixture "badlocale")
mkdir -p "$BL/_config" "$BL/_log"
printf '# x\n\n## Workspace Map\n\n```\nx/\n├── _config/\n├── _log/\n├── bad.md\n├── CONTEXT.md\n└── IDENTITY.md\n```\n' > "$BL/IDENTITY.md"
printf '# x\n' > "$BL/CONTEXT.md"
printf '# note\n\n| a | b\342\210\n| 2 |\n' > "$BL/bad.md"
run env LC_ALL=en_AU.UTF-8 LANG=en_AU.UTF-8 sh "$SCRIPTS/icm-check.sh" --placeholders --fences --budgets "$BL"
assert_rc "an invalid UTF-8 byte in a .md file does not abort the checker under a UTF-8 locale" 0
assert_out "the walk past a non-UTF-8 file still reaches the summary" "result: clean"
assert_not_out "no awk multibyte conversion failure leaks out" "multibyte conversion failure"

# adapter shape: the adapter icm-scaffold documents must pass --adapters
AD=$(fixture "adaptershape")
run "$SCRIPTS/icm-plan.sh" --quiet "$AD"
run "$SCRIPTS/icm-apply.sh" "$AD"
run "$SCRIPTS/icm-check.sh" --only adapters "$AD"
assert_rc "the adapter this toolkit generates passes its own --adapters check" 0

printf '\n%s\n' '-- conformance: spaces inside the workspace --'

# A space in the fixture ROOT is already covered. This covers a space in a
# folder INSIDE the workspace, which is the case a real user actually hits.
SP=$(fixture "innerspace")
run "$SCRIPTS/icm-plan.sh" --quiet "$SP"
run "$SCRIPTS/icm-apply.sh" "$SP"
mkdir -p "$SP/01 - research notes" "$SP/02_plain"
printf 'a note\n' > "$SP/01 - research notes/note.md"
printf 'plain\n' > "$SP/02_plain/note.md"
run "$SCRIPTS/icm-check.sh" --only drift "$SP"

# Drift is right to flag both: they were added after the map was written. The
# bug this guards is word splitting, which would shred the spaced name into
# "01", "-", "research" and "notes" and report four phantom paths.
if printf '%s\n' "$OUT" | grep -q -F '01 - research notes'; then
    t_pass "a folder name with spaces survives the drift walk as one path"
else
    t_fail "a folder name with spaces survives the drift walk as one path" "$OUT"
fi
for frag in ': 01$' ': research$' ': notes$' ': -$'; do
    if printf '%s\n' "$OUT" | grep -qE "$frag"; then
        t_fail "the spaced folder name is not split into fragments" "$OUT"
        break
    fi
done
printf '%s\n' "$OUT" | grep -qE ': 01$|: research$|: notes$|: -$' \
    || t_pass "the spaced folder name is not split into fragments"

SPACED_N=$(printf '%s\n' "$OUT" | grep -c -F '01 - research notes' || true)
PLAIN_N=$(printf '%s\n' "$OUT" | grep -c -F '02_plain' || true)
assert_eq "a spaced folder is reported exactly as often as a plain one" "$SPACED_N" "$PLAIN_N"

printf '\n%s\n' '-- conformance: malformed block --'

# A CLAUDE.md whose end marker was hand-deleted must COLLIDE and lose nothing.
MB=$(fixture "malformed")
{
    printf '# Acme\n\nHand written rules that must survive.\n\n'
    printf '<!-- icm:begin -->\nsomething that looks managed\n'
} > "$MB/CLAUDE.md"
cp "$MB/CLAUDE.md" "$MB.pre"
run "$SCRIPTS/icm-plan.sh" --quiet "$MB"
assert_out "a CLAUDE.md missing its end marker is classified COLLIDE" "COLLIDE"
run "$SCRIPTS/icm-apply.sh" "$MB"
assert_same "a malformed block loses not one line of the user's file" "$MB/CLAUDE.md" "$MB.pre"


# ------------------------------------------------------------ the loop --
# icm-loop.sh is the librarian. It counts, it never judges, and every verdict
# word it writes is a count a reader can redo by hand. These fixtures pin the
# counts, the kill rules, the starvation check and the one file it may write.

printf '\n%s\n' '-- the loop --'

LP=$(fixture "loop ws")
run "$SCRIPTS/icm-plan.sh" --quiet "$LP"
run "$SCRIPTS/icm-apply.sh" "$LP"
assert_file "apply installs a ledger with the Lines section" "$LP/_log/LOOP-LEDGER.md"
run grep -c '^## Lines' "$LP/_log/LOOP-LEDGER.md"
assert_out "the installed ledger ends with a Lines section to append under" "1"
run grep -c '^## Session Close' "$LP/CONTEXT.md"
assert_out "the installed CONTEXT.md carries the Session Close" "1"
run grep -c 'Session Close' "$LP/CLAUDE.md"
assert_out "the adapter points at the Session Close without copying it" "1"
run "$SCRIPTS/icm-check.sh" --only sections "$LP"
assert_rc "a fresh install passes the sections check with Session Close required" 0

mkdir -p "$LP/skills/icm-context" "$LP/sales"
printf -- '---\nname: icm-context\ndescription: x\n---\n# x\n' > "$LP/skills/icm-context/SKILL.md"
printf '# card\n' > "$LP/sales/CONTEXT.md"
cat >> "$LP/_log/LOOP-LEDGER.md" <<'LOOP_EOF'
| 2026-08-20 | outreach 01 | 2 | cash | 1 | 0/1/0/0 | 0 | none | out.md |
| 2026-08-20 | Use | icm-context | skills/icm-context/SKILL.md | outreach 01 | ok | 1 |
| 2026-08-20 | Miss | 2 | _config/voice.md | em dash in deck copy | ban it in deck copy |
| 2026-08-27 | Miss | 2 | _config/voice.md | em dash in slide subhead | say it covers slides |
| 2026-08-28 | Miss | 3 | none | no rule for saying we do not know | a rule |
| 2026-08-29 | Patched | _config/style.md | FP-2026-08-29-01 |
| 2026-08-30 | Miss | 2 | _config/style.md | RECURRENCE: timecode ambiguity | say beat start |
| 2026-09-01 | Miss | 2 | _config/style.md | RECURRENCE: timecode again | say beat start |
| 2026-09-02 | Miss | 1 | ghosts/old.md | stale | none |
| 2026-09-02 | Miss | 3 | ghosts/sev3.md | wrong path, wrong output | none |
| 2026-09-03 | Patched | _config/glossary.md | FP-2026-09-03-01 |
| 2026-09-03 | Miss | 2 | _config/glossary.md | term still ambiguous after patch | define it |
LOOP_EOF
snapshot "$LP" > "$LP.before"
run "$SCRIPTS/icm-loop.sh" --today 2026-09-04 "$LP"
assert_rc "an index with verdicts waiting exits 1" 1
assert_file "the index is written to _log/SKILL-INDEX.md" "$LP/_log/SKILL-INDEX.md"
assert_out "two sev 2 misses on one rule book is a hole" '`_config/voice.md` | - | - | - | 2 | 2 | 0 | - | hole |'
assert_out "two RECURRENCE misses after a patch is a rewrite" '`_config/style.md` | - | - | - | 2 | 2 | 2 | 2026-08-29 | rewrite |'
assert_out "a sev 3 miss against none is uncovered, not a hole" '| none | none | `none` |'
assert_out "uncovered is the verdict word for none" '| 1 | 3 | 0 | - | uncovered |'
assert_out "a ledger path that is not on disk is a ghost" '`ghosts/old.md` | 0 | 0 | - | 1 | 1 | 0 | - | ghost |'
assert_out "a sev 3 miss against a path not on disk is a ghost, not a hole" '`ghosts/sev3.md` | 0 | 0 | - | 1 | 3 | 0 | - | ghost |'
assert_out "a miss dated the patch day and appended after the patch stays open" '`_config/glossary.md` | - | - | - | 1 | 2 | 0 | 2026-09-03 | ok |'
assert_out "a job card with no lines yet in a young ledger is unlogged" '`sales/CONTEXT.md` | 0 | 0 | - | 0 | 0 | 0 | - | unlogged |'
assert_out "a used skill with its misses logged is ok" '`skills/icm-context/SKILL.md` | 1 | 1 | 2026-08-20 | 0 | 0 | 0 | - | ok |'
snapshot "$LP" | grep -v '^_log/SKILL-INDEX.md' > "$LP.after"
grep -v '^_log/SKILL-INDEX.md' "$LP.before" > "$LP.before2"
assert_same "the index run touched no file other than the index" "$LP.before2" "$LP.after"

printf '| 2026-09-03 | Use | icm-loop | skills/icm-loop/SKILL.md | install | ok | 0 |\n' >> "$LP/_log/LOOP-LEDGER.md"
run "$SCRIPTS/icm-loop.sh" --today 2026-09-04 "$LP"
assert_out "a toolkit skill used from a workspace is found in the toolkit, not called a ghost" '| icm-loop | toolkit skill | `skills/icm-loop/SKILL.md` | 1 | 1 | 2026-09-03 | 0 | 0 | 0 | - | ok |'
run "$SCRIPTS/icm-loop.sh" --today 2026-11-01 "$LP"
assert_out "no use in the archive window on an old ledger is archive" '`skills/icm-context/SKILL.md` | 0 | 0 | 2026-08-20 | 0 | 0 | 0 | - | archive |'

run "$SCRIPTS/icm-loop.sh" --starve --today 2026-08-26 "$LP"
assert_rc "work and a miss in the window is not starved" 0
assert_out "the starvation check says the write back is firing" "the write back is firing"
run "$SCRIPTS/icm-loop.sh" --starve --today 2026-08-22 "$LP"
assert_rc "work and a miss two days apart is not starved" 0
printf '| 2026-09-08 | outreach 02 | 2 | cash | 1 | 0/0/0/0 | 0 | none | out2.md |\n' >> "$LP/_log/LOOP-LEDGER.md"
printf '| 2026-09-08 | Use | icm-context | skills/icm-context/SKILL.md | outreach 02 | ok | 0 |\n' >> "$LP/_log/LOOP-LEDGER.md"
run "$SCRIPTS/icm-loop.sh" --starve --today 2026-09-10 "$LP"
assert_rc "real work and no miss in the window is starved, exit 1" 1
assert_out "starvation names the fix, not a rule book" "STARVED"
assert_nofile "--starve writes no index" "$LP/_log/SKILL-INDEX.md.icm-tmp.$$"

run "$SCRIPTS/icm-loop.sh" --block
assert_rc "--block prints and exits 0 with no target" 0
assert_out "the block opens with its start marker" "<!-- ICM-LOOP:START -->"
assert_out "the block closes with its end marker" "<!-- ICM-LOOP:END -->"
assert_out "the block is the Session Close, not a paraphrase of it" "## Session Close"
BLK_LINES=$(printf '%s\n' "$OUT" | sed '1d;$d' | sed '/^$/d')
CTX_LINES=$(sed -n '/^## Session Close$/,/^## Rule Books$/p' "$LP/CONTEXT.md" | sed '$d' | sed '/^$/d')
assert_eq "the block and the installed Session Close are the same bytes" "$BLK_LINES" "$CTX_LINES"

E=$(fixture "loop empty")
run "$SCRIPTS/icm-loop.sh" "$E"
assert_rc "no ledger is refused with exit 2" 2
assert_out "the refusal names a command that does work" "icm-plan.sh"
run "$SCRIPTS/icm-loop.sh" --index --starve "$LP"
assert_rc "two modes at once is a usage error" 2
run "$SCRIPTS/icm-loop.sh" --today 2026-13-40 "$LP"
assert_rc "a malformed --today date is refused" 2

# ------------------------------------------------ the 2026-10 defect hunt --
# Each block below is a defect reproduced on ee91520 and fixed on the same
# branch. The fixture is the reproduction; the assertion is the contract line.

printf '\n%s\n' '-- hunt: the ledger is data, never a command --'
HI=$(fixture "hunt inject")
run "$SCRIPTS/icm-plan.sh" --quiet "$HI"
run "$SCRIPTS/icm-apply.sh" --no-check "$HI"
printf '| 2026-10-01 | Miss | 3 | $(touch "%s/PWNED") | what | fix |\n' "$HI" >> "$HI/_log/LOOP-LEDGER.md"
printf '| 2026-10-01 | Use | x | `touch "%s/PWNED2"` | t | o | 0 |\n' "$HI" >> "$HI/_log/LOOP-LEDGER.md"
printf "| 2026-10-01 | Use | q | it's.md | t | o | 0 |\n" >> "$HI/_log/LOOP-LEDGER.md"
touch "$HI/it's.md"
run "$SCRIPTS/icm-loop.sh" --today 2026-10-07 "$HI"
assert_nofile "a \$(...) in a ledger path column is never executed" "$HI/PWNED"
assert_nofile "a backtick command in a ledger path column is never executed" "$HI/PWNED2"
assert_out "a path holding a single quote still resolves on disk" "\`it's.md\` | 1 | 1 | 2026-10-01 | 0 | 0 | 0 | - | ok |"

printf '\n%s\n' '-- hunt: .in_use is tool state (issue 3) --'
HU=$(fixture "hunt inuse")
run "$SCRIPTS/icm-plan.sh" --quiet "$HU"
run "$SCRIPTS/icm-apply.sh" --no-check "$HU"
mkdir "$HU/.in_use"
run "$SCRIPTS/icm-check.sh" --drift "$HU"
assert_rc "a plugin install's .in_use lock directory is not a drift finding" 0
assert_not_out "the drift check never names .in_use" "does not document: .in_use"
if grep -q -x '\.in_use' "$ROOT/spec/excluded-folders.md" && grep -q '"\.in_use"' "$ROOT/icm.defaults.json"; then
    t_pass "excluded_globs and its human rendering both carry .in_use"
else
    t_fail "excluded_globs and its human rendering both carry .in_use" "one side is missing it"
fi

printf '\n%s\n' '-- hunt: drift compares whole names --'
HD=$(fixture "hunt drift names")
run "$SCRIPTS/icm-plan.sh" --quiet "$HD"
run "$SCRIPTS/icm-apply.sh" --no-check "$HD"
mkdir "$HD/log"
run "$SCRIPTS/icm-check.sh" --drift "$HD"
assert_rc "a real log/ is not vouched for by the map's _log/ row" 1
assert_out "the undocumented entry is named whole" "does not document: log"

printf '\n%s\n' '-- hunt: links accept a title and %20 --'
HL=$(fixture "hunt links")
run "$SCRIPTS/icm-plan.sh" --quiet "$HL"
run "$SCRIPTS/icm-apply.sh" --no-check "$HL"
mkdir "$HL/01 - notes"
printf 'See [m](IDENTITY.md "the map"), [n](01%%20-%%20notes/) and [bad](nope.md).\n' > "$HL/README.md"
run "$SCRIPTS/icm-check.sh" --links "$HL"
assert_not_out "a link title is not part of the path" 'IDENTITY.md "the map"'
assert_not_out "%20 in a link is a space on disk" "01%20-%20notes"
assert_out "a dead link still fails" "does not exist: nope.md"

printf '\n%s\n' '-- hunt: check and loop refuse what they cannot read --'
HR=$(fixture "hunt unreadable")
run "$SCRIPTS/icm-plan.sh" --quiet "$HR"
run "$SCRIPTS/icm-apply.sh" --no-check "$HR"
chmod 0300 "$HR"
run "$SCRIPTS/icm-check.sh" "$HR"
assert_rc "the checker exits 2 on a target it cannot list, never clean" 2
run "$SCRIPTS/icm-loop.sh" "$HR"
assert_rc "the loop exits 2 on a target it cannot list" 2
chmod 0700 "$HR"
HF=$(fixture "hunt icm file")
touch "$HF/.icm"
run "$SCRIPTS/icm-check.sh" "$HF"
assert_rc "a .icm that is a file is a preflight refusal in the checker too" 2

printf '\n%s\n' '-- hunt: the quick map documents only what quick installs --'
HQ=$(fixture "hunt quick map")
run "$SCRIPTS/icm-plan.sh" --quiet "$HQ"
run "$SCRIPTS/icm-apply.sh" --no-check "$HQ"
if grep -q "grounding.md" "$HQ/IDENTITY.md"; then
    t_fail "a quick install's map does not document _config/grounding.md, which it never writes" "$(grep -n grounding "$HQ/IDENTITY.md")"
else
    t_pass "a quick install's map does not document _config/grounding.md, which it never writes"
fi
HQW=$(fixture "hunt wiki map")
run "$SCRIPTS/icm-plan.sh" --quiet --archetype wiki "$HQW"
run "$SCRIPTS/icm-apply.sh" --no-check "$HQW"
if grep -q "grounding.md" "$HQW/IDENTITY.md" && [ -f "$HQW/_config/grounding.md" ]; then
    t_pass "a wiki install's map documents the grounding.md it writes"
else
    t_fail "a wiki install's map documents the grounding.md it writes" "$(grep -n grounding "$HQW/IDENTITY.md"; ls "$HQW/_config")"
fi

printf '\n%s\n' '-- hunt: rollback closes once the kept file is gone --'
HK=$(fixture "hunt rollback kept")
printf 'mine\n' > "$HK/CLAUDE.md"
run "$SCRIPTS/icm-plan.sh" --quiet "$HK"
run "$SCRIPTS/icm-apply.sh" --no-check "$HK"
printf 'edited\n' >> "$HK/IDENTITY.md"
run "$SCRIPTS/icm-rollback.sh" "$HK"
assert_out "the edited file is kept" "kept     IDENTITY.md"
run "$SCRIPTS/icm-rollback.sh" "$HK"
assert_not_out "a file already restored is not reported as edited" "kept     CLAUDE.md"
assert_out "a file already restored is named as such" "CLAUDE.md already holds its pre-image"
rm "$HK/IDENTITY.md"
run "$SCRIPTS/icm-rollback.sh" "$HK"
assert_rc "deleting the kept file by hand closes the run, as the note promises" 0
HK_MARK=$(ls "$HK"/.icm/backup/*/ROLLED-BACK 2>/dev/null | head -n 1)
assert_file "the run carries its ROLLED-BACK marker" "$HK_MARK"

# ---------------------------------------------------------------- the tally --

printf '\n%s\n' '-- summary --'
printf 'PASS %s / FAIL %s\n' "$PASSN" "$FAILN"

if [ "$FAILN" -gt 0 ]; then
    exit 1
fi
exit 0
