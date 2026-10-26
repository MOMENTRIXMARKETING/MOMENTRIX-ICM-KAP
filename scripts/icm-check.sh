#!/bin/sh
# icm-check.sh - the verifier for an ICM workspace.
#
# Report only. This script never writes a file inside the target.
# Exit 0 when clean, 1 when anything FAILed, 2 on a usage or environment error.
#
# POSIX sh only. No bashisms. No python required.

set -e

usage() {
    cat <<'ICM_USAGE'
usage: icm-check.sh [--only ID]... [--<check>]... [--all] [-h|--help] [target-dir]
       icm-check.sh --only orchestra [target-dir]
       icm-check.sh --orchestra [target-dir]
       icm-check.sh --orchestra --job CARD [--input NAME=PATH]...
                    [--tool-version NAME=VERSION]... [target-dir]
       icm-check.sh --orchestra-view [target-dir]

Verifies an ICM workspace against icm.defaults.json. Report only, never writes.
target-dir defaults to the current directory.

Generic checks (the default and --all select these eleven, never Orchestra):
  --self          shell layer: sh -n, bashism sweep, defaults parse
  --frontmatter   skills/<name>/SKILL.md frontmatter and naming
  --budgets       character and line ceilings from icm.defaults.json
  --adapters      CLAUDE.md is an alias of IDENTITY.md, not a copy of it
  --drift         the workspace map in IDENTITY.md covers the real tree
  --sections      required sections per icm.defaults.json
  --routes        every routing-table target in a CONTEXT.md exists on disk
  --links         every relative markdown link in every .md resolves on disk
  --fences        markdown code fences are balanced
  --placeholders  no unfilled {{ }} placeholders survive
  --evidence      deep grounding sweep (needs python3 and wiki/; part of --all)
  --all           the eleven generic checks above
  -h, --help      this text

  --only ID       select one check by its id. Repeatable. The twelve ids are:
                  self frontmatter budgets adapters drift sections routes
                  links fences placeholders evidence orchestra

Orchestra is explicit only:
  --orchestra       structural graph, same as --only orchestra
  --orchestra-view  deterministic Markdown graph and inverse indexes
  --job CARD        strict preflight, only with literal --orchestra --job
  --input NAME=PATH bind an external input to existing workspace material
  --tool-version NAME=VERSION attest an exact Tool version, never runs NAME --version

RUN means ready to start, not completed work or external-action approval.
Exit: 0 clean or RUN, 1 findings or MISSING, 2 usage or environment error.
ICM_USAGE
}

ICM_SELF=$(cd "$(dirname "$0")" && pwd)
ICM_HOME=$(cd "$ICM_SELF/.." && pwd)
. "$ICM_HOME/scripts/icm_lib.sh"

TARGET=""
SEL=0
D_SELF=0; D_FM=0; D_BUD=0; D_ADP=0; D_DRIFT=0
D_SEC=0; D_ROUTE=0; D_LINK=0; D_FENCE=0; D_PLACE=0; D_EVID=0
ORCH_FLAG=0; ORCH_ONLY=0; ORCH_VIEW=0; ORCH_GENERIC=0; ORCH_ALL=0
JOB_SET=0; JOB=""; INPUT_ARGS=""; TOOL_ARGS=""; INPUT_NAMES=" "; TOOL_NAMES=" "
CLI_TAB=$(printf '\t')
CLI_NL='
'

ICM_CHECK_IDS='self frontmatter budgets adapters drift sections routes links fences placeholders evidence orchestra'

only_id() {
    case "$1" in
        self)         D_SELF=1; ORCH_GENERIC=1 ;;
        frontmatter)  D_FM=1; ORCH_GENERIC=1 ;;
        budgets)      D_BUD=1; ORCH_GENERIC=1 ;;
        adapters)     D_ADP=1; ORCH_GENERIC=1 ;;
        drift)        D_DRIFT=1; ORCH_GENERIC=1 ;;
        sections)     D_SEC=1; ORCH_GENERIC=1 ;;
        routes)       D_ROUTE=1; ORCH_GENERIC=1 ;;
        links)        D_LINK=1; ORCH_GENERIC=1 ;;
        fences)       D_FENCE=1; ORCH_GENERIC=1 ;;
        placeholders) D_PLACE=1; ORCH_GENERIC=1 ;;
        evidence)     D_EVID=1; ORCH_GENERIC=1 ;;
        orchestra)    ORCH_ONLY=1 ;;
        *)
            printf 'FAIL unknown check id: %s\n' "$1" >&2
            printf 'note the twelve check ids are:\n' >&2
            for _oi in $ICM_CHECK_IDS; do printf 'note   %s\n' "$_oi" >&2; done
            printf 'note each one also has a flag of the same name, for example --routes\n' >&2
            exit 2
            ;;
    esac
    SEL=1
}

cli_machine_field() {
    case "$2" in
        *"$CLI_TAB"*) printf 'FAIL tab in a CLI machine field\n' >&2; exit 2 ;;
        *"$CLI_NL"*)  printf 'FAIL newline in a CLI machine field\n' >&2; exit 2 ;;
    esac
}

cli_binding() {
    _cb_flag="$1"
    _cb_value="$2"
    cli_machine_field "$_cb_flag" "$_cb_value"
    case "$_cb_value" in
        *=*) _cb_name=${_cb_value%%=*}; _cb_data=${_cb_value#*=} ;;
        *)   printf 'FAIL malformed %s\n' "$_cb_flag" >&2; exit 2 ;;
    esac
    _cb_bad=0
    [ -n "$_cb_name" ] && [ -n "$_cb_data" ] || _cb_bad=1
    case "$_cb_name" in [A-Za-z]*) ;; *) _cb_bad=1 ;; esac
    case "$_cb_name" in *[!A-Za-z0-9_-]*) _cb_bad=1 ;; esac
    [ "$_cb_bad" -eq 0 ] || { printf 'FAIL malformed %s\n' "$_cb_flag" >&2; exit 2; }
    if [ "$_cb_flag" = "--input" ]; then
        case "$INPUT_NAMES" in *" $_cb_name "*) printf 'FAIL duplicate --input: %s\n' "$_cb_name" >&2; exit 2 ;; esac
        INPUT_NAMES="$INPUT_NAMES$_cb_name "
        INPUT_ARGS="${INPUT_ARGS}${_cb_value}
"
    else
        case "$TOOL_NAMES" in *" $_cb_name "*) printf 'FAIL duplicate --tool-version: %s\n' "$_cb_name" >&2; exit 2 ;; esac
        TOOL_NAMES="$TOOL_NAMES$_cb_name "
        TOOL_ARGS="${TOOL_ARGS}${_cb_value}
