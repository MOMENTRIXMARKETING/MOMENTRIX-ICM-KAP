#!/bin/sh
# Standalone ICM Orchestra conformance tests. Run the same file against any toolkit root:
# ICM_ROOT=/path/to/toolkit sh tests/orchestra-tests.sh

LC_ALL=C
export LC_ALL

TEST_FILE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")
DEFAULT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
ROOT=${ICM_ROOT:-$DEFAULT_ROOT}
SCRIPTS="$ROOT/scripts"
CHECK="$SCRIPTS/icm-check.sh"
VERBOSE=0
if [ "${1:-}" = "-v" ]; then
    VERBOSE=1
fi

WORK="${TMPDIR:-/tmp}/icm orchestra tests $$"
rm -rf "$WORK"
mkdir -p "$WORK"
WORK=$(CDPATH= cd -- "$WORK" && pwd -P)
trap 'chmod -R u+rwX "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT INT TERM

CONTROL_PASS=0
CONTROL_FAIL=0
FEATURE_PASS=0
FEATURE_FAIL=0
OUT=""
RC=0
T_ERROR=""

fixture() {
    _fx="$WORK/$1"
    rm -rf "$_fx"
    mkdir -p "$_fx"
    printf '%s\n' "$_fx"
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

run_to() {
    _rt_file="$WORK/$1"
    shift
    "$@" > "$_rt_file" 2>&1
    RC=$?
    OUT=$(cat "$_rt_file" 2>/dev/null)
    if [ "$VERBOSE" -eq 1 ]; then
        printf '     $ %s\n' "$*"
        printf '%s\n' "$OUT" | sed 's/^/     > /'
    fi
    return 0
}

t_begin() {
    T_ERROR=""
    OUT=""
    RC=0
}

t_error() {
    if [ -z "$T_ERROR" ]; then
        T_ERROR="$1"
    fi
}

t_rc() {
    if [ "$RC" -ne "$1" ]; then
        t_error "expected exit $1, got $RC"
    fi
}

t_out() {
    if ! printf '%s\n' "$OUT" | grep -q -F -- "$1"; then
        t_error "output did not contain [$1]"
    fi
}

t_not_out() {
    if printf '%s\n' "$OUT" | grep -q -F -- "$1"; then
        t_error "output unexpectedly contained [$1]"
    fi
}

t_out_re() {
    if ! printf '%s\n' "$OUT" | grep -q -E -- "$1"; then
        t_error "output did not match [$1]"
    fi
}

t_eq() {
    if [ "$1" != "$2" ]; then
        t_error "expected [$2], got [$1]"
    fi
}

t_file() {
    if [ ! -f "$1" ]; then
        t_error "missing file [$1]"
    fi
}

t_nofile() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        t_error "path should be absent [$1]"
    fi
}

t_same() {
    if ! cmp -s "$1" "$2"; then
        t_error "files differ [$1] [$2]"
    fi
}

t_file_out() {
    if [ ! -f "$1" ] || ! grep -q -F -- "$2" "$1"; then
        t_error "[$1] did not contain [$2]"
    fi
}

t_file_not_out() {
    if [ ! -f "$1" ] || grep -q -F -- "$2" "$1"; then
        t_error "[$1] unexpectedly contained [$2]"
    fi
}

t_finish() {
    _tf_group="$1"
    _tf_id="$2"
    if [ -z "$T_ERROR" ]; then
        printf '%s PASS %s\n' "$_tf_group" "$_tf_id"
        case "$_tf_group" in
            CONTROL) CONTROL_PASS=$((CONTROL_PASS + 1)) ;;
            FEATURE) FEATURE_PASS=$((FEATURE_PASS + 1)) ;;
        esac
    else
        printf '%s FAIL %s | %s\n' "$_tf_group" "$_tf_id" "$T_ERROR"
        if [ -n "$OUT" ]; then
            printf '%s\n' "$OUT" | sed 's/^/     | /'
        fi
        case "$_tf_group" in
            CONTROL) CONTROL_FAIL=$((CONTROL_FAIL + 1)) ;;
            FEATURE) FEATURE_FAIL=$((FEATURE_FAIL + 1)) ;;
        esac
    fi
}

control() {
    t_finish CONTROL "$1"
}

feature() {
    t_finish FEATURE "$1"
}

snapshot() {
    _sn_root="$1"
    _sn_out="$2"
    (
        CDPATH= cd -- "$_sn_root" || exit 1
        if [ ! -e .icm ] && [ ! -L .icm ]; then
            printf 'absent .icm\n'
        fi
        find . -print | sort | while IFS= read -r _sn_p; do
            if [ -L "$_sn_p" ]; then
                _sn_target=$(ls -ld "$_sn_p" 2>/dev/null | sed 's/.* -> //')
                printf 'link %s -> %s\n' "$_sn_p" "$_sn_target"
            elif [ -d "$_sn_p" ]; then
                printf 'dir %s\n' "$_sn_p"
            elif [ -f "$_sn_p" ]; then
                _sn_sum=$(cksum < "$_sn_p" | awk '{print $1 ":" $2}')
                printf 'file %s %s\n' "$_sn_p" "$_sn_sum"
            else
                printf 'other %s\n' "$_sn_p"
            fi
        done
    ) > "$_sn_out"
}

make_workspace() {
    _mw_root="$1"
    mkdir -p "$_mw_root"
    cat > "$_mw_root/IDENTITY.md" <<'ICM_ID'
# Fixture Identity

## Workspace Map

```
fixture/
```

## Rules

Use the typed fixture cards.
ICM_ID
    make_router "$_mw_root/CONTEXT.md"
}

make_router() {
    _mr_file="$1"
    mkdir -p "$(dirname -- "$_mr_file")"
    cat > "$_mr_file" <<'ICM_ROUTER'
# Routing

## Routing

| Job | Where | Load first | Edge |
|---|---|---|---|
ICM_ROUTER
}

route() {
    printf '| %s | `%s` | %s | %s |\n' "$2" "$3" "$4" "$5" >> "$1"
}

make_card() {
    _mc_root="$1"
    _mc_dir="$2"
    _mc_input="$3"
    _mc_output="$4"
    _mc_routes="$5"
    _mc_preflight="$6"
    mkdir -p "$_mc_root/$_mc_dir"
    _mc_purpose="Complete the declared stage work."
    case "$_mc_dir" in
        *00-intake) _mc_purpose="Intake and preflight the request." ;;
    esac
    {
        printf '# %s\n\n' "$_mc_dir"
        printf '## Purpose\n\n%s\n\n' "$_mc_purpose"
        printf '## Inputs\n\n'
        printf '| Source | File | Scope | Why |\n|---|---|---|---|\n'
        if [ "$_mc_input" != "-" ]; then
            printf '| Input | %s | full | declared input |\n' "$_mc_input"
        fi
        printf '\n## Process\n\n1. Do the work.\n\n'
        printf '## Outputs\n\n'
        printf '| Artifact | Location | Format |\n|---|---|---|\n'
        if [ "$_mc_output" != "-" ]; then
            printf '| Output | %s | file |\n' "$_mc_output"
        fi
        printf '\n## Routing\n\n'
        printf '| When | Go to | Edge |\n|---|---|---|\n'
        if [ -n "$_mc_routes" ]; then
            printf '%s\n' "$_mc_routes"
        fi
        printf '\n## Preflight\n\n'
        printf '| Kind | Reference | Version |\n|---|---|---|\n'
        if [ -n "$_mc_preflight" ]; then
            printf '%s\n' "$_mc_preflight"
        else
            printf '| None | - | - |\n'
        fi
    } > "$_mc_root/$_mc_dir/CONTEXT.md"
}

