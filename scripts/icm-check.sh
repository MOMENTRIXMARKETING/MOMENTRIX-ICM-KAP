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
usage: icm-check.sh [--only ID]... [checks...] [--all] [-h|--help] [target-dir]

Verifies an ICM workspace against icm.defaults.json. Report only, never writes.
target-dir defaults to the current directory.

Checks (pass none, or --all, to run every one):
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
  --all           everything above (the default)
  -h, --help      this text

  --only ID       select one check by its id. Repeatable. Same effect as that
                  check's own flag. The eleven ids are:
                  self frontmatter budgets adapters drift sections routes
                  links fences placeholders evidence

Exit: 0 clean, 1 findings, 2 usage or environment error.
ICM_USAGE
}

ICM_SELF=$(cd "$(dirname "$0")" && pwd)
ICM_HOME=$(cd "$ICM_SELF/.." && pwd)
. "$ICM_HOME/scripts/icm_lib.sh"

TARGET=""
SEL=0
D_SELF=0; D_FM=0; D_BUD=0; D_ADP=0; D_DRIFT=0
D_SEC=0; D_ROUTE=0; D_LINK=0; D_FENCE=0; D_PLACE=0; D_EVID=0

# The complete list. CLI-CONTRACT section 3.2 owns it. There are no others.
ICM_CHECK_IDS='self frontmatter budgets adapters drift sections routes links fences placeholders evidence'

# only_id <id> - select one check by name. Never runs in a subshell, because it
# sets the D_* flags the run block reads. An unrecognised id names the id, not
# the flag, and lists the valid ones.
only_id() {
    case "$1" in
        self)         D_SELF=1 ;;
        frontmatter)  D_FM=1 ;;
        budgets)      D_BUD=1 ;;
        adapters)     D_ADP=1 ;;
        drift)        D_DRIFT=1 ;;
        sections)     D_SEC=1 ;;
        routes)       D_ROUTE=1 ;;
        links)        D_LINK=1 ;;
        fences)       D_FENCE=1 ;;
        placeholders) D_PLACE=1 ;;
        evidence)     D_EVID=1 ;;
        *)
            printf 'FAIL unknown check id: %s\n' "$1" >&2
            printf 'note the eleven check ids are:\n' >&2
            for _oi in $ICM_CHECK_IDS; do printf 'note   %s\n' "$_oi" >&2; done
            printf 'note each one also has a flag of the same name, for example --routes\n' >&2
            exit 2
            ;;
    esac
    SEL=1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --self)         D_SELF=1;  SEL=1 ;;
        --frontmatter)  D_FM=1;    SEL=1 ;;
        --budgets)      D_BUD=1;   SEL=1 ;;
        --adapters)     D_ADP=1;   SEL=1 ;;
        --drift)        D_DRIFT=1; SEL=1 ;;
        --sections)     D_SEC=1;   SEL=1 ;;
        --routes)       D_ROUTE=1; SEL=1 ;;
        --links)        D_LINK=1;  SEL=1 ;;
        --fences)       D_FENCE=1; SEL=1 ;;
        --placeholders) D_PLACE=1; SEL=1 ;;
        --evidence)     D_EVID=1;  SEL=1 ;;
        --only)
            [ $# -ge 2 ] || {
                printf 'FAIL --only needs a check id\n' >&2
                printf 'note the eleven check ids are: %s\n' "$ICM_CHECK_IDS" >&2
                exit 2
            }
            only_id "$2"
            shift ;;
        --only=*)       only_id "${1#--only=}" ;;
        --all)          SEL=0 ;;
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

[ -n "$TARGET" ] || TARGET="."
[ -d "$TARGET" ] || icm_die "no such directory: $TARGET"
TARGET=$(icm_abspath "$TARGET")

if [ "$SEL" -eq 0 ]; then
    D_SELF=1; D_FM=1; D_BUD=1; D_ADP=1; D_DRIFT=1
    D_SEC=1; D_ROUTE=1; D_LINK=1; D_FENCE=1; D_PLACE=1; D_EVID=1
fi

icm_init "$TARGET"

# The checker grades a finished workspace and is given no plan, so it reads the
# archetype off the disk. Everything that asks "is this path ours" then answers
# for the shape this workspace actually has, not for every shape at once.
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

rel_of() {
    printf '%s\n' "${1#$TARGET/}"
}