"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --self)         D_SELF=1;  SEL=1; ORCH_GENERIC=1 ;;
        --frontmatter)  D_FM=1;    SEL=1; ORCH_GENERIC=1 ;;
        --budgets)      D_BUD=1;   SEL=1; ORCH_GENERIC=1 ;;
        --adapters)     D_ADP=1;   SEL=1; ORCH_GENERIC=1 ;;
        --drift)        D_DRIFT=1; SEL=1; ORCH_GENERIC=1 ;;
        --sections)     D_SEC=1;   SEL=1; ORCH_GENERIC=1 ;;
        --routes)       D_ROUTE=1; SEL=1; ORCH_GENERIC=1 ;;
        --links)        D_LINK=1;  SEL=1; ORCH_GENERIC=1 ;;
        --fences)       D_FENCE=1; SEL=1; ORCH_GENERIC=1 ;;
        --placeholders) D_PLACE=1; SEL=1; ORCH_GENERIC=1 ;;
        --evidence)     D_EVID=1;  SEL=1; ORCH_GENERIC=1 ;;
        --orchestra)    ORCH_FLAG=1; SEL=1 ;;
        --orchestra-view) ORCH_VIEW=1; SEL=1 ;;
        --job)
            [ $# -ge 2 ] || { printf 'FAIL --job needs a card\n' >&2; exit 2; }
            [ "$JOB_SET" -eq 0 ] || { printf 'FAIL duplicate --job\n' >&2; exit 2; }
            cli_machine_field --job "$2"
            JOB_SET=1; JOB="$2"; SEL=1; shift ;;
        --input)
            [ $# -ge 2 ] || { printf 'FAIL malformed --input\n' >&2; exit 2; }
            cli_binding --input "$2"; SEL=1; shift ;;
        --tool-version)
            [ $# -ge 2 ] || { printf 'FAIL malformed --tool-version\n' >&2; exit 2; }
            cli_binding --tool-version "$2"; SEL=1; shift ;;
        --only)
            [ $# -ge 2 ] || {
                printf 'FAIL --only needs a check id\n' >&2
                printf 'note the twelve check ids are: %s\n' "$ICM_CHECK_IDS" >&2
                exit 2
            }
            only_id "$2"
            shift ;;
        --only=*)       only_id "${1#--only=}" ;;
        --all)          SEL=0; ORCH_ALL=1 ;;
        -h|--help)      usage; exit 0 ;;
        --*)            printf 'FAIL unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
        *)
            if [ -n "$TARGET" ]; then
                printf 'FAIL more than one target given: %s\n' "$1" >&2
                exit 2
            fi
            TARGET="$1"
            ;;
    esac
    shift
done

ORCH_MODE=""
if [ "$ORCH_VIEW" -eq 1 ] && { [ "$ORCH_FLAG" -eq 1 ] || [ "$ORCH_ONLY" -eq 1 ] || [ "$JOB_SET" -eq 1 ] || [ -n "$INPUT_ARGS" ] || [ -n "$TOOL_ARGS" ] || [ "$ORCH_GENERIC" -eq 1 ] || [ "$ORCH_ALL" -eq 1 ]; }; then
    printf 'FAIL mixed Orchestra view and another check mode\n' >&2
    exit 2
fi
if { [ "$ORCH_FLAG" -eq 1 ] || [ "$ORCH_ONLY" -eq 1 ]; } && { [ "$ORCH_GENERIC" -eq 1 ] || [ "$ORCH_ALL" -eq 1 ]; }; then
    printf 'FAIL mixed Orchestra and generic check selection\n' >&2
    exit 2
fi
if [ "$ORCH_FLAG" -eq 1 ] && [ "$JOB_SET" -eq 1 ] && [ "$ORCH_ONLY" -eq 0 ]; then
    ORCH_MODE=strict
elif [ "$JOB_SET" -eq 1 ] || [ -n "$INPUT_ARGS" ] || [ -n "$TOOL_ARGS" ]; then
    printf 'FAIL --job, --input and --tool-version require literal --orchestra --job strict mode\n' >&2
    exit 2
elif [ "$ORCH_VIEW" -eq 1 ]; then
    ORCH_MODE=view
elif [ "$ORCH_FLAG" -eq 1 ] || [ "$ORCH_ONLY" -eq 1 ]; then
    ORCH_MODE=structural
fi

[ -n "$TARGET" ] || TARGET="."
TARGET=$(icm_require_target "$TARGET") || exit 2

if [ -z "$ORCH_MODE" ] && [ "$SEL" -eq 0 ]; then
    D_SELF=1; D_FM=1; D_BUD=1; D_ADP=1; D_DRIFT=1
    D_SEC=1; D_ROUTE=1; D_LINK=1; D_FENCE=1; D_PLACE=1; D_EVID=1
fi

icm_init "$TARGET"

if [ -n "$ORCH_MODE" ]; then
    icm_tally_init
    trap 'icm_cleanup' EXIT INT TERM
    : > "$ICM_TMPDIR/cli.inputs"
    : > "$ICM_TMPDIR/cli.tools"
    printf '%s' "$INPUT_ARGS" | while IFS= read -r _cli_row; do
        [ -n "$_cli_row" ] || continue
        printf '%s\t%s\n' "${_cli_row%%=*}" "${_cli_row#*=}" >> "$ICM_TMPDIR/cli.inputs"
    done
    printf '%s' "$TOOL_ARGS" | while IFS= read -r _cli_row; do
        [ -n "$_cli_row" ] || continue
        printf '%s\t%s\n' "${_cli_row%%=*}" "${_cli_row#*=}" >> "$ICM_TMPDIR/cli.tools"
    done
    cp "$ICM_TMPDIR/cli.inputs" "$ICM_TMPDIR/orchestra.cli.inputs"
    cp "$ICM_TMPDIR/cli.tools" "$ICM_TMPDIR/orchestra.cli.tools"
    if icm_orchestra_report "$ORCH_MODE" "$JOB"; then
        exit 0
    else
        exit $?
    fi
fi

ICM_ARCHETYPE=$(icm_detect_archetype "$TARGET")
export ICM_ARCHETYPE
icm_tally_init
trap 'icm_cleanup' EXIT INT TERM

printf '# icm-check\n'
printf 'target:   %s\n' "$TARGET"
printf 'defaults: %s\n' "$ICM_DEFAULTS"
printf '\n'