make_valid() {
    _mv_root="$1"
    _mv_layout="$2"
    rm -rf "$_mv_root"
    make_workspace "$_mv_root"
    case "$_mv_layout" in
        root)
            make_card "$_mv_root" 00-intake - - "" ""
            make_card "$_mv_root" 01-draft - - "" ""
            route "$_mv_root/CONTEXT.md" Intake 00-intake/CONTEXT.md - NEXT
            route "$_mv_root/CONTEXT.md" Draft 01-draft/CONTEXT.md - NEXT
            ;;
        root-stages)
            make_card "$_mv_root" stages/00-intake - - "" ""
            make_card "$_mv_root" stages/01-draft - - "" ""
            route "$_mv_root/CONTEXT.md" Intake stages/00-intake/CONTEXT.md - NEXT
            route "$_mv_root/CONTEXT.md" Draft stages/01-draft/CONTEXT.md - NEXT
            ;;
        department|department-stages)
            make_router "$_mv_root/sales/CONTEXT.md"
            route "$_mv_root/CONTEXT.md" Sales sales/CONTEXT.md - NEXT
            if [ "$_mv_layout" = department ]; then
                _mv_prefix=sales
            else
                _mv_prefix=sales/stages
            fi
            make_card "$_mv_root" "$_mv_prefix/00-intake" - - "" ""
            make_card "$_mv_root" "$_mv_prefix/01-draft" - - "" ""
            route "$_mv_root/sales/CONTEXT.md" Intake "$_mv_prefix/00-intake/CONTEXT.md" - NEXT
            route "$_mv_root/sales/CONTEXT.md" Draft "$_mv_prefix/01-draft/CONTEXT.md" - NEXT
            ;;
    esac
}

make_pair() {
    _mp_root="$1"
    rm -rf "$_mp_root"
    make_workspace "$_mp_root"
    make_card "$_mp_root" 01-a - - "" ""
    make_card "$_mp_root" 02-b - - "" ""
    route "$_mp_root/CONTEXT.md" Alpha 01-a/CONTEXT.md - NEXT
    route "$_mp_root/CONTEXT.md" Beta 02-b/CONTEXT.md - NEXT
}

materialize() {
    _mat_root="$1"
    _mat_rel="$2"
    mkdir -p "$_mat_root/$(dirname -- "$_mat_rel")"
    printf '%s\n' "${3:-materialised input}" > "$_mat_root/$_mat_rel"
}

table_add() {
    _ta_file="$1"
    _ta_section="$2"
    _ta_row="$3"
    awk -v section="## $_ta_section" -v row="$_ta_row" '
        $0 == section { active = 1 }
        active && /^\|---/ { print; print row; active = 0; next }
        { print }
    ' "$_ta_file" > "$_ta_file.new"
    mv "$_ta_file.new" "$_ta_file"
}

replace_line() {
    _rl_file="$1"
    _rl_old="$2"
    _rl_new="$3"
    awk -v old="$_rl_old" -v new="$_rl_new" '$0 == old { print new; next } { print }' \
        "$_rl_file" > "$_rl_file.new"
    mv "$_rl_file.new" "$_rl_file"
}

strict() {
    run "$CHECK" --orchestra --job "$1" "$2"
}

printf '# icm orchestra conformance\n'
printf 'root: %s\n' "$ROOT"
printf 'work: %s\n' "$WORK"
printf 'legacy controls and feature assertions are tallied separately\n\n'

# Legacy controls must pass on the pristine base and on the completed feature.

t_begin
run sh -n "$TEST_FILE"
t_rc 0
control "CTRL-HARNESS-SYNTAX"

t_begin
ICM_LEGACY_IDS='self frontmatter budgets adapters drift sections routes links fences placeholders evidence'
for ID in $ICM_LEGACY_IDS; do
    run "$CHECK" --only "$ID" "$ROOT"
    if [ "$RC" -ne 0 ] && [ "$RC" -ne 1 ]; then
        t_error "legacy id $ID exited $RC"
        break
    fi
done
control "CTRL-ELEVEN-LEGACY-IDS"

t_begin
run "$CHECK" "$ROOT/examples/content-pipeline"
t_rc 0
t_not_out "# icm-orchestra"
t_not_out "-- orchestra --"
control "CTRL-DEFAULT-ELEVEN-NO-ORCHESTRA"

t_begin
run "$CHECK" --all "$ROOT/examples/content-pipeline"
t_rc 0
t_not_out "# icm-orchestra"
t_not_out "-- orchestra --"
control "CTRL-ALL-ELEVEN-NO-ORCHESTRA"

D=$(fixture "legacy untyped")
make_workspace "$D"
make_card "$D" 01-a - - '| Done | `02-b/CONTEXT.md` | - |' ""
make_card "$D" 02-b - - "" ""
# Generic legacy parsing is tested through a legacy two-column card as well.
cat > "$D/01-a/CONTEXT.md" <<'ICM_LEGACY'
# Legacy stage

## Purpose

Keep legacy routing.

## Inputs

| Source | File | Scope | Why |
|---|---|---|---|

## Process

1. Do the work.

## Outputs

| Artifact | Location | Format |
|---|---|---|

## Routing

| When | Go to |
|---|---|
| Done | `02-b/CONTEXT.md` |
ICM_LEGACY
t_begin
run "$CHECK" --only routes "$D"
t_rc 0
control "CTRL-LEGACY-UNTYPED-ROUTES"

D=$(fixture "legacy bad input")
make_workspace "$D"
make_card "$D" 01-a - - "" ""
replace_line "$D/01-a/CONTEXT.md" '| Input | - | full | declared input |' ''
table_add "$D/01-a/CONTEXT.md" Inputs '| Bad | `missing/input.md` | full | invalid legacy input |'
t_begin
run "$CHECK" "$D"
t_rc 1
t_out "missing/input.md"
control "CTRL-LEGACY-INVALID-INPUT-STILL-FAILS"

D=$(fixture "legacy unrelated skill")
mkdir -p "$D/skills/unrelated"
cat > "$D/skills/unrelated/SKILL.md" <<'ICM_SKILL'
---
name: unrelated
description: "This skill should be used when the user asks for an unrelated check."
user-invocable: true
argument-hint: ""
---
# Unrelated
ICM_SKILL
t_begin
run "$CHECK" --only frontmatter "$D"
t_rc 0
control "CTRL-UNRELATED-SKILL-NO-VERSION"

t_begin
run "$CHECK" --only orchestra-view "$ROOT"
t_rc 2
t_out "unknown check id: orchestra-view"
control "CTRL-VIEW-IS-NOT-CHECK-ID"

# CLI selection, strict mode, and usage refusals.

D=$(fixture "cli valid")
make_valid "$D" root

t_begin
run "$CHECK" --only orchestra "$D"
t_rc 0
t_out "# icm-orchestra-structural-v1"
t_out "result: clean"
feature "CLI-ORCHESTRA-ID"

t_begin
run_to "equiv only.out" "$CHECK" --only orchestra "$D"
RC_ONLY=$RC
run_to "equiv flag.out" "$CHECK" --orchestra "$D"
t_rc 0
t_eq "$RC_ONLY" "0"
t_same "$WORK/equiv only.out" "$WORK/equiv flag.out"
feature "CLI-FLAG-ID-EQUIVALENT"

t_begin
run "$CHECK" --help
t_rc 0
t_out "orchestra"
t_out "twelve"
t_out "--orchestra-view"
t_out "--tool-version"
feature "CLI-HELP-COMPLETE"

t_begin
run_to "strict run.out" "$CHECK" --orchestra --job 00-intake/CONTEXT.md "$D"
t_rc 0
cat > "$WORK/strict run.expected" <<'ICM_RUN'
# icm-orchestra-preflight-v1
job: 00-intake/CONTEXT.md
result: RUN
ICM_RUN
t_same "$WORK/strict run.expected" "$WORK/strict run.out"
feature "CLI-STRICT-RUN-EXACT"

t_begin
run "$CHECK" --only orchestra --job 00-intake/CONTEXT.md "$D"
t_rc 2
t_out "--job"
t_out "--orchestra"
feature "CLI-STRICT-SPELLING-IS-LITERAL"

t_begin
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --job 01-draft/CONTEXT.md "$D"
t_rc 2
t_out "duplicate --job"
feature "CLI-DUPLICATE-JOB"

t_begin
for ARGS in '--orchestra --routes' '--orchestra --all' '--orchestra-view --only routes' '--orchestra-view --orchestra'; do
    set -- $ARGS
    run "$CHECK" "$@" "$D"
    t_rc 2
    t_out "mixed"
    if [ -n "$T_ERROR" ]; then
        break
    fi