# Report a char budget. $1 file, $2 label, $3 json budget key.
budget_file() {
    [ -f "$1" ] || return 0
    _b_rel=$(rel_of "$1")
    _b_c=$(icm_chars "$1")
    _b_target=$(icm_json_num "$ICM_DEFAULTS" "budgets.$3.target_chars" 0)
    _b_ceil=$(icm_json_num "$ICM_DEFAULTS" "budgets.$3.ceiling_chars" 0)
    if [ "$_b_ceil" -gt 0 ] && [ "$_b_c" -gt "$_b_ceil" ]; then
        icm_fail "$_b_rel is $_b_c chars, over the $3 ceiling of $_b_ceil (icm.defaults.json)"
    elif [ "$_b_target" -gt 0 ] && [ "$_b_c" -gt "$_b_target" ]; then
        icm_warn "$_b_rel is $_b_c chars, over the $3 target of $_b_target (icm.defaults.json)"
    else
        icm_ok "$_b_rel $_b_c chars, inside the $3 budget"
    fi
    _b_lc=$(icm_json_num "$ICM_DEFAULTS" "budgets.$3.ceiling_lines" 0)
    if [ "$_b_lc" -gt 0 ]; then
        _b_l=$(icm_lines "$1")
        if [ "$_b_l" -gt "$_b_lc" ]; then
            icm_fail "$_b_rel is $_b_l lines, over the $3 line ceiling of $_b_lc (icm.defaults.json)"
        fi
    fi
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

# Markdown link targets only, out of one file. Fenced blocks are skipped, and
# so is anything inside an inline code span, because a backticked
# `[Title](wiki/topic/article.md)` is documentation quoting the syntax, not a
# claim that the path exists.
link_tokens() {
    awk '
        /^ *```/ { inf = 1 - inf; next }
        inf == 1 { next }
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
            while ((a = index(out, "](")) > 0) {
                rest = substr(out, a + 2)
                b = index(rest, ")")
                if (b == 0) { break }
                print substr(rest, 1, b - 1)
                out = substr(rest, b + 1)
            }
        }
    ' "$1"
}

# -------------------------------------------------------------------- checks --

c_self() {
    printf '%s\n' '-- self --'
    if icm_json_get "$ICM_DEFAULTS" toolkit >/dev/null 2>&1; then
        icm_ok "icm.defaults.json parses, toolkit is $ICM_TOOLKIT $ICM_VERSION"
    else
        icm_fail "icm.defaults.json did not parse"
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
        printf '%s\n' '\[\['
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
        if [ "$(head -n 1 "$_f_file")" != "---" ]; then
            icm_fail "skills/$_f_d/SKILL.md does not open with frontmatter, line 1 is not ---"
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
    budget_file "$TARGET/IDENTITY.md" "identity" "IDENTITY.md"
    budget_file "$TARGET/CONTEXT.md" "context-root" "CONTEXT.root.md"
    _bu_md="$ICM_TMPDIR/bumd"
    icm_walk_md "$TARGET" > "$_bu_md"
    while IFS= read -r _bu_r; do
        [ -n "$_bu_r" ] || continue
        case "$_bu_r" in
            CONTEXT.md|IDENTITY.md) continue ;;
            */CONTEXT.md)   budget_file "$TARGET/$_bu_r" "stage" "CONTEXT.stage.md" ;;
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
    _dr_real="$ICM_TMPDIR/realtop"
    icm_top_entries "$TARGET" > "$_dr_real"
    _dr_miss=0
    while IFS= read -r _dr_e; do
        [ -n "$_dr_e" ] || continue
        if grep -q -F -- "$_dr_e" "$_dr_blk"; then
            :
        else
            icm_fail "the workspace map in IDENTITY.md does not document: $_dr_e"
            _dr_miss=$((_dr_miss + 1))
        fi
    done < "$_dr_real"

    _dr_cards="$ICM_TMPDIR/cards"
    icm_walk_md "$TARGET" | grep '/CONTEXT\.md$' > "$_dr_cards" || true
    while IFS= read -r _dr_c; do
        [ -n "$_dr_c" ] || continue
        _dr_dir=$(dirname "$_dr_c")
        _dr_base=$(basename "$_dr_dir")
        if grep -q -F -- "$_dr_base" "$_dr_blk"; then
            :
        else
            icm_fail "the workspace map does not document the folder that holds a job card: $_dr_dir"
            _dr_miss=$((_dr_miss + 1))
        fi
    done < "$_dr_cards"

    if [ "$_dr_miss" -eq 0 ]; then
        icm_ok "the workspace map covers every real top-level entry and every job card folder"
    fi

    # A top level row is "<box drawing>── <name>" and the name may hold spaces,
    # so take the whole rest of the row, then drop the aligned "# ..." comment
    # the map writes after two or more spaces, then the trailing slash. Nested
    # rows carry leading spaces before their box drawing and never match, which
    # is deliberate: their names are relative to a parent, not to the target.
    sed -n 's/^[^ ]*── //p' "$_dr_blk" \
        | sed -e 's/  *#.*$//' -e 's/[ 	]*$//' -e 's|/$||' \
        > "$ICM_TMPDIR/documented"
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
            */CONTEXT.md) sections_of "$TARGET/$_se_r" "required_sections.CONTEXT.stage.md" ;;
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
    while IFS= read -r _ro_r; do
        [ -n "$_ro_r" ] || continue
        _ro_file="$TARGET/$_ro_r"
        _ro_dir=$(dirname "$_ro_file")
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
            if [ -e "$_ro_dir/$_ro_p" ] || [ -e "$TARGET/$_ro_p" ]; then
                :
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
    while IFS= read -r _lk_r; do
        [ -n "$_lk_r" ] || continue
        case "$_lk_r" in
            *.tmpl|*.md.tmpl) continue ;;
        esac
        _lk_file="$TARGET/$_lk_r"
        _lk_dir=$(dirname "$_lk_file")
        link_tokens "$_lk_file" > "$ICM_TMPDIR/ltok"
        while IFS= read -r _lk_t; do
            case "$_lk_t" in
                ''|http:*|https:*|mailto:*|ftp:*|'#'*) continue ;;
            esac
            # a placeholder, a glob or a shell expansion is not a path claim
            case "$_lk_t" in
                *'{{'*|*'*'*|*'<'*|*'$'*|*'|'*) continue ;;
            esac
            _lk_p=${_lk_t%%#*}
            _lk_p=${_lk_p#./}
            [ -n "$_lk_p" ] || continue
            _lk_n=$((_lk_n + 1))
            if [ -e "$_lk_dir/$_lk_p" ] || [ -e "$TARGET/$_lk_p" ]; then
                :
            else
                icm_fail "$_lk_r links to a path that does not exist: $_lk_t"
                _lk_bad=1
            fi
        done < "$ICM_TMPDIR/ltok"
    done < "$_lk_md"
    if [ "$_lk_bad" -eq 0 ]; then
        icm_ok "every relative markdown link resolves on disk ($_lk_n checked)"
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
        icm_note "it needs python3 3.10 or newer. the toolkit does not require python at all, this check is the one optional extra"
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