_shanote=$(icm_sha_mode_note)
if [ -n "$_shanote" ]; then
    icm_note "$_shanote"
fi

# ------------------------------------------------------------------- helpers --

# A folder that holds its own IDENTITY.md is a workspace root in its own right.
# spec/layers.md, layer 0: a folder that feels like it needs an IDENTITY.md is a
# separate workspace, not a department. So the CONTEXT.md sitting beside one is
# that workspace's layer 1, not a job card, and the tree under it is documented
# by that IDENTITY.md rather than by the target's. Without this a repo carrying a
# worked example workspace inside it grades that workspace against the wrong file
# and reports failures that are not there.

# True when the relative path of a CONTEXT.md sits beside an IDENTITY.md.
nested_root_card() {
    [ -f "$(dirname "$TARGET/$1")/IDENTITY.md" ]
}

# True when a relative directory sits inside a nested workspace root, meaning
# some ancestor below the target holds its own IDENTITY.md. The target's own
# root never matches, because the walk stops before it.
under_nested_root() {
    _un_p="$1"
    while [ -n "$_un_p" ] && [ "$_un_p" != "." ] && [ "$_un_p" != "/" ]; do
        if [ -f "$TARGET/$_un_p/IDENTITY.md" ]; then
            return 0
        fi
        _un_p=$(dirname "$_un_p")
    done
    return 1
}

rel_of() {
    printf '%s\n' "${1#$TARGET/}"
}

# Report byte and optional line budgets against explicit values.
budget_file_values() {
    [ -f "$1" ] || return 0
    _b_rel=$(rel_of "$1")
    _b_c=$(icm_chars "$1")
    _b_target=$2
    _b_ceil=$3
    _b_lc=$4
    _b_label=$5
    if [ "$_b_ceil" -gt 0 ] && [ "$_b_c" -gt "$_b_ceil" ]; then
        icm_fail "$_b_rel is $_b_c chars, over the $_b_label ceiling of $_b_ceil (icm.defaults.json)"
    elif [ "$_b_target" -gt 0 ] && [ "$_b_c" -gt "$_b_target" ]; then
        icm_warn "$_b_rel is $_b_c chars, over the $_b_label target of $_b_target (icm.defaults.json)"
    else
        icm_ok "$_b_rel $_b_c chars, inside the $_b_label budget"
    fi
    if [ "$_b_lc" -gt 0 ]; then
        _b_l=$(icm_lines "$1")
        if [ "$_b_l" -gt "$_b_lc" ]; then
            icm_fail "$_b_rel is $_b_l lines, over the $_b_label line ceiling of $_b_lc (icm.defaults.json)"
        fi
    fi
}

# Report a char budget. $1 file, $2 label, $3 json budget key.
budget_file() {
    [ -f "$1" ] || return 0
    _b_target=$(icm_json_num "$ICM_DEFAULTS" "budgets.$3.target_chars" 0)
    _b_ceil=$(icm_json_num "$ICM_DEFAULTS" "budgets.$3.ceiling_chars" 0)
    _b_lc=$(icm_json_num "$ICM_DEFAULTS" "budgets.$3.ceiling_lines" 0)
    budget_file_values "$1" "$_b_target" "$_b_ceil" "$_b_lc" "$3"
}

path_budgets_init() {
    _pb_rules="$ICM_TMPDIR/path-budgets"
    _pb_active=0
    : > "$_pb_rules"
    _pb_i=0
    while _pb_pattern=$(icm_json_get "$ICM_DEFAULTS" "path_budgets.${_pb_i}.pattern" 2>/dev/null); do
        _pb_target=$(icm_json_num "$ICM_DEFAULTS" "path_budgets.${_pb_i}.target_chars" 0)
        _pb_ceil=$(icm_json_num "$ICM_DEFAULTS" "path_budgets.${_pb_i}.ceiling_chars" 0)
        _pb_lines=$(icm_json_num "$ICM_DEFAULTS" "path_budgets.${_pb_i}.ceiling_lines" 0)
        printf '%s|%s|%s|%s\n' "$_pb_pattern" "$_pb_target" "$_pb_ceil" "$_pb_lines" >> "$_pb_rules"
        _pb_active=1
        _pb_i=$((_pb_i + 1))
    done
}

path_budget_file() {
    [ "$_pb_active" -eq 1 ] || return 1
    [ -f "$TARGET/$1" ] || return 1
    while IFS='|' read -r _pb_pattern _pb_target _pb_ceil _pb_lines; do
        [ -n "$_pb_pattern" ] || continue
        case "$1" in
            $_pb_pattern)
                budget_file_values "$TARGET/$1" "$_pb_target" "$_pb_ceil" "$_pb_lines" "path pattern $_pb_pattern"
                return 0
                ;;
        esac
    done < "$_pb_rules"
    return 1
}

# Check the required sections of one file. $1 file, $2 json path.
sections_of() {
    [ -f "$1" ] || return 0
    _s_rel=$(rel_of "$1")
    _s_list="$ICM_TMPDIR/secs.$$"
    icm_json_list "$ICM_DEFAULTS" "$2" > "$_s_list"
    if [ ! -s "$_s_list" ]; then
        rm -f "$_s_list"
        return 0
    fi
    _s_bad=0
    while IFS= read -r _s_sec; do
        [ -n "$_s_sec" ] || continue
        if awk -v s="$_s_sec" 'index($0, s) == 1 { f = 1 } END { exit f ? 0 : 1 }' "$1"; then
            :
        else
            icm_fail "$_s_rel is missing a required section: $_s_sec"
            _s_bad=1
        fi
    done < "$_s_list"
    rm -f "$_s_list"
    if [ "$_s_bad" -eq 0 ]; then
        icm_ok "$_s_rel has every required section"
    fi
}

# Candidate path tokens out of a markdown file: backticked spans and link
# targets, ignoring anything inside a fenced code block.
route_tokens() {
    awk '
        /^ *```/ { inf = 1 - inf; next }
        inf == 1 { next }
        /^## / {
            preflight = ($0 == "## Preflight")
            if (preflight) { next }
        }
        preflight == 1 { next }
        {
            line = $0
            while ((a = index(line, "`")) > 0) {
                rest = substr(line, a + 1)
                b = index(rest, "`")
                if (b == 0) { break }
                print substr(rest, 1, b - 1)
                line = substr(rest, b + 1)
            }
            l2 = $0
            while ((a = index(l2, "](")) > 0) {
                rest = substr(l2, a + 2)
                b = index(rest, ")")
                if (b == 0) { break }
                print substr(rest, 1, b - 1)
                l2 = substr(rest, b + 1)
            }
        }
    ' "$1"
}