done
feature "CLI-MIXED-MODES-REFUSED"

t_begin
run "$CHECK" --input brief=intake.md "$D"
t_rc 2
t_out "strict"
run "$CHECK" --orchestra --input brief=intake.md "$D"
t_rc 2
t_out "strict"
feature "CLI-BINDINGS-OUTSIDE-STRICT"

t_begin
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --input a=one.md --input a=two.md "$D"
t_rc 2
t_out "duplicate --input"
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --tool-version sh=1 --tool-version sh=1 "$D"
t_rc 2
t_out "duplicate --tool-version"
feature "CLI-DUPLICATE-BINDINGS"

t_begin
for BIND in brief 'brief=' '=file.md' 'bad.name=file.md'; do
    run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --input "$BIND" "$D"
    t_rc 2
    t_out "malformed --input"
    if [ -n "$T_ERROR" ]; then
        break
    fi
done
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --tool-version sh= "$D"
t_rc 2
t_out "malformed --tool-version"
feature "CLI-MALFORMED-BINDINGS"

TAB=$(printf '\t')
NL='
'
t_begin
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --input "bad${TAB}name=file.md" "$D"
t_rc 2
t_out "FAIL tab in a CLI machine field"
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --tool-version "sh=1${NL}2" "$D"
t_rc 2
t_out "FAIL newline in a CLI machine field"
feature "CLI-MACHINE-FIELD-WHITESPACE"

# Numbering, four layouts, nested roots, and pipeline identity.

for LAYOUT in root root-stages department department-stages; do
    D=$(fixture "layout $LAYOUT")
    make_valid "$D" "$LAYOUT"
    t_begin
    run "$CHECK" --orchestra "$D"
    t_rc 0
    t_out "result: clean"
    feature "LAYOUT-$LAYOUT"
done

D=$(fixture "number gaps")
make_workspace "$D"
for STAGE in 01-one 02-two 07-seven 99-last; do
    make_card "$D" "$STAGE" - - "" ""
done
route "$D/CONTEXT.md" Seven 07-seven/CONTEXT.md - NEXT
route "$D/CONTEXT.md" One 01-one/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Last 99-last/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Two 02-two/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
feature "NUM-GAPS-AND-ROUTING-ORDER"

D=$(fixture "duplicate intake")
make_valid "$D" root
make_card "$D" 00-other - - "" ""
route "$D/CONTEXT.md" Other 00-other/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+NUMBERING'
feature "NUM-00-DUPLICATE"

D=$(fixture "misordered intake")
make_valid "$D" root
make_router "$D/CONTEXT.md"
route "$D/CONTEXT.md" Draft 01-draft/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Intake 00-intake/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+NUMBERING'
feature "NUM-00-MISORDERED"

D=$(fixture "duplicate positive")
make_valid "$D" root
make_card "$D" 01-duplicate - - "" ""
route "$D/CONTEXT.md" Duplicate 01-duplicate/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+NUMBERING'
feature "NUM-POSITIVE-DUPLICATE"

D=$(fixture "department duplicate legal")
make_valid "$D" department
make_router "$D/support/CONTEXT.md"
make_card "$D" support/00-intake - - "" ""
make_card "$D" support/01-draft - - "" ""
route "$D/CONTEXT.md" Support support/CONTEXT.md - NEXT
route "$D/support/CONTEXT.md" Intake support/00-intake/CONTEXT.md - NEXT
route "$D/support/CONTEXT.md" Draft support/01-draft/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
feature "NUM-DEPARTMENT-DUPLICATES-LEGAL"

D=$(fixture "pipeline duplicate legal")
make_valid "$D" root
make_card "$D" stages/00-intake - - "" ""
make_card "$D" stages/01-draft - - "" ""
route "$D/CONTEXT.md" Other-intake stages/00-intake/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Other-draft stages/01-draft/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
feature "NUM-CONTAINER-DUPLICATES-LEGAL"

D=$(fixture "nested workspaces")
make_valid "$D" root
make_valid "$D/inner" root
make_card "$D/inner" 01-duplicate - - "" ""
route "$D/inner/CONTEXT.md" Duplicate 01-duplicate/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
run "$CHECK" --orchestra "$D/inner"
t_rc 1
t_out_re '^FAIL[[:space:]]+NUMBERING'
feature "LAYOUT-NESTED-ROOTS-INDEPENDENT"

# Conversational insertion and rename conformance is checked on materialised results.

D=$(fixture "front insertion")
make_workspace "$D"
for STAGE in 00-intake 01-new-brief 02-old-brief 04-old-publish; do
    make_card "$D" "$STAGE" - - "" ""
done
route "$D/CONTEXT.md" Intake 00-intake/CONTEXT.md - NEXT
route "$D/CONTEXT.md" New 01-new-brief/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Old 02-old-brief/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Publish 04-old-publish/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
t_file "$D/00-intake/CONTEXT.md"
feature "POLICY-FRONT-INSERTION-AFTER-00"

D=$(fixture "middle insertion")
make_workspace "$D"
for STAGE in 00-intake 01-research 02-new-draft 03-old-draft 05-publish; do
    make_card "$D" "$STAGE" - - "" ""
done
route "$D/CONTEXT.md" Intake 00-intake/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Research 01-research/CONTEXT.md - NEXT
route "$D/CONTEXT.md" New 02-new-draft/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Old 03-old-draft/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Publish 05-publish/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
feature "POLICY-MIDDLE-INSERTION-SHIFTS-HIGHER-ONLY"

D=$(fixture "positive rename")
make_valid "$D" root
mv "$D/01-draft" "$D/01-reviewed-draft"
replace_line "$D/CONTEXT.md" '| Draft | `01-draft/CONTEXT.md` | - | NEXT |' '| Draft | `01-reviewed-draft/CONTEXT.md` | - | NEXT |'
make_card "$D" 02-publish '`01-reviewed-draft/output/brief.md`' '`output/publication.md`' "" ""
route "$D/CONTEXT.md" Publish 02-publish/CONTEXT.md - NEXT
materialize "$D" 01-reviewed-draft/output/brief.md
mkdir -p "$D/output" "$D/wiki"
printf '# Renamed stage\n\nSee [draft](01-reviewed-draft/CONTEXT.md).\n' > "$D/wiki/draft.md"
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
run "$CHECK" --only links "$D"
t_rc 0
strict 02-publish/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
t_file "$D/00-intake/CONTEXT.md"
t_file "$D/01-reviewed-draft/CONTEXT.md"
t_nofile "$D/01-draft"
feature "POLICY-POSITIVE-SLUG-RENAME"

t_begin
t_file "$ROOT/spec/ORCHESTRA.md"
for TEXT in 'after:00' 'with or without an actual `00-intake`' 'Exhaustion after `99`' 'highest-first collision rollback' 'never renames `00-intake`' 'Immutable raw files and append-only history are never rewritten'; do
    if ! grep -q -F -- "$TEXT" "$ROOT/spec/ORCHESTRA.md" 2>/dev/null; then
        t_error "Orchestra contract lacks [$TEXT]"
        break
    fi
done
feature "POLICY-HUMAN-CONFIRMED-MAP-PROTOCOL"


# Typed workflow graph, producer ownership, and ambiguity.

D=$(fixture "load handoff cycle")
make_pair "$D"
make_card "$D" 01-a '`02-b/output/result.md`' '`01-a/output/result.md`' "" ""
make_card "$D" 02-b '`01-a/output/result.md`' '`02-b/output/result.md`' "" ""
materialize "$D" 01-a/output/result.md "from a"
materialize "$D" 02-b/output/result.md "from b"
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+LOAD'
t_not_out "untyped"
feature "GRAPH-REAL-OUTPUT-HANDOFF-LOAD-CYCLE"

D=$(fixture "next cycle")
make_pair "$D"
make_card "$D" 01-a - - '| Next | `02-b/CONTEXT.md` | NEXT |' ""
make_card "$D" 02-b - - '| Next | `01-a/CONTEXT.md` | NEXT |' ""
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+NEXT'
if printf '%s\n' "$OUT" | grep -q -E '^FAIL[[:space:]]+LOAD'; then
    t_error "a pure NEXT cycle leaked into the LOAD projection"