# Markdown and wiki targets, typed M| or W|. Fenced blocks and inline code
# are documentation quoting syntax, not path claims.
link_tokens() {
    awk '
        BEGIN { lb = "[" }
        /^ *```/ { inf = 1 - inf; next }
        /^ *~~~/ { tin = 1 - tin; next }
        inf == 1 || tin == 1 { next }
        {
            line = $0
            out = ""
            while ((a = index(line, "`")) > 0) {
                out = out substr(line, 1, a - 1)
                rest = substr(line, a + 1)
                b = index(rest, "`")
                if (b == 0) { line = ""; break }
                line = substr(rest, b + 1)
            }
            out = out line
            md = out
            while ((a = index(md, "](")) > 0) {
                rest = substr(md, a + 2)
                b = index(rest, ")")
                if (b == 0) { break }
                printf "M|%s\n", substr(rest, 1, b - 1)
                md = substr(rest, b + 1)
            }
            while ((a = index(out, lb lb)) > 0) {
                rest = substr(out, a + 2)
                b = index(rest, "]]" )
                if (b == 0) { break }
                target = substr(rest, 1, b - 1)
                if (target != "" && substr(target, 1, 1) != "[") {
                    printf "W|%s\n", target
                }
                out = substr(rest, b + 1)
            }
        }
    ' "$1"
}

# -------------------------------------------------------------------- checks --

c_self() {
    printf '%s\n' '-- self --'
    # The parse is judged on the file's own flatten. The merged view always
    # has a toolkit key from the toolkit, so it cannot say this file parses.
    _c_d="$ICM_TMPDIR/self.defaults"
    if ! icm_json_parse "$ICM_DEFAULTS" "$_c_d" 2>/dev/null; then
        icm_fail "icm.defaults.json did not parse: $(head -n 1 "$_c_d.err")"
    elif icm_json_get "$ICM_DEFAULTS" toolkit >/dev/null 2>&1; then
        icm_ok "icm.defaults.json parses, toolkit is $ICM_TOOLKIT $ICM_VERSION"
    else
        icm_fail "icm.defaults.json parses but names no toolkit"
    fi
    for _c_k in excluded_globs never_write; do
        if icm_json_list "$ICM_DEFAULTS" "$_c_k" | grep -q .; then
            icm_ok "icm.defaults.json $_c_k is populated"
        else
            icm_fail "icm.defaults.json $_c_k is empty"
        fi
    done

    _c_sh="$ICM_TMPDIR/shfiles"
    : > "$_c_sh"
    icm_walk_files "$TARGET" | grep '\.sh$' >> "$_c_sh" || true
    if [ ! -s "$_c_sh" ]; then
        icm_note "no shell scripts under $TARGET, syntax and bashism sweep skipped"
        return 0
    fi

    # The patterns are split across two printf arguments on purpose. Written
    # whole they would be literal bashisms in this file, and a plain grep for
    # them would flag the checker itself.
    _c_pat="$ICM_TMPDIR/bashisms"
    {
        printf '%s\n' '\[\[($|[^:])'
        printf '%s%s\n' '(^| |;)lo' 'cal '
        printf '%s\n' '<\('
        printf '%s\n' '\$\{[A-Za-z_][A-Za-z0-9_]*\^\^'
        printf '%s\n' '=\('
        printf '%s\n' '(^|;)[ ]*(declare|typeset|mapfile|readarray|shopt) '
        printf '%s%s\n' 'echo ' '-e'
        printf '%s%s\n' '(^|;)[ ]*sou' 'rce '
        printf '%s\n' '\$\{![A-Za-z_]'
    } > "$_c_pat"

    while IFS= read -r _c_f; do
        [ -n "$_c_f" ] || continue
        if sh -n "$TARGET/$_c_f" 2>"$ICM_TMPDIR/shn"; then
            icm_ok "$_c_f passes sh -n"
        else
            icm_fail "$_c_f fails sh -n: $(head -n 2 "$ICM_TMPDIR/shn" | tr '\n' ' ')"
        fi
        if grep -n -E -f "$_c_pat" "$TARGET/$_c_f" > "$ICM_TMPDIR/bhits" 2>/dev/null; then
            while IFS= read -r _c_h; do
                icm_fail "$_c_f bashism: $_c_h"
            done < "$ICM_TMPDIR/bhits"
        fi
    done < "$_c_sh"

    # The banned frontmatter key must not appear as a key anywhere.
    _c_ban="$ICM_TMPDIR/banned"
    : > "$_c_ban"
    icm_json_list "$ICM_DEFAULTS" frontmatter.banned_keys > "$_c_ban"
    _c_md="$ICM_TMPDIR/allmd"
    icm_walk_md "$TARGET" > "$_c_md"
    while IFS= read -r _c_k2; do
        [ -n "$_c_k2" ] || continue
        while IFS= read -r _c_f2; do
            [ -n "$_c_f2" ] || continue
            if grep -q -E "^ *$_c_k2 *:" "$TARGET/$_c_f2" 2>/dev/null; then
                icm_fail "$_c_f2 uses the banned key $_c_k2"
            fi
        done < "$_c_md"
    done < "$_c_ban"
}

c_frontmatter() {
    printf '%s\n' '-- frontmatter --'
    if [ ! -d "$TARGET/skills" ]; then
        icm_note "no skills/ under the target, frontmatter check skipped"
        return 0
    fi
    _f_dirs="$ICM_TMPDIR/skdirs"
    icm_top_entries "$TARGET/skills" > "$_f_dirs"
    if [ ! -s "$_f_dirs" ]; then
        icm_note "skills/ is empty, frontmatter check skipped"
        return 0
    fi
    _f_req="$ICM_TMPDIR/fmreq"
    _f_ban="$ICM_TMPDIR/fmban"
    icm_json_list "$ICM_DEFAULTS" frontmatter.required_keys > "$_f_req"
    icm_json_list "$ICM_DEFAULTS" frontmatter.banned_keys > "$_f_ban"
    _f_eq=$(icm_json_get "$ICM_DEFAULTS" frontmatter.name_must_equal_dirname 2>/dev/null) || _f_eq="true"

    while IFS= read -r _f_d; do
        [ -n "$_f_d" ] || continue
        [ -d "$TARGET/skills/$_f_d" ] || continue
        _f_file="$TARGET/skills/$_f_d/SKILL.md"
        if [ ! -f "$_f_file" ]; then
            icm_fail "skills/$_f_d has no SKILL.md"
            continue
        fi
        _f_l1=$(head -n 1 "$_f_file")
        if [ "$_f_l1" != "---" ]; then
            if [ "$(printf '%s' "$_f_l1" | tr -d '\r')" = "---" ]; then
                icm_fail "skills/$_f_d/SKILL.md has CRLF line endings; the frontmatter reader wants LF. convert it, then rerun"
            else
                icm_fail "skills/$_f_d/SKILL.md does not open with frontmatter, line 1 is not ---"
            fi
            continue
        fi
        _f_blk="$ICM_TMPDIR/fmblk"
        icm_fm_block "$_f_file" > "$_f_blk"
        if [ ! -s "$_f_blk" ]; then
            icm_fail "skills/$_f_d/SKILL.md has an empty or unterminated frontmatter block"
            continue
        fi
        _f_bad=0
        while IFS= read -r _f_k; do
            [ -n "$_f_k" ] || continue
            if grep -q -E "^ *$_f_k *:" "$_f_blk"; then
                if [ -z "$(icm_fm_get "$_f_file" "$_f_k")" ]; then
                    icm_fail "skills/$_f_d/SKILL.md has an empty $_f_k"
                    _f_bad=1
                fi
            else
                icm_fail "skills/$_f_d/SKILL.md is missing the required key $_f_k"
                _f_bad=1
            fi
        done < "$_f_req"
        while IFS= read -r _f_b; do
            [ -n "$_f_b" ] || continue
            if grep -q -E "^ *$_f_b *:" "$_f_blk"; then
                icm_fail "skills/$_f_d/SKILL.md uses the banned key $_f_b"
                _f_bad=1
            fi
        done < "$_f_ban"
        if [ "$_f_eq" = "true" ]; then
            _f_name=$(icm_fm_get "$_f_file" name)
            if [ "$_f_name" != "$_f_d" ]; then
                icm_fail "skills/$_f_d/SKILL.md name is '$_f_name', it must equal the directory name '$_f_d'"
                _f_bad=1
            fi
        fi
        if ! grep -q -E '^ *user-invocable *:' "$_f_blk"; then
            icm_warn "skills/$_f_d/SKILL.md has no user-invocable key (hyphen, per BUILD-CONTRACT.md)"
        fi
        if ! grep -q -E '^ *argument-hint *:' "$_f_blk"; then
            icm_warn "skills/$_f_d/SKILL.md has no argument-hint key"
        fi
        if [ "$_f_bad" -eq 0 ]; then
            icm_ok "skills/$_f_d/SKILL.md frontmatter is clean"
        fi
    done < "$_f_dirs"
}