fi
feature "GRAPH-PURE-NEXT-CYCLE"

D=$(fixture "legal next rework")
make_workspace "$D"
make_card "$D" 02-first - - '| Forward | `01-second/CONTEXT.md` | NEXT |' ""
make_card "$D" 01-second - - '| Repair | `02-first/CONTEXT.md` | REWORK |' ""
route "$D/CONTEXT.md" First 02-first/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Second 01-second/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
t_out "result: clean"
feature "GRAPH-LEGAL-NEXT-REWORK-TABLE-ORDER"

D=$(fixture "forward rework")
make_pair "$D"
make_card "$D" 01-a - - '| Bad repair | `02-b/CONTEXT.md` | REWORK |' ""
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+REWORK'
feature "GRAPH-FORWARD-REWORK"

D=$(fixture "explicit load cycle")
make_pair "$D"
make_card "$D" 01-a - - '| Load | `02-b/CONTEXT.md` | LOAD |' ""
make_card "$D" 02-b - - '| Load | `01-a/CONTEXT.md` | LOAD |' ""
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+LOAD'
feature "GRAPH-EXPLICIT-LOAD-CYCLE"

D=$(fixture "load is not hop")
make_pair "$D"
make_router "$D/CONTEXT.md"
route "$D/CONTEXT.md" Alpha 01-a/CONTEXT.md - NEXT
make_card "$D" 01-a - - '| Load | `02-b/CONTEXT.md` | LOAD |' ""
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+ROUTE'
t_out "02-b/CONTEXT.md"
feature "GRAPH-LOAD-IS-NOT-ROUTING-HOP"

D=$(fixture "nearest pipeline router")
make_workspace "$D"
make_router "$D/dept/CONTEXT.md"
make_card "$D" dept/01-stage - - "" ""
route "$D/CONTEXT.md" Department dept/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Bypass dept/01-stage/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+ROUTE'
t_out "dept/01-stage/CONTEXT.md"
strict dept/01-stage/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+ROUTE'
feature "ROUTE-NEAREST-PIPELINE-ROUTER"

D=$(fixture "untyped orchestra")
make_pair "$D"
make_card "$D" 01-a - - '| Done | `02-b/CONTEXT.md` | - |' ""
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+ROUTE'
feature "GRAPH-UNTYPED-PATH-ROUTE"

D=$(fixture "nonpath route")
make_pair "$D"
make_card "$D" 01-a - - '| Stop | - | - |' ""
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
feature "GRAPH-NONPATH-DASH-LEGAL"

D=$(fixture "bad edge")
make_pair "$D"
make_card "$D" 01-a - - '| Done | `02-b/CONTEXT.md` | MAYBE |' ""
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+ROUTE'
feature "GRAPH-UNKNOWN-EDGE"

D=$(fixture "duplicate labels")
make_pair "$D"
make_router "$D/CONTEXT.md"
route "$D/CONTEXT.md" 'Publish   Now' 01-a/CONTEXT.md - NEXT
route "$D/CONTEXT.md" 'publish now' 02-b/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+AMBIGUOUS'
feature "GRAPH-DUPLICATE-NORMALISED-TASKS"

D=$(fixture "duplicate routes")
make_pair "$D"
make_card "$D" 01-a - - '| One | `02-b/CONTEXT.md` | NEXT |
| Two | `02-b/CONTEXT.md` | NEXT |' ""
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+AMBIGUOUS'
feature "GRAPH-DUPLICATE-ROUTES"

D=$(fixture "duplicate path candidates")
make_pair "$D"
make_card "$D" 01-a '`shared.md`, `shared.md`' - "" ""
materialize "$D" shared.md
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+AMBIGUOUS'
feature "GRAPH-DUPLICATE-PATH-CANDIDATES"

D=$(fixture "two candidates")
make_pair "$D"
make_card "$D" 01-a - - '| Next | `02-b/CONTEXT.md` | NEXT |' ""
make_card "$D" 01-a/02-b - - "" ""
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+AMBIGUOUS'
feature "GRAPH-TWO-PHYSICAL-CANDIDATES"

t_begin
strict 01-a/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+AMBIGUOUS'
t_out "result: MISSING"
feature "STRICT-TWO-CANDIDATES-AMBIGUOUS"

D=$(fixture "multiple producers")
make_workspace "$D"
make_card "$D" 01-a - '`shared/out.md`' "" ""
make_card "$D" 02-b - '`shared/out.md`' "" ""
make_card "$D" 03-c '`shared/out.md`' - "" ""
route "$D/CONTEXT.md" Alpha 01-a/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Beta 02-b/CONTEXT.md - NEXT
route "$D/CONTEXT.md" Consume 03-c/CONTEXT.md - NEXT
materialize "$D" shared/out.md
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+AMBIGUOUS'
feature "GRAPH-MULTIPLE-PRODUCERS"

# Depth and the separate legacy parser.

D=$(fixture "depth four")
make_workspace "$D"
make_router "$D/dept/CONTEXT.md"
make_card "$D" dept/01-stage - - '| Deep | `dept/01-stage/02-deep/CONTEXT.md` | NEXT |' ""
make_card "$D" dept/01-stage/02-deep - - "" ""
route "$D/CONTEXT.md" Department dept/CONTEXT.md - NEXT
route "$D/dept/CONTEXT.md" Stage dept/01-stage/CONTEXT.md - NEXT

t_begin
run "$CHECK" --only routes "$D"
t_rc 0
t_out "note"
t_out "depth"
feature "DEPTH-GENERIC-NONFAILING-NOTE"

t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
t_out_re '^NOTE[[:space:]]+DEPTH'
t_out "dept/01-stage/02-deep/CONTEXT.md"
feature "DEPTH-STRUCTURAL-REPORT"

t_begin
strict dept/01-stage/02-deep/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+ROUTE'
t_out "result: MISSING"
feature "DEPTH-STRICT-MISSING-ROUTE"

D=$(fixture "legacy preflight exclusion")
make_valid "$D" root
make_card "$D" 01-draft - - "" '| No touch | `missing/private/` | - |'
t_begin
run "$CHECK" --only routes "$D"
t_rc 0
t_not_out "missing/private"
feature "LEGACY-PREFLIGHT-ONLY-EXCLUSION"

# Knowledge is a separate, informational projection.

D=$(fixture "knowledge cycle")
make_pair "$D"
mkdir -p "$D/wiki"
printf '# A\n\nSee [B](wiki/b.md).\n' > "$D/wiki/a.md"
printf '# B\n\nSee [A](wiki/a.md).\n' > "$D/wiki/b.md"
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
t_out_re '^INFO[[:space:]]'
t_out "cycle"
t_out "wiki/a.md"
feature "KNOWLEDGE-CYCLE-INFORMATIONAL"

D=$(fixture "knowledge beside load")
make_pair "$D"
make_card "$D" 01-a '`02-b/output/result.md`' '`01-a/output/result.md`' "" ""
make_card "$D" 02-b '`01-a/output/result.md`' '`02-b/output/result.md`' "" ""
materialize "$D" 01-a/output/result.md "from a"
materialize "$D" 02-b/output/result.md "from b"
mkdir -p "$D/wiki"
printf '# A\n\nSee [B](wiki/b.md).\n' > "$D/wiki/a.md"
printf '# B\n\nSee [A](wiki/a.md).\n' > "$D/wiki/b.md"
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
t_out_re '^FAIL[[:space:]]+LOAD'
t_out_re '^INFO[[:space:]]'
t_out "cycle"
feature "KNOWLEDGE-CYCLE-BESIDE-LOAD-CYCLE"

D=$(fixture "workflow knowledge independent")
make_pair "$D"
replace_line "$D/01-a/CONTEXT.md" '1. Do the work.' '1. Read [Beta](02-b/CONTEXT.md), then work.'
replace_line "$D/02-b/CONTEXT.md" '1. Do the work.' '1. Read [Alpha](01-a/CONTEXT.md), then work.'
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
if printf '%s\n' "$OUT" | grep -q -E '^FAIL[[:space:]]+(NEXT|LOAD)'; then
    t_error "ordinary links created a workflow cycle"
fi
t_out "cycle"
feature "KNOWLEDGE-NOT-WORKFLOW-EDGES"


# Capability discovery and exact version attestation.

make_skill() {
    _ms_root="$1"
    _ms_name="$2"
    _ms_version="$3"
    _ms_actual="${4:-$_ms_name}"
    mkdir -p "$_ms_root/skills/$_ms_name"
    {
        printf '%s\n' '---'
        printf 'name: %s\n' "$_ms_actual"
        printf 'description: "This skill should be used when the user asks for a fixture."\n'
        if [ "$_ms_version" != "-" ]; then
            printf 'version: %s\n' "$_ms_version"
        fi
        printf 'user-invocable: true\nargument-hint: ""\n---\n'
        printf '# %s\n' "$_ms_actual"
    } > "$_ms_root/skills/$_ms_name/SKILL.md"
}

D=$(fixture "preflight none alone")
make_valid "$D" root
make_card "$D" 00-intake - - "" '| None | - | - |
| No touch | `.git/` | - |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+CAPABILITY'
feature "CAP-NONE-MUST-BE-ONLY-ROW"

D=$(fixture "preflight duplicate")
make_valid "$D" root
make_card "$D" 00-intake - - "" '| Tool | sh | 1.0.0 |
| Tool | sh | 1.0.0 |'
t_begin
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --tool-version sh=1.0.0 "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+CAPABILITY'
feature "CAP-DUPLICATE-PREFLIGHT-DECLARATION"

D=$(fixture "preflight unknown kind")
make_valid "$D" root
make_card "$D" 00-intake - - "" '| Plugin | demo | 1.0.0 |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+CAPABILITY'
feature "CAP-UNKNOWN-PREFLIGHT-KIND"

D=$(fixture "tool missing attestation")
make_valid "$D" root
make_card "$D" 00-intake - - "" '| Tool | sh | 1.2.3-fixture |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+CAPABILITY'
feature "CAP-TOOL-MISSING-ATTESTATION"

t_begin
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --tool-version sh=9.9.9 "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+CAPABILITY'
feature "CAP-TOOL-VERSION-MISMATCH"

t_begin
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --tool-version sh=1.2.3-fixture "$D"
t_rc 0
t_out "result: RUN"
feature "CAP-TOOL-EXACT-ATTESTATION"

D=$(fixture "tool never executes")
make_valid "$D" root
mkdir -p "$D/bin"
cat > "$D/bin/fake-tool" <<'ICM_FAKE'
#!/bin/sh
printf 'executed\n' > "$FAKE_MARK"
ICM_FAKE
chmod +x "$D/bin/fake-tool"
make_card "$D" 00-intake - - "" '| Tool | fake-tool | 1.0.0 |'
t_begin
run env FAKE_MARK="$D/PWNED" PATH="$D/bin:$PATH" "$CHECK" --orchestra --job 00-intake/CONTEXT.md --tool-version fake-tool=1.0.0 "$D"
t_rc 0
t_out "result: RUN"
t_nofile "$D/PWNED"
feature "CAP-TOOL-NO-VERSION-EXECUTION"

D=$(fixture "tool unsafe string")
make_valid "$D" root
mkdir -p "$D/bin"
cat > "$D/bin/fake-tool" <<'ICM_FAKE'
#!/bin/sh
printf 'executed\n' > "$FAKE_MARK"
ICM_FAKE
chmod +x "$D/bin/fake-tool"
make_card "$D" 00-intake - - "" '| Tool | fake-tool;fake-tool | 1.0.0 |'
t_begin
run env FAKE_MARK="$D/PWNED" PATH="$D/bin:$PATH" "$CHECK" --orchestra --job 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+CAPABILITY'
t_nofile "$D/PWNED"
feature "CAP-UNSAFE-TOOL-STRING-REFUSED"

D=$(fixture "skill exact")
make_valid "$D" root
make_skill "$D" demo 1.0.0
make_card "$D" 00-intake - - "" '| Skill | demo | 1.0.0 |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
feature "CAP-SKILL-EXACT"

D=$(fixture "skill version mismatch")
make_valid "$D" root
make_skill "$D" demo 2.0.0
make_card "$D" 00-intake - - "" '| Skill | demo | 1.0.0 |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+CAPABILITY'
feature "CAP-SKILL-VERSION-MISMATCH"

D=$(fixture "skill name mismatch")
make_valid "$D" root
make_skill "$D" demo 1.0.0 other
make_card "$D" 00-intake - - "" '| Skill | demo | 1.0.0 |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+CAPABILITY'
feature "CAP-SKILL-NAME-MISMATCH"

D=$(fixture "skill home fallback")
ALT=$(fixture "skill home")
mkdir -p "$ALT"
cp -R "$SCRIPTS" "$ALT/"
cp "$ROOT/icm.defaults.json" "$ALT/icm.defaults.json"
make_valid "$D" root
make_skill "$ALT" demo 1.0.0
make_card "$D" 00-intake - - "" '| Skill | demo | 1.0.0 |'
t_begin
run "$ALT/scripts/icm-check.sh" --orchestra --job 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
feature "CAP-SKILL-HOME-FALLBACK"

D=$(fixture "skill workspace precedence")
ALT=$(fixture "skill precedence home")
mkdir -p "$ALT"
cp -R "$SCRIPTS" "$ALT/"
cp "$ROOT/icm.defaults.json" "$ALT/icm.defaults.json"
make_valid "$D" root
make_skill "$D" demo 2.0.0
make_skill "$ALT" demo 1.0.0
make_card "$D" 00-intake - - "" '| Skill | demo | 1.0.0 |'
t_begin
run "$ALT/scripts/icm-check.sh" --orchestra --job 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+CAPABILITY'
feature "CAP-SKILL-WORKSPACE-PRECEDENCE"

D=$(fixture "skill symlink")
make_valid "$D" root
OUTSIDE_SKILL=$(fixture "outside skill")
make_skill "$OUTSIDE_SKILL" demo 1.0.0
mkdir -p "$D/skills/demo"
ln -s "$OUTSIDE_SKILL/skills/demo/SKILL.md" "$D/skills/demo/SKILL.md"
make_card "$D" 00-intake - - "" '| Skill | demo | 1.0.0 |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "CAP-SKILL-SYMLINK-REFUSED"

D=$(fixture "skill dangling symlink")
make_valid "$D" root
mkdir -p "$D/skills/icm-orchestra"
ln -s missing-target "$D/skills/icm-orchestra/SKILL.md"
make_card "$D" 00-intake - - "" '| Skill | icm-orchestra | 1.0.0 |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "CAP-SKILL-DANGLING-SYMLINK-REFUSED"

D=$(fixture "skill parent symlink")
make_valid "$D" root
OUTSIDE=$(fixture "empty outside skill parent")
mkdir -p "$D/skills"
ln -s "$OUTSIDE" "$D/skills/icm-orchestra"
make_card "$D" 00-intake - - "" '| Skill | icm-orchestra | 1.0.0 |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "CAP-SKILL-PARENT-SYMLINK-REFUSED"

D=$(fixture "skill root symlink")
make_valid "$D" root
OUTSIDE=$(fixture "empty outside skill root")
ln -s "$OUTSIDE" "$D/skills"
make_card "$D" 00-intake - - "" '| Skill | icm-orchestra | 1.0.0 |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "CAP-SKILL-ROOT-SYMLINK-REFUSED"

D=$(fixture "skill home dangling symlink")
ALT=$(fixture "skill home dangling")
mkdir -p "$ALT"
cp -R "$SCRIPTS" "$ALT/"
cp "$ROOT/icm.defaults.json" "$ALT/icm.defaults.json"
make_valid "$D" root
mkdir -p "$ALT/skills/icm-orchestra"
ln -s missing-target "$ALT/skills/icm-orchestra/SKILL.md"
make_card "$D" 00-intake - - "" '| Skill | icm-orchestra | 1.0.0 |'
t_begin
run "$ALT/scripts/icm-check.sh" --orchestra --job 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "CAP-SKILL-HOME-DANGLING-SYMLINK-REFUSED"

D=$(fixture "unrelated skill strict")
make_valid "$D" root
make_skill "$D" unrelated -
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
feature "CAP-UNRELATED-SKILL-NO-VERSION"