c_budgets() {
    printf '%s\n' '-- budgets --'
    path_budgets_init
    if ! path_budget_file "IDENTITY.md"; then
        budget_file "$TARGET/IDENTITY.md" "identity" "IDENTITY.md"
    fi
    if ! path_budget_file "CONTEXT.md"; then
        budget_file "$TARGET/CONTEXT.md" "context-root" "CONTEXT.root.md"
    fi
    _bu_md="$ICM_TMPDIR/bumd"
    icm_walk_md "$TARGET" > "$_bu_md"
    while IFS= read -r _bu_r; do
        [ -n "$_bu_r" ] || continue
        if path_budget_file "$_bu_r"; then
            continue
        fi
        case "$_bu_r" in
            CONTEXT.md|IDENTITY.md) continue ;;
            */CONTEXT.md)
                if nested_root_card "$_bu_r"; then
                    budget_file "$TARGET/$_bu_r" "context-root" "CONTEXT.root.md"
                else
                    budget_file "$TARGET/$_bu_r" "stage" "CONTEXT.stage.md"
                fi ;;
            _config/*.md)   budget_file "$TARGET/$_bu_r" "rulebook" "rulebook.md" ;;
            wiki/index.md|wiki/log.md) : ;;
            wiki/*.md)      budget_file "$TARGET/$_bu_r" "article" "wiki_article.md" ;;
        esac
    done < "$_bu_md"
}

c_adapters() {
    printf '%s\n' '-- adapters --'
    _ad_id="$TARGET/IDENTITY.md"
    _ad_cl="$TARGET/CLAUDE.md"
    if [ ! -f "$_ad_id" ]; then
        icm_warn "no IDENTITY.md at the target root, this is not an ICM workspace yet"
        return 0
    fi
    if [ ! -f "$_ad_cl" ]; then
        icm_warn "no CLAUDE.md adapter, nothing points Claude at IDENTITY.md"
    else
        if grep -q -F '@IDENTITY.md' "$_ad_cl"; then
            icm_ok "CLAUDE.md aliases IDENTITY.md"
        else
            icm_fail "CLAUDE.md does not contain @IDENTITY.md, so it is not an alias"
        fi
        _ad_sig="$ICM_TMPDIR/idsig"
        grep -v '^ *$' "$_ad_id" | awk 'length($0) >= 20' | sort -u > "$_ad_sig"
        _ad_tot=$(awk 'END { print NR + 0 }' "$_ad_sig")
        if [ "$_ad_tot" -gt 0 ]; then
            _ad_dup=$(grep -c -F -x -f "$_ad_sig" "$_ad_cl" 2>/dev/null) || _ad_dup=0
            if [ "$_ad_dup" -ge 3 ] && [ $((_ad_dup * 2)) -ge "$_ad_tot" ]; then
                icm_fail "CLAUDE.md duplicates the IDENTITY.md body ($_ad_dup of $_ad_tot lines copied), it must be an alias not a copy"
            else
                icm_ok "CLAUDE.md is not a copy of IDENTITY.md ($_ad_dup of $_ad_tot lines shared)"
            fi
        fi
    fi
    for _ad_o in AGENTS.md GEMINI.md .cursorrules .windsurfrules; do
        if [ -f "$TARGET/$_ad_o" ]; then
            if grep -q -F 'IDENTITY.md' "$TARGET/$_ad_o"; then
                icm_ok "$_ad_o points at IDENTITY.md"
            else
                icm_warn "$_ad_o exists but never mentions IDENTITY.md, that adapter will drift"
            fi
        fi
    done
}

c_drift() {
    printf '%s\n' '-- drift --'
    _dr_id="$TARGET/IDENTITY.md"
    if [ ! -f "$_dr_id" ]; then
        icm_warn "no IDENTITY.md, the workspace map cannot be checked"
        return 0
    fi
    _dr_blk="$ICM_TMPDIR/idtree"
    icm_first_fence_block "$_dr_id" > "$_dr_blk"
    if [ ! -s "$_dr_blk" ]; then
        icm_fail "IDENTITY.md has no fenced workspace map, there is nothing to compare to disk"
        return 0
    fi
    # Two name lists from the map, compared whole-line, never as substrings:
    # "_log/" in the map must not vouch for a real "log/", nor a nested
    # "voice.md" row for a top-level file of that name. A top level row is
    # "<box drawing>── <name>" and the name may hold spaces, so take the whole
    # rest of the row, then drop the aligned "# ..." comment the map writes
    # after two or more spaces, then the trailing slash. Nested rows carry
    # leading spaces before their box drawing; "documented" leaves them out on
    # purpose, because their names are relative to a parent, not to the
    # target, while "allnames" keeps every row for the job card folder check.
    sed -n 's/^[^ ]*── //p' "$_dr_blk" \
        | sed -e 's/  *#.*$//' -e 's/[ 	]*$//' -e 's|/$||' \
        > "$ICM_TMPDIR/documented"
    sed -n 's/^.*── //p' "$_dr_blk" \
        | sed -e 's/  *#.*$//' -e 's/[ 	]*$//' -e 's|/$||' \
        > "$ICM_TMPDIR/allnames"
    _dr_real="$ICM_TMPDIR/realtop"
    icm_top_entries "$TARGET" > "$_dr_real"
    _dr_miss=0
    while IFS= read -r _dr_e; do
        [ -n "$_dr_e" ] || continue
        if grep -q -x -F -- "$_dr_e" "$ICM_TMPDIR/documented"; then
            :
        else
            icm_fail "the workspace map in IDENTITY.md does not document: $_dr_e"
            _dr_miss=$((_dr_miss + 1))
        fi
    done < "$_dr_real"

    _dr_cards="$ICM_TMPDIR/cards"
    icm_walk_md "$TARGET" | grep '/CONTEXT\.md$' > "$_dr_cards" || true
    _dr_nested=0
    while IFS= read -r _dr_c; do
        [ -n "$_dr_c" ] || continue
        _dr_dir=$(dirname "$_dr_c")
        if under_nested_root "$_dr_dir"; then
            _dr_nested=$((_dr_nested + 1))
            continue
        fi
        _dr_base=$(basename "$_dr_dir")
        if grep -q -x -F -- "$_dr_base" "$ICM_TMPDIR/allnames"; then
            :
        else
            icm_fail "the workspace map does not document the folder that holds a job card: $_dr_dir"
            _dr_miss=$((_dr_miss + 1))
        fi
    done < "$_dr_cards"

    if [ "$_dr_miss" -eq 0 ]; then
        icm_ok "the workspace map covers every real top-level entry and every job card folder"
    fi
    if [ "$_dr_nested" -gt 0 ]; then
        icm_note "$_dr_nested job card folder(s) sit inside a nested workspace root, which carries its own IDENTITY.md; run the checker on that folder to grade them against their own map"
    fi

    # The reverse pass: every top level row the map documents must be on disk.
    while IFS= read -r _dr_d; do
        [ -n "$_dr_d" ] || continue
        if [ -e "$TARGET/$_dr_d" ]; then
            :
        else
            icm_warn "the workspace map documents a path that is not on disk: $_dr_d"
        fi
    done < "$ICM_TMPDIR/documented"
}

c_sections() {
    printf '%s\n' '-- sections --'
    sections_of "$TARGET/IDENTITY.md" "required_sections.IDENTITY.md"
    sections_of "$TARGET/CONTEXT.md" "required_sections.CONTEXT.root.md"
    _se_md="$ICM_TMPDIR/semd"
    icm_walk_md "$TARGET" > "$_se_md"
    while IFS= read -r _se_r; do
        [ -n "$_se_r" ] || continue
        case "$_se_r" in
            CONTEXT.md) continue ;;
            */CONTEXT.md)
                if nested_root_card "$_se_r"; then
                    sections_of "$TARGET/$_se_r" "required_sections.CONTEXT.root.md"
                else
                    sections_of "$TARGET/$_se_r" "required_sections.CONTEXT.stage.md"
                fi ;;
        esac
    done < "$_se_md"
}

c_routes() {
    printf '%s\n' '-- routes --'
    _ro_md="$ICM_TMPDIR/romd"
    icm_walk_md "$TARGET" | grep 'CONTEXT\.md$' > "$_ro_md" || true
    if [ ! -s "$_ro_md" ]; then
        icm_note "no CONTEXT.md anywhere under the target, route check skipped"
        return 0
    fi
    _ro_bad=0
    : > "$ICM_TMPDIR/depth.notes"
    while IFS= read -r _ro_r; do
        [ -n "$_ro_r" ] || continue
        _ro_file="$TARGET/$_ro_r"
        _ro_dir=$(dirname "$_ro_file")
        _ro_root="$TARGET"
        _ro_scope=$(dirname -- "$_ro_r")
        while [ "$_ro_scope" != "." ] && [ "$_ro_scope" != "/" ] && [ -n "$_ro_scope" ]; do
            if [ -f "$TARGET/$_ro_scope/IDENTITY.md" ]; then
                _ro_root="$TARGET/$_ro_scope"
                break
            fi
            _ro_scope=$(dirname -- "$_ro_scope")
        done
        route_tokens "$_ro_file" > "$ICM_TMPDIR/rtok"
        while IFS= read -r _ro_t; do
            case "$_ro_t" in
                ''|http*|'#'*) continue ;;
            esac
            case "$_ro_t" in
                *'{{'*|*'*'*|*'['*|*'<'*|*'|'*|*' '*|*'...'*|*'$'*|*'`'*) continue ;;
            esac
            case "$_ro_t" in
                */*|*.md) ;;
                *) continue ;;
            esac
            _ro_p="${_ro_t#./}"
            if [ -e "$_ro_dir/$_ro_p" ] || [ -e "$_ro_root/$_ro_p" ]; then
                _ro_rdir=$(dirname -- "$_ro_r")
                if [ -e "$_ro_dir/$_ro_p" ]; then
                    _ro_dest=$(icm_orchestra_normalize "$_ro_rdir" "$_ro_p" 2>/dev/null || printf '')
                else
                    _ro_dest=$(icm_orchestra_normalize . "$_ro_p" 2>/dev/null || printf '')
                fi
                _ro_stage=$(basename -- "$_ro_rdir")
                case "$_ro_stage:$_ro_dest" in
                    [0-9][0-9]-*:"$_ro_rdir"/*/CONTEXT.md)
                        if ! grep -q -F -x -- "$_ro_dest" "$ICM_TMPDIR/depth.notes"; then
                            printf '%s\n' "$_ro_dest" >> "$ICM_TMPDIR/depth.notes"
                            icm_note "$_ro_r routes to a fourth nested context card (depth): $_ro_dest"
                        fi
                        ;;
                esac
            else
                icm_fail "$_ro_r routes to a path that does not exist: $_ro_t"
                _ro_bad=1
            fi
        done < "$ICM_TMPDIR/rtok"
    done < "$_ro_md"
    if [ "$_ro_bad" -eq 0 ]; then
        icm_ok "every routing target in every CONTEXT.md exists on disk"
    fi
}