# Direct and bound input materialisation.

D=$(fixture "input missing")
make_valid "$D" root
make_card "$D" 00-intake '`intake/missing.md`' - "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+INPUT'
feature "INPUT-MISSING-FILE"

D=$(fixture "input empty")
make_valid "$D" root
make_card "$D" 00-intake '`intake/empty.md`' - "" ""
mkdir -p "$D/intake"
: > "$D/intake/empty.md"
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+INPUT'
feature "INPUT-EMPTY-FILE"

D=$(fixture "input nonempty")
make_valid "$D" root
make_card "$D" 00-intake '`intake/brief.md`' - "" ""
materialize "$D" intake/brief.md
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
feature "INPUT-READABLE-NONEMPTY"

D=$(fixture "input directory gitkeep")
make_valid "$D" root
make_card "$D" 00-intake '`intake/`' - "" ""
mkdir -p "$D/intake"
: > "$D/intake/.gitkeep"
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+INPUT'
feature "INPUT-DIRECTORY-GITKEEP-NOT-MATERIAL"

D=$(fixture "input directory file")
make_valid "$D" root
make_card "$D" 00-intake '`intake/`' - "" ""
mkdir -p "$D/intake/nested"
printf 'brief\n' > "$D/intake/nested/brief.md"
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
feature "INPUT-DIRECTORY-QUALIFIES"

D=$(fixture "bound intake")
make_valid "$D" root
make_card "$D" 00-intake '`@brief`' - "" ""
materialize "$D" intake/brief.txt
t_begin
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --input brief=intake/brief.txt "$D"
t_rc 0
t_out "result: RUN"
feature "INPUT-BOUND-INTAKE-RUN"

t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+INPUT'
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --input brief=intake/absent.txt "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+INPUT'
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --input brief=inline-content "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+INPUT'
feature "INPUT-UNBOUND-MISSING-AND-NO-INLINE"

D=$(fixture "external outside intake")
make_valid "$D" root
make_card "$D" 01-draft '`@brief`' - "" ""
materialize "$D" intake/brief.txt
t_begin
run "$CHECK" --orchestra --job 01-draft/CONTEXT.md --input brief=intake/brief.txt "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+INPUT'
feature "INPUT-EXTERNAL-ONLY-00"

D=$(fixture "binding equals path")
make_valid "$D" root
make_card "$D" 00-intake '`@brief`' - "" ""
materialize "$D" 'intake/a=b.md'
t_begin
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --input 'brief=intake/a=b.md' "$D"
t_rc 0
t_out "result: RUN"
feature "INPUT-BINDING-SPLITS-FIRST-EQUALS"

D=$(fixture "binding directory")
make_valid "$D" root
make_card "$D" 00-intake '`@brief`' - "" ""
mkdir -p "$D/intake/nested"
printf 'brief\n' > "$D/intake/nested/brief.md"
t_begin
run "$CHECK" --orchestra --job 00-intake/CONTEXT.md --input brief=intake/ "$D"
t_rc 0
t_out "result: RUN"
feature "INPUT-BOUND-DIRECTORY-QUALIFIES"

FEATURE_SKIP=0
feature_skip() {
    FEATURE_SKIP=$((FEATURE_SKIP + 1))
    printf 'FEATURE SKIP %s | %s\n' "$1" "$2"
}

AM_ROOT=0
if [ "$(id -u 2>/dev/null || printf 1)" = "0" ]; then
    AM_ROOT=1
fi

D=$(fixture "input unreadable")
make_valid "$D" root
make_card "$D" 00-intake '`intake/secret.md`' - "" ""
materialize "$D" intake/secret.md
if [ "$AM_ROOT" -eq 0 ]; then
    chmod 000 "$D/intake/secret.md"
    t_begin
    strict 00-intake/CONTEXT.md "$D"
    t_rc 1
    t_out_re '^MISSING[[:space:]]+INPUT'
    chmod 644 "$D/intake/secret.md"
    feature "INPUT-UNREADABLE-FILE"
else
    feature_skip "INPUT-UNREADABLE-FILE" "running as root"
fi

# Scope, output types, No touch, never_write, and symlink safety.

D=$(fixture "absolute input")
make_valid "$D" root
OUTSIDE=$(fixture "absolute outside")
printf 'outside\n' > "$OUTSIDE/brief.md"
make_card "$D" 00-intake "\`$OUTSIDE/brief.md\`" - "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "SCOPE-ABSOLUTE-INPUT"

D=$(fixture "escape input")
make_valid "$D" root
printf 'outside\n' > "$WORK/escape outside.md"
make_card "$D" 00-intake '`../escape outside.md`' - "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "SCOPE-WORKSPACE-ESCAPE-INPUT"

D=$(fixture "escape output")
make_valid "$D" root
make_card "$D" 00-intake - '`../escape-output.md`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
t_nofile "$WORK/escape-output.md"
feature "SCOPE-WORKSPACE-ESCAPE-OUTPUT"

D=$(fixture "internal symlink input")
make_valid "$D" root
materialize "$D" intake/real.md
ln -s real.md "$D/intake/link.md"
make_card "$D" 00-intake '`intake/link.md`' - "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "SCOPE-INTERNAL-SYMLINK"

D=$(fixture "escaping symlink input")
make_valid "$D" root
OUTSIDE=$(fixture "symlink outside")
printf 'outside\n' > "$OUTSIDE/brief.md"
mkdir -p "$D/intake"
ln -s "$OUTSIDE/brief.md" "$D/intake/link.md"
make_card "$D" 00-intake '`intake/link.md`' - "" ""
snapshot "$OUTSIDE" "$WORK/symlink outside.before"
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
snapshot "$OUTSIDE" "$WORK/symlink outside.after"
t_same "$WORK/symlink outside.before" "$WORK/symlink outside.after"
feature "SCOPE-ESCAPING-SYMLINK"

D=$(fixture "symlink output parent")
make_valid "$D" root
OUTSIDE=$(fixture "output link outside")
mkdir -p "$OUTSIDE/parent"
ln -s "$OUTSIDE/parent" "$D/output"
make_card "$D" 00-intake - '`output/result.md`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
t_nofile "$OUTSIDE/parent/result.md"
feature "SCOPE-SYMLINK-OUTPUT-PARENT"

D=$(fixture "output parent absent")
make_valid "$D" root
make_card "$D" 00-intake - '`absent/result.md`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
t_nofile "$D/absent"
feature "SCOPE-ABSENT-OUTPUT-PARENT"

D=$(fixture "output absent file")
make_valid "$D" root
mkdir -p "$D/output"
make_card "$D" 00-intake - '`output/result.md`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
t_nofile "$D/output/result.md"
feature "OUTPUT-ABSENT-FILE-EXISTING-PARENT"

D=$(fixture "output existing empty file")
make_valid "$D" root
mkdir -p "$D/output"
: > "$D/output/result.md"
make_card "$D" 00-intake - '`output/result.md`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
feature "OUTPUT-EXISTING-EMPTY-FILE"

D=$(fixture "output absent directory")
make_valid "$D" root
mkdir -p "$D/output"
make_card "$D" 00-intake - '`output/results/`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
t_nofile "$D/output/results"
feature "OUTPUT-ABSENT-DIRECTORY-EXISTING-PARENT"

D=$(fixture "output existing directory")
make_valid "$D" root
mkdir -p "$D/output/results"
make_card "$D" 00-intake - '`output/results/`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
feature "OUTPUT-EXISTING-DIRECTORY"

D=$(fixture "output type mismatch")
make_valid "$D" root
mkdir -p "$D/output"
: > "$D/output/result.md"
make_card "$D" 00-intake - '`output/result.md/`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "OUTPUT-TYPE-MISMATCH"

D=$(fixture "output unwritable parent")
make_valid "$D" root
mkdir -p "$D/output"
make_card "$D" 00-intake - '`output/result.md`' "" ""
if [ "$AM_ROOT" -eq 0 ]; then
    chmod 555 "$D/output"
    t_begin
    strict 00-intake/CONTEXT.md "$D"
    t_rc 1
    t_out_re '^MISSING[[:space:]]+SCOPE'
    chmod 755 "$D/output"
    t_nofile "$D/output/result.md"
    feature "OUTPUT-UNWRITABLE-PARENT"
else
    feature_skip "OUTPUT-UNWRITABLE-PARENT" "running as root"
fi

D=$(fixture "no touch input")
make_valid "$D" root
materialize "$D" private/secret.md
make_card "$D" 00-intake '`private/secret.md`' - "" '| No touch | `private/` | - |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
feature "SCOPE-NO-TOUCH-INPUT"

D=$(fixture "no touch output")
make_valid "$D" root
mkdir -p "$D/private"
make_card "$D" 00-intake - '`private/result.md`' "" '| No touch | `private/` | - |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
t_nofile "$D/private/result.md"
feature "SCOPE-NO-TOUCH-OUTPUT"

D=$(fixture "prefix lookalike")
make_valid "$D" root
materialize "$D" private-old/brief.md
make_card "$D" 00-intake '`private-old/brief.md`' - "" '| No touch | `private/` | - |'
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
feature "SCOPE-PATH-COMPONENT-NOT-PREFIX"

D=$(fixture "scoped spaces")
make_valid "$D" root
materialize "$D" 'intake space/brief file.md'
mkdir -p "$D/output space"
make_card "$D" 00-intake '`intake space/brief file.md`' '`output space/result file.md`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
t_nofile "$D/output space/result file.md"
feature "SCOPE-PATHS-WITH-SPACES"

D=$(fixture "never write output")
make_valid "$D" root
mkdir -p "$D/.git"
make_card "$D" 00-intake - '`.git/result.md`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 1
t_out_re '^MISSING[[:space:]]+SCOPE'
t_nofile "$D/.git/result.md"
feature "SCOPE-NEVER-WRITE-OUTPUT"

D=$(fixture "never write input allowed")
make_valid "$D" root
mkdir -p "$D/.git" "$D/output"
printf 'fixture config\n' > "$D/.git/config"
make_card "$D" 00-intake '`.git/config`' '`output/result.md`' "" ""
t_begin
strict 00-intake/CONTEXT.md "$D"
t_rc 0
t_out "result: RUN"
feature "SCOPE-NEVER-WRITE-IS-OUTPUT-ONLY"


# Deterministic view, independent backlinks, and strict TSV ordering.

D=$(fixture "view sections")
make_pair "$D"
mkdir -p "$D/wiki"
printf '# A\n\nSee [B](wiki/b.md).\n' > "$D/wiki/a.md"
printf '# B\n\nSee [A](wiki/a.md).\n' > "$D/wiki/b.md"
t_begin
run_to "view sections.out" "$CHECK" --orchestra-view "$D"
t_rc 0
grep '^#' "$WORK/view sections.out" > "$WORK/view sections.headings"
cat > "$WORK/view sections.expected" <<'ICM_HEADINGS'
# ICM Orchestra
## Findings
## Pipelines
## Cards
## Workflow Edges
## Workflow Backlinks
## Knowledge Edges
## Knowledge Backlinks
## Notes
ICM_HEADINGS
t_same "$WORK/view sections.expected" "$WORK/view sections.headings"
t_file_out "$WORK/view sections.out" '| NEXT | `CONTEXT.md` | `01-a/CONTEXT.md` |'
t_file_out "$WORK/view sections.out" '| `01-a/CONTEXT.md` | NEXT | `CONTEXT.md` |'
t_file_out "$WORK/view sections.out" '| `wiki/a.md` | `wiki/b.md` |'
t_file_out "$WORK/view sections.out" '| `wiki/b.md` | `wiki/a.md` |'
t_file_out "$WORK/view sections.out" 'result: clean'
awk '
    /^## / { active = 1; first = 1; prev = ""; next }
    /^result:/ { active = 0 }
    active && /^\| / {
        if (first == 1) { first = 0; next }
        if (index($0, "---") > 0) { next }
        if (prev != "" && $0 < prev) { exit 1 }
        prev = $0
    }
' "$WORK/view sections.out"
if [ "$?" -ne 0 ]; then
    t_error "view rows are not sorted inside every section"
fi
feature "VIEW-FIXED-SECTIONS-SORTED-INVERSES"

D=$(fixture "view load inverse")
make_pair "$D"
make_card "$D" 01-a '`02-b/output/result.md`' '`01-a/output/result.md`' "" ""
make_card "$D" 02-b '`01-a/output/result.md`' '`02-b/output/result.md`' "" ""
materialize "$D" 01-a/output/result.md "from a"
materialize "$D" 02-b/output/result.md "from b"
t_begin
run_to "view load inverse.out" "$CHECK" --orchestra-view "$D"
t_rc 1
t_file_out "$WORK/view load inverse.out" '| LOAD | `01-a/CONTEXT.md` | `02-b/CONTEXT.md` |'
t_file_out "$WORK/view load inverse.out" '| `01-a/CONTEXT.md` | LOAD | `02-b/CONTEXT.md` |'
t_file_out "$WORK/view load inverse.out" '| LOAD | `02-b/CONTEXT.md` | `01-a/CONTEXT.md` |'
t_file_out "$WORK/view load inverse.out" '| `02-b/CONTEXT.md` | LOAD | `01-a/CONTEXT.md` |'
feature "VIEW-PRODUCER-LOAD-INVERSE-BACKLINKS"

D=$(fixture "view invalid")
make_valid "$D" root
make_card "$D" 01-duplicate - - "" ""
route "$D/CONTEXT.md" Duplicate 01-duplicate/CONTEXT.md - NEXT
t_begin
run "$CHECK" --orchestra-view "$D"
t_rc 1
t_out "## Findings"
t_out "NUMBERING"
t_out "result: FAIL"
feature "VIEW-STRUCTURAL-FINDINGS-EXIT-1"

D=$(fixture "knowledge orphan")
make_pair "$D"
mkdir -p "$D/wiki"
printf '# Orphan\n\nNo links here.\n' > "$D/wiki/orphan.md"
t_begin
run "$CHECK" --orchestra-view "$D"
t_rc 0
t_out_re 'ORPHAN|orphan'
t_out "result: clean"
feature "VIEW-KNOWLEDGE-ORPHAN-INFORMATIONAL"

D=$(fixture "strict sorted")
make_valid "$D" root
make_card "$D" 00-intake '`@alpha`' - "" '| Tool | sh | 1.0.0 |'
table_add "$D/00-intake/CONTEXT.md" Inputs '| Zeta | `@zeta` | full | deliberately before alpha |'
t_begin
run_to "strict sorted.out" "$CHECK" --orchestra --job 00-intake/CONTEXT.md "$D"
t_rc 1
grep '^MISSING' "$WORK/strict sorted.out" > "$WORK/strict sorted.rows"
sort "$WORK/strict sorted.rows" > "$WORK/strict sorted.expected"
t_same "$WORK/strict sorted.expected" "$WORK/strict sorted.rows"
MISSING_N=$(awk 'END { print NR + 0 }' "$WORK/strict sorted.rows")
t_eq "$MISSING_N" "3"
awk -F '\t' '
    NF != 4 { bad = 1 }
    $2 !~ /^(INPUT|CAPABILITY|ROUTE|SCOPE|AMBIGUOUS)$/ { bad = 1 }
    END { exit bad ? 1 : 0 }
' "$WORK/strict sorted.rows"
if [ "$?" -ne 0 ]; then
    t_error "strict findings are not four-field TSV with public missing types"
fi
t_file_out "$WORK/strict sorted.out" 'result: MISSING'
feature "STRICT-TSV-SORTED-FOUR-FIELDS"

D1=$(fixture "mirror one")
D2=$(fixture "mirror two with spaces")
make_valid "$D1" root
make_valid "$D2" root
t_begin
for MODE in structural view strict; do
    case "$MODE" in
        structural) set -- --orchestra ;;
        view) set -- --orchestra-view ;;
        strict) set -- --orchestra --job 00-intake/CONTEXT.md ;;
    esac
    run_to "mirror one.$MODE" "$CHECK" "$@" "$D1"
    RC1=$RC
    run_to "mirror two.$MODE" "$CHECK" "$@" "$D2"
    RC2=$RC
    t_eq "$RC1" "0"
    t_eq "$RC2" "0"
    t_same "$WORK/mirror one.$MODE" "$WORK/mirror two.$MODE"
    t_file_not_out "$WORK/mirror one.$MODE" "$WORK"
    t_file_not_out "$WORK/mirror two.$MODE" "$WORK"
    t_file_not_out "$WORK/mirror one.$MODE" "$ROOT"