link_has_scheme() {
    _ls_prefix=${1%%:*}
    [ "$_ls_prefix" != "$1" ] || return 1
    case $_ls_prefix in *\\) _ls_prefix=${_ls_prefix%\\} ;; esac
    case $_ls_prefix in
        ''|[!A-Za-z]*|*[!A-Za-z0-9+.-]*) return 1 ;;
    esac
    return 0
}

c_links() {
    printf '%s\n' '-- links --'
    _lk_md="$ICM_TMPDIR/lkmd"
    icm_walk_md "$TARGET" > "$_lk_md"
    if [ ! -s "$_lk_md" ]; then
        icm_note "no markdown under the target, link check skipped"
        return 0
    fi
    _lk_bad=0
    _lk_n=0
    _lk_lb='['
    _lk_wtok="$ICM_TMPDIR/lkwiki.tokens"
    : > "$_lk_wtok"
    while IFS= read -r _lk_r; do
        [ -n "$_lk_r" ] || continue
        case "$_lk_r" in
            *.tmpl|*.md.tmpl) continue ;;
        esac
        _lk_file="$TARGET/$_lk_r"
        _lk_dir=$(dirname "$_lk_file")
        link_tokens "$_lk_file" > "$ICM_TMPDIR/ltok"
        while IFS= read -r _lk_line; do
            case $_lk_line in
                W\|*)
                    _lk_t=${_lk_line#W|}
                    _lk_w=${_lk_t%%|*}
                    _lk_w=${_lk_w%%#*}
                    [ -n "$_lk_w" ] || continue
                    _lk_n=$((_lk_n + 1))
                    _lk_c1=""
                    _lk_c2=""
                    case $_lk_w in
                        */*)
                            _lk_rel=$(dirname -- "$_lk_r")
                            _lk_c1=$(icm_orchestra_normalize "$_lk_rel" "$_lk_w" 2>/dev/null || printf '')
                            _lk_c2=$(icm_orchestra_normalize . "$_lk_w" 2>/dev/null || printf '')
                            if [ -z "$_lk_c1" ] && [ -z "$_lk_c2" ]; then
                                icm_fail "$_lk_r wiki target escapes the workspace: ${_lk_lb}[${_lk_t}]]"
                                _lk_bad=1
                                continue
                            fi
                            ;;
                    esac
                    printf '%s\t%s\t%s\t%s\n' "$_lk_r" "$_lk_t" "$_lk_c1" "$_lk_c2" >> "$_lk_wtok"
                    ;;
                M\|*)
                    _lk_t=${_lk_line#M|}
                    [ -n "$_lk_t" ] || continue
                    case $_lk_t in
                        '#'*) continue ;;
                    esac
                    if link_has_scheme "$_lk_t"; then
                        continue
                    fi
                    # a placeholder, a glob or a shell expansion is not a path claim
                    case $_lk_t in
                        *'{{'*|*'*'*|*'<'*|*'$'*|*'|'*) continue ;;
                    esac
                    # A markdown destination may carry a title after a space,
                    # [m](IDENTITY.md "the map"), and a space in a path is written
                    # %20. Neither is part of the path claim.
                    _lk_p=$(printf '%s\n' "$_lk_t" | sed -e 's/ *"[^"]*" *$//' -e "s/ *'[^']*' *$//" -e 's/%20/ /g')
                    _lk_p=${_lk_p%%\?*}
                    _lk_p=${_lk_p%%#*}
                    _lk_p=${_lk_p#./}
                    [ -n "$_lk_p" ] || continue
                    _lk_n=$((_lk_n + 1))
                    if [ -e "$_lk_dir/$_lk_p" ] || [ -e "$TARGET/$_lk_p" ]; then
                        :
                    else
                        icm_fail "$_lk_r links to a path that does not exist: $_lk_t"
                        _lk_bad=1
                    fi
                    ;;
            esac
        done < "$ICM_TMPDIR/ltok"
    done < "$_lk_md"

    if [ -s "$_lk_wtok" ]; then
        _lk_files="$ICM_TMPDIR/lkfiles"
        _lk_wout="$ICM_TMPDIR/lkwiki.out"
        icm_walk "$TARGET" f > "$_lk_files"
        awk -F '\t' '
            NR == FNR {
                path = $0
                present[path] = 1
                n = split(path, part, "/")
                base = part[n]
                count[base]++
                if (count[base] == 1) { first[base] = path }
                next
            }
            BEGIN { lb = "[" }
            {
                src = $1; raw = $2; c1 = $3; c2 = $4; target = raw
                sub(/\|.*/, "", target)
                sub(/#.*/, "", target)
                if (target == "") { next }
                matches = 0
                if (index(target, "/") == 0) {
                    for (j = 0; j < 2; j++) {
                        if (j == 0) { key = target }
                        else {
                            if (target ~ /\.md$/) { continue }
                            key = target ".md"
                        }
                        if (key in count) {
                            if (count[key] > 1) { matches += count[key]; continue }
                            p = first[key]
                            if (seen[p] != FNR) { seen[p] = FNR; matches++ }
                        }
                    }
                } else {
                    for (j = 0; j < 2; j++) {
                        c = (j == 0 ? c1 : c2)
                        if (c == "") { continue }
                        for (k = 0; k < 2; k++) {
                            if (k == 1 && c ~ /\.md$/) { continue }
                            p = (k == 0 ? c : c ".md")
                            if ((p in present) && seen[p] != FNR) { seen[p] = FNR; matches++ }
                        }
                    }
                }
                if (matches == 0) {
                    printf "%s links to a wiki target that does not exist: %s%s%s]]\n", src, lb, lb, raw
                } else if (matches > 1) {
                    printf "%s has an ambiguous wiki target: %s%s%s]] (%d matches)\n", src, lb, lb, raw, matches
                }
            }
        ' "$_lk_files" "$_lk_wtok" > "$_lk_wout"
        while IFS= read -r _lk_msg; do
            [ -n "$_lk_msg" ] || continue
            icm_fail "$_lk_msg"
            _lk_bad=1
        done < "$_lk_wout"
    fi
    if [ "$_lk_bad" -eq 0 ]; then
        icm_ok "every relative markdown and wiki link resolves on disk ($_lk_n checked)"
    fi
}