done
feature "DETERMINISTIC-MIRRORED-CLONES"

# Complete target snapshots, including .icm absence and a preexisting sentinel.

D=$(fixture "readonly absent icm")
make_valid "$D" root
snapshot "$D" "$WORK/readonly absent.before"
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
run "$CHECK" --orchestra-view "$D"
t_rc 0
strict 00-intake/CONTEXT.md "$D"
t_rc 0
snapshot "$D" "$WORK/readonly absent.after"
t_same "$WORK/readonly absent.before" "$WORK/readonly absent.after"
t_nofile "$D/.icm"
t_nofile "$D/GRAPH.md"
t_nofile "$D/BACKLINKS.md"
feature "READONLY-COMPLETE-SNAPSHOT-ICM-ABSENT"

D=$(fixture "readonly sentinel")
make_valid "$D" root
mkdir -p "$D/.icm/empty"
printf 'do not change this sentinel\n' > "$D/.icm/sentinel.txt"
ln -s sentinel.txt "$D/.icm/sentinel-link"
snapshot "$D" "$WORK/readonly sentinel.before"
t_begin
run "$CHECK" --orchestra "$D"
t_rc 0
run "$CHECK" --orchestra-view "$D"
t_rc 0
strict 00-intake/CONTEXT.md "$D"
t_rc 0
snapshot "$D" "$WORK/readonly sentinel.after"
t_same "$WORK/readonly sentinel.before" "$WORK/readonly sentinel.after"
t_file_out "$D/.icm/sentinel.txt" 'do not change this sentinel'
if [ ! -L "$D/.icm/sentinel-link" ]; then
    t_error "the preexisting .icm symlink was changed"
fi
feature "READONLY-COMPLETE-SNAPSHOT-ICM-SENTINEL"

D=$(fixture "readonly findings")
make_valid "$D" root
make_card "$D" 00-intake '`intake/missing.md`' - "" ""
make_card "$D" 01-duplicate - - "" ""
route "$D/CONTEXT.md" Duplicate 01-duplicate/CONTEXT.md - NEXT
snapshot "$D" "$WORK/readonly findings.before"
t_begin
run "$CHECK" --orchestra "$D"
t_rc 1
run "$CHECK" --orchestra-view "$D"
t_rc 1
strict 00-intake/CONTEXT.md "$D"
t_rc 1
snapshot "$D" "$WORK/readonly findings.after"
t_same "$WORK/readonly findings.before" "$WORK/readonly findings.after"
t_nofile "$D/.icm"
t_nofile "$D/intake"
feature "READONLY-MISSING-AND-STRUCTURAL-FINDINGS"

# Generated bodies use the existing render gate and existing budgets.

render_body() {
    _rb_out="$WORK/$1"
    _rb_arch="$2"
    _rb_rel="$3"
    _rb_target="$4"
    (
        ICM_HOME="$ROOT"
        . "$ROOT/scripts/icm_lib.sh"
        icm_init "$_rb_target"
        ICM_ARCHETYPE="$_rb_arch"
        export ICM_ARCHETYPE
        trap 'icm_cleanup' EXIT
        icm_render "$_rb_rel" "$_rb_target"
    ) > "$_rb_out" 2>&1
    RC=$?
    OUT=$(cat "$_rb_out" 2>/dev/null)
    return 0
}

for ARCH in quick full wiki; do
    D=$(fixture "body root $ARCH")
    t_begin
    render_body "body root $ARCH.out" "$ARCH" CONTEXT.md "$D"
    t_rc 0
    t_file_out "$WORK/body root $ARCH.out" '| Job | Where | Load first | Edge |'
    t_file_out "$WORK/body root $ARCH.out" 'sh "$ICM_HOME/scripts/icm-check.sh" --orchestra-view .'
    t_file_not_out "$WORK/body root $ARCH.out" '](--orchestra-view)'
    t_file_not_out "$WORK/body root $ARCH.out" 'GRAPH.md'
    t_file_not_out "$WORK/body root $ARCH.out" 'BACKLINKS.md'
    t_file_not_out "$WORK/body root $ARCH.out" '## Pipeline'
    t_file_not_out "$WORK/body root $ARCH.out" '## Backlinks'
    cp "$WORK/body root $ARCH.out" "$D/CONTEXT.md"
    run "$CHECK" --only budgets "$D"
    t_rc 0
    feature "BODY-$ARCH-ROOT-TYPED-VIEW-BUDGET"
done

D=$(fixture "body route helper")
t_begin
(
    ICM_HOME="$ROOT"
    . "$ROOT/scripts/icm_lib.sh"
    icm_init "$D"
    ICM_ARCHETYPE=wiki
    export ICM_ARCHETYPE
    icm_route_row raw/CONTEXT.md Filing - NEXT
) > "$WORK/body route helper.out" 2>&1
RC=$?
OUT=$(cat "$WORK/body route helper.out")
t_rc 0
t_eq "$OUT" '| Filing | `raw/CONTEXT.md` | - | NEXT |'
feature "BODY-ROUTE-ROW-EMITS-EDGE"

D=$(fixture "body raw")
t_begin
render_body "body raw.out" wiki raw/CONTEXT.md "$D"
t_rc 0
t_file_out "$WORK/body raw.out" '## Preflight'
t_file_out "$WORK/body raw.out" '| None | - | - |'
t_file_out "$WORK/body raw.out" '| When | Go to | Edge |'
mkdir -p "$D/raw"
cp "$WORK/body raw.out" "$D/raw/CONTEXT.md"
run "$CHECK" --only budgets "$D"
t_rc 0
run "$CHECK" --only sections "$D"
t_rc 0
feature "BODY-WIKI-RAW-PREFLIGHT-TYPED-BUDGET"

for ARCH in full wiki; do
    D=$(fixture "body output $ARCH")
    t_begin
    render_body "body output $ARCH.out" "$ARCH" output/CONTEXT.md "$D"
    t_rc 0
    t_file_out "$WORK/body output $ARCH.out" '## Preflight'
    t_file_out "$WORK/body output $ARCH.out" '| None | - | - |'
    t_file_out "$WORK/body output $ARCH.out" '| When | Go to | Edge |'
    mkdir -p "$D/output"
    cp "$WORK/body output $ARCH.out" "$D/output/CONTEXT.md"
    run "$CHECK" --only budgets "$D"
    t_rc 0
    run "$CHECK" --only sections "$D"
    t_rc 0
    feature "BODY-$ARCH-OUTPUT-PREFLIGHT-TYPED-BUDGET"
done

for ARCH in quick full wiki; do
    D=$(fixture "generated workspace $ARCH")
    t_begin
    run "$ROOT/scripts/icm-plan.sh" --archetype "$ARCH" "$D"
    t_rc 0
    run "$ROOT/scripts/icm-apply.sh" --no-check "$D"
    t_rc 0
    run "$CHECK" "$D"
    t_rc 0
    run "$CHECK" --orchestra "$D"
    t_rc 0
    t_out "result: clean"
    if [ "$ARCH" = wiki ] && [ ! -d "$D/raw/incoming" ]; then
        t_error "generated wiki raw input directory is absent"
    fi
    feature "GENERATED-$ARCH-ORCHESTRA"
done

printf '\n# summary\n'
printf 'CONTROL PASS %s / FAIL %s\n' "$CONTROL_PASS" "$CONTROL_FAIL"
printf 'FEATURE PASS %s / FAIL %s / SKIP %s\n' "$FEATURE_PASS" "$FEATURE_FAIL" "$FEATURE_SKIP"
TOTAL_PASS=$((CONTROL_PASS + FEATURE_PASS))
TOTAL_FAIL=$((CONTROL_FAIL + FEATURE_FAIL))
printf 'PASS %s / FAIL %s\n' "$TOTAL_PASS" "$TOTAL_FAIL"

if [ "$TOTAL_FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