c_fences() {
    printf '%s\n' '-- fences --'
    _fe_md="$ICM_TMPDIR/femd"
    icm_walk_md "$TARGET" > "$_fe_md"
    if [ ! -s "$_fe_md" ]; then
        icm_note "no markdown under the target, fence check skipped"
        return 0
    fi
    _fe_bad=0
    while IFS= read -r _fe_r; do
        [ -n "$_fe_r" ] || continue
        _fe_b=$(icm_fence_count "$TARGET/$_fe_r" | head -n 1)
        _fe_t=$(icm_fence_count "$TARGET/$_fe_r" | tail -n 1)
        if [ $((_fe_b % 2)) -ne 0 ]; then
            icm_fail "$_fe_r has $_fe_b backtick fence lines, an odd count leaves a block open"
            _fe_bad=1
        fi
        if [ $((_fe_t % 2)) -ne 0 ]; then
            icm_fail "$_fe_r has $_fe_t tilde fence lines, an odd count leaves a block open"
            _fe_bad=1
        fi
    done < "$_fe_md"
    if [ "$_fe_bad" -eq 0 ]; then
        icm_ok "every markdown file has balanced code fences"
    fi
}

c_placeholders() {
    printf '%s\n' '-- placeholders --'
    _pl_md="$ICM_TMPDIR/plmd"
    icm_walk_md "$TARGET" > "$_pl_md"
    _pl_bad=0
    while IFS= read -r _pl_r; do
        [ -n "$_pl_r" ] || continue
        case "$_pl_r" in
            *.tmpl) continue ;;
        esac
        icm_live_placeholders "$TARGET/$_pl_r" > "$ICM_TMPDIR/plhits"
        if [ -s "$ICM_TMPDIR/plhits" ]; then
            while IFS= read -r _pl_h; do
                icm_fail "$_pl_r carries an unfilled placeholder at line $_pl_h"
                _pl_bad=1
            done < "$ICM_TMPDIR/plhits"
        fi
    done < "$_pl_md"
    if [ "$_pl_bad" -eq 0 ]; then
        icm_ok "no unfilled placeholders in live prose"
    fi
    icm_note "a *.tmpl file is exempt, it is interview material a human fills in, and so is any placeholder inside a code fence or backticks, which is documentation quoting the syntax"
}

c_evidence() {
    printf '%s\n' '-- evidence --'
    if [ ! -d "$TARGET/wiki" ]; then
        icm_note "no wiki/ under the target, the deep grounding check does not apply"
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        icm_note "python3 is not on PATH, the deep grounding check was skipped; every other check still ran"
        return 0
    fi
    _ev_py="$ICM_HOME/scripts/check_evidence.py"
    if [ ! -f "$_ev_py" ]; then
        icm_note "scripts/check_evidence.py is not present, the deep grounding check was skipped"
        return 0
    fi
    _ev_out="$ICM_TMPDIR/evidence.txt"
    _ev_rc=0
    python3 "$_ev_py" "$TARGET" > "$_ev_out" 2>&1 || _ev_rc=$?
    head -n 60 "$_ev_out" | while IFS= read -r _ev_l; do
        printf '     | %s\n' "$_ev_l"
    done
    if [ "$(icm_lines "$_ev_out")" -gt 60 ]; then
        printf '     | ... relay truncated at 60 lines\n'
    fi
    # No Summary line means the script did not complete. Say the check was
    # skipped. Never report a clean grounding sweep that never happened.
    if ! grep -q '^## Summary' "$_ev_out"; then
        icm_note "check_evidence.py did not complete here (exit $_ev_rc), so the deep grounding check was skipped; every other check still ran"
        icm_note "it needs python3 3.10 or newer; on a newer python the relayed lines above hold the cause. the toolkit does not require python at all, this check is the one optional extra"
        return 0
    fi
    _ev_err=$(sed -n 's/.*, \([0-9][0-9]*\) evidence error(s).*/\1/p' "$_ev_out" | head -n 1)
    _ev_sus=$(sed -n 's/^\([0-9][0-9]*\) fidelity suspect(s).*/\1/p' "$_ev_out" | head -n 1)
    [ -n "$_ev_err" ] || _ev_err=0
    [ -n "$_ev_sus" ] || _ev_sus=0
    if [ "$_ev_err" -gt 0 ]; then
        icm_fail "check_evidence.py found $_ev_err evidence error(s): an article cannot be verified at all"
    else
        icm_ok "check_evidence.py found no evidence errors"
    fi
    if [ "$_ev_sus" -gt 0 ]; then
        icm_warn "check_evidence.py found $_ev_sus fidelity suspect(s), each one is a judgment call for a human"
    fi
}

# ----------------------------------------------------------------------- run --

if [ "$D_SELF"  -eq 1 ]; then c_self;         fi
if [ "$D_FM"    -eq 1 ]; then c_frontmatter;  fi
if [ "$D_BUD"   -eq 1 ]; then c_budgets;      fi
if [ "$D_ADP"   -eq 1 ]; then c_adapters;     fi
if [ "$D_DRIFT" -eq 1 ]; then c_drift;        fi
if [ "$D_SEC"   -eq 1 ]; then c_sections;     fi
if [ "$D_ROUTE" -eq 1 ]; then c_routes;       fi
if [ "$D_LINK"  -eq 1 ]; then c_links;        fi
if [ "$D_FENCE" -eq 1 ]; then c_fences;       fi
if [ "$D_PLACE" -eq 1 ]; then c_placeholders; fi
if [ "$D_EVID"  -eq 1 ]; then c_evidence;     fi

FAILS=$(icm_count FAIL)
WARNS=$(icm_count WARN)
OKS=$(icm_count OK)

printf '\n'; printf '%s\n' '-- summary --'
printf 'ok %s   warn %s   FAIL %s\n' "$OKS" "$WARNS" "$FAILS"

if [ "$FAILS" -gt 0 ]; then
    printf 'result: FAIL\n'
    exit 1
fi
printf 'result: clean\n'
exit 0
