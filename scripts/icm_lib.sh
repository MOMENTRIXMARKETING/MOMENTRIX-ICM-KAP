#!/bin/sh
# icm_lib.sh - shared POSIX helpers for the Momentrix ICM KAP Toolkit.
#
# This file is dot-sourced, never executed:
#
#   ICM_SELF=$(cd "$(dirname "$0")" && pwd)
#   ICM_HOME=$(cd "$ICM_SELF/.." && pwd)
#   . "$ICM_HOME/scripts/icm_lib.sh"
#   icm_init "$TARGET"
#   trap 'icm_cleanup' EXIT INT TERM
#
# POSIX sh only. No bashisms. Tested with: sh -n scripts/icm_lib.sh
#
# What lives here:
#   json      icm_json_get / icm_json_list / icm_json_num  (reads icm.defaults.json)
#   walking   icm_top_entries / icm_walk_files / icm_walk_md / icm_excluded
#   counting  icm_chars / icm_lines
#   markdown  icm_fm_get / icm_fm_block / icm_first_fence_block / icm_fence_count
#   writing   icm_atomic_write / icm_splice
#   hashing   icm_sha  (shasum -a 256, else sha256sum, else degraded size+mtime)
#   install   icm_manifest / icm_candidate / icm_render / icm_tree
#   output    icm_ok / icm_fail / icm_warn / icm_note  (+ tally, subshell safe)

# ---------------------------------------------------------------- constants --

ICM_BEGIN='<!-- icm:begin -->'
ICM_END='<!-- icm:end -->'
ICM_TMPDIR=""
ICM_TALLY=""
ICM_SHA_MODE=""
ICM_DEFAULTS=""
ICM_TOOLKIT="Momentrix ICM KAP Toolkit"
ICM_VERSION="0"
ICM_JSON_SRC=""
ICM_JSON_CACHE=""

# ------------------------------------------------------------------- basics --

icm_die() {
    printf 'FAIL %s\n' "$*" >&2
    exit 2
}

# Resolve a path physically. A directory that cannot be entered, or whose name
# starts with a dash, is a named refusal (exit 2), never a raw shell error and
# never exit 1. cd is given -- and -P so a leading dash is a path, not an
# option, and so a symlinked directory resolves to where it really is.
icm_abspath() {
    if [ -d "$1" ]; then
        _a_r=$( cd -P -- "$1" 2>/dev/null && pwd -P ) || _a_r=""
        [ -n "$_a_r" ] || icm_die "cannot resolve directory: $1 (unreadable, untraversable, or gone)"
        printf '%s\n' "$_a_r"
        return 0
    fi
    _a_d=$(dirname -- "$1")
    _a_b=$(basename -- "$1")
    _a_p=$( cd -P -- "$_a_d" 2>/dev/null && pwd -P ) || _a_p="$_a_d"
    case "$_a_p" in
        */) printf '%s%s\n' "$_a_p" "$_a_b" ;;
        *)  printf '%s/%s\n' "$_a_p" "$_a_b" ;;
    esac
}

# The physical directory a path's parent resolves to, or empty when it cannot
# be resolved. This is the only containment primitive; a textual test on the
# relative path cannot see a managed folder that is a symlink.
icm_parent_real() {
    _pr_d=$(dirname -- "$1")
    ( cd -P -- "$_pr_d" 2>/dev/null && pwd -P ) || printf ''
}

# icm_path_escape <target> <relpath> -> a reason on stdout when writing that
# relative path would land outside the target, empty when it is contained.
#
# Textual tests alone are not containment. A managed folder that is a symlink to
# a shared docs tree makes a write land in another checkout while the plan still
# names the path as wiki/index.md, so every directory component is tested for
# being a link and the deepest existing parent is resolved physically.
icm_path_escape() {
    _pe_t="$1"
    _pe_rp="$2"
    case "$_pe_rp" in
        /*)   printf 'outside target (absolute path in the plan)\n'; return 0 ;;
        *..*) printf 'outside target (the path contains ..)\n';      return 0 ;;
    esac
    _pe_cur="$_pe_t"
    _pe_rest="$_pe_rp"
    while : ; do
        case "$_pe_rest" in
            */*) _pe_head=${_pe_rest%%/*}; _pe_rest=${_pe_rest#*/} ;;
            *)   break ;;
        esac
        [ -n "$_pe_head" ] || continue
        _pe_cur="$_pe_cur/$_pe_head"
        if [ -L "$_pe_cur" ]; then
            printf 'outside target (the managed folder %s is a symlink)\n' "$_pe_head"
            return 0
        fi
    done
    _pe_par=$(icm_parent_real "$_pe_t/$_pe_rp")
    if [ -n "$_pe_par" ] && ! icm_under "$_pe_par" "$_pe_t"; then
        printf 'outside target after resolving symlinks\n'
        return 0
    fi
    printf ''
    return 1
}

# True when $1 is $2 or below it. Both must already be physical paths.
icm_under() {
    [ -n "$1" ] || return 1
    [ "$1" = "$2" ] && return 0
    case "$1" in
        "$2"/*) return 0 ;;
    esac
    return 1
}

# icm_require_target <raw target> -> the physical path on stdout.
# Every refusal here is exit 2 with a FAIL line. Nothing below this point ever
# sees a target it cannot read, cannot enter, or that is not a directory, and
# nothing ever sees a .icm that is not a directory.
icm_require_target() {
    _rt_in="$1"
    case "$_rt_in" in
        -*) _rt_in="./$_rt_in" ;;
    esac
    [ -e "$_rt_in" ] || icm_die "no such directory: $1"
    [ -d "$_rt_in" ] || icm_die "not a directory: $1"
    _rt_abs=$( cd -P -- "$_rt_in" 2>/dev/null && pwd -P ) || _rt_abs=""
    [ -n "$_rt_abs" ] || icm_die "cannot enter $1 (check its permissions)"
    [ -r "$_rt_abs" ] || icm_die "cannot read $1 (check its permissions)"
    if [ -e "$_rt_abs/.icm" ] && [ ! -d "$_rt_abs/.icm" ]; then
        icm_die "$_rt_abs/.icm exists and is not a directory. move it aside, then rerun."
    fi
    printf '%s\n' "$_rt_abs"
}

# A stamp that cannot collide. A whole second is not unique: two applies in the
# same second would share one backup directory and the second would store the
# first one's output as the "pre-image".
icm_utc_stamp() {
    printf '%s-%s\n' "$(date -u '+%Y%m%dT%H%M%SZ')" "$$"
}

icm_utc_iso() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

icm_today() {
    date -u '+%Y-%m-%d'
}

# ------------------------------------------------------------ temp + tally --

icm_tmp_init() {
    if [ -n "$ICM_TMPDIR" ] && [ -d "$ICM_TMPDIR" ]; then
        return 0
    fi
    ICM_TMPDIR="${TMPDIR:-/tmp}/icm-$$"
    rm -rf "$ICM_TMPDIR"
    mkdir -p "$ICM_TMPDIR" || icm_die "cannot create work dir $ICM_TMPDIR"
}

icm_cleanup() {
    if [ -n "$ICM_TMPDIR" ] && [ -d "$ICM_TMPDIR" ]; then
        rm -rf "$ICM_TMPDIR"
    fi
}

# A POSIX trap handler that does not exit returns to the script, so a bare
# 'trap icm_cleanup INT' deletes the work directory and lets the run carry on
# into a loop iteration whose candidate body has just been removed underneath
# it. Every script arms its signals through this, so a signal actually stops
# the run and reports the conventional status.
icm_trap_default() {
    trap 'icm_cleanup' EXIT
    trap 'icm_cleanup; exit 130' INT
    trap 'icm_cleanup; exit 143' TERM
}

# Findings are tallied through a file so that counts survive pipelines and
# subshells. Never count with a shell variable in this codebase.
icm_tally_init() {
    icm_tmp_init
    ICM_TALLY="$ICM_TMPDIR/tally"
    : > "$ICM_TALLY"
}

icm_ok() {
    printf 'ok   %s\n' "$*"
    if [ -n "$ICM_TALLY" ]; then printf 'OK\n' >> "$ICM_TALLY"; fi
}

icm_fail() {
    printf 'FAIL %s\n' "$*"
    if [ -n "$ICM_TALLY" ]; then printf 'FAIL\n' >> "$ICM_TALLY"; fi
}

icm_warn() {
    printf 'warn %s\n' "$*"
    if [ -n "$ICM_TALLY" ]; then printf 'WARN\n' >> "$ICM_TALLY"; fi
}

icm_note() {
    printf 'note %s\n' "$*"
}

icm_count() {
    if [ -z "$ICM_TALLY" ] || [ ! -f "$ICM_TALLY" ]; then
        printf '0\n'
        return 0
    fi
    awk -v k="$1" '$0 == k { n++ } END { print n + 0 }' "$ICM_TALLY"
}

# --------------------------------------------------------------------- json --

# Flatten a JSON document to "dotted.path<TAB>value" lines.
# Keys that contain dots (IDENTITY.md) simply become part of the path, so a
# lookup is always by the exact flattened string.
icm_json_flatten() {
    awk '
    { s = s $0 "\n" }
    END {
        # The dotted path is rebuilt inline at each emit. An awk subroutine would
        # read better, but the bashism sweep matches that keyword anywhere in
        # this file and awk has no other way to spell it.
        n = length(s); i = 1; depth = 0
        while (i <= n) {
            c = substr(s, i, 1)
            if (c == " " || c == "\t" || c == "\r" || c == "\n") { i++; continue }
            if (c == "{") { depth++; typ[depth] = "o"; expk[depth] = 1; ky[depth] = ""; i++; continue }
            if (c == "[") { depth++; typ[depth] = "a"; idx[depth] = 0; i++; continue }
            if (c == "}" || c == "]") {
                depth--
                if (depth >= 1 && typ[depth] == "a") { idx[depth]++ }
                i++; continue
            }
            if (c == ",") { if (typ[depth] == "o") { expk[depth] = 1 } i++; continue }
            if (c == ":") { expk[depth] = 0; i++; continue }
            if (c == "\"") {
                j = i + 1; str = ""
                while (j <= n) {
                    ch = substr(s, j, 1)
                    if (ch == "\\") {
                        nx = substr(s, j + 1, 1)
                        if (nx == "n")      { str = str "\n" }
                        else if (nx == "t") { str = str "\t" }
                        else                { str = str nx }
                        j += 2; continue
                    }
                    if (ch == "\"") { break }
                    str = str ch; j++
                }
                i = j + 1
                if (typ[depth] == "o" && expk[depth] == 1) { ky[depth] = str }
                else {
                    P = ""
                    for (d = 1; d <= depth; d++) {
                        if (typ[d] == "o") { P = (P == "" ? ky[d] : P "." ky[d]) }
                        else               { P = (P == "" ? idx[d] "" : P "." idx[d]) }
                    }
                    printf "%s\t%s\n", P, str
                    if (typ[depth] == "a") { idx[depth]++ }
                }
                continue
            }
            j = i
            while (j <= n) {
                ch = substr(s, j, 1)
                if (ch == "," || ch == "]" || ch == "}" || ch == " " || ch == "\t" || ch == "\r" || ch == "\n") { break }
                j++
            }
            val = substr(s, i, j - i); i = j
            P = ""
            for (d = 1; d <= depth; d++) {
                if (typ[d] == "o") { P = (P == "" ? ky[d] : P "." ky[d]) }
                else               { P = (P == "" ? idx[d] "" : P "." idx[d]) }
            }
            printf "%s\t%s\n", P, val
            if (typ[depth] == "a") { idx[depth]++ }
        }
    }
    ' "$1"
}

icm_json_load() {
    icm_tmp_init
    if [ "$ICM_JSON_SRC" = "$1" ] && [ -f "$ICM_JSON_CACHE" ]; then
        return 0
    fi
    [ -f "$1" ] || icm_die "no such defaults file: $1"
    ICM_JSON_CACHE="$ICM_TMPDIR/defaults.flat"
    icm_json_flatten "$1" > "$ICM_JSON_CACHE"
    ICM_JSON_SRC="$1"
}

# icm_json_get <file> <flattened.path>  -> value on stdout, exit 1 if absent
icm_json_get() {
    icm_json_load "$1"
    awk -F '\t' -v k="$2" '$1 == k { print $2; found = 1; exit } END { if (!found) exit 1 }' "$ICM_JSON_CACHE"
}

# icm_json_list <file> <flattened.path-of-array>  -> one element per line
icm_json_list() {
    icm_json_load "$1"
    awk -F '\t' -v k="$2" '
        index($1, k ".") == 1 {
            rest = substr($1, length(k) + 2)
            if (rest ~ /^[0-9]+$/) { print $2 }
        }
    ' "$ICM_JSON_CACHE"
}

# icm_json_num <file> <path> <fallback>  -> integer, always succeeds
icm_json_num() {
    _n_v=$(icm_json_get "$1" "$2" 2>/dev/null) || _n_v=""
    case "$_n_v" in
        ''|*[!0-9]*) printf '%s\n' "$3" ;;
        *)           printf '%s\n' "$_n_v" ;;
    esac
}

# ------------------------------------------------------------------ walking --

# True (exit 0) when a basename matches one of excluded_globs.
icm_excluded() {
    for _x_g in $(icm_json_list "$ICM_DEFAULTS" excluded_globs); do
        case "$1" in
            $_x_g) return 0 ;;
        esac
    done
    return 1
}

# True (exit 0) when a relative path may be written.
#
# The test is on ANY path component, not just the first, because a never_write
# name can appear at any depth: docs/sub/node_modules/x.md and a/.git/config are
# both refusals. Wrapping the candidate in slashes is what makes the first and
# last components match too. The globs still come from icm.defaults.json; they
# are never hand typed here.
icm_never_write_ok() {
    _w_p="/$1/"
    for _w_g in $(icm_json_list "$ICM_DEFAULTS" never_write); do
        case "$_w_p" in
            *"/$_w_g/"*) return 1 ;;
        esac
    done
    return 0
}

# The never_write component that refuses a path, for the message. Empty when
# the path is writable.
icm_never_write_hit() {
    _wh_p="/$1/"
    for _wh_g in $(icm_json_list "$ICM_DEFAULTS" never_write); do
        case "$_wh_p" in
            *"/$_wh_g/"*) printf '%s\n' "$_wh_g"; return 0 ;;
        esac
    done
    printf ''
}

# Top level entries of a directory, sorted, exclusions applied.
icm_top_entries() {
    [ -d "$1" ] || return 0
    ( cd "$1" && find . ! -name . -prune -print 2>/dev/null ) \
        | sed 's|^\./||' \
        | sort \
        | while IFS= read -r _e_n; do
              [ -n "$_e_n" ] || continue
              if icm_excluded "$_e_n"; then continue; fi
              printf '%s\n' "$_e_n"
          done
}

# Build the find(1) prune expression from excluded_globs.
icm_prune_expr() {
    _p_out=""
    for _p_g in $(icm_json_list "$ICM_DEFAULTS" excluded_globs); do
        _p_out="$_p_out -name '$_p_g' -prune -o"
    done
    printf '%s\n' "$_p_out"
}

# All files under a root, as paths relative to that root, exclusions applied.
icm_walk_files() {
    _f_root=$(icm_abspath "$1")
    [ -d "$_f_root" ] || return 0
    _f_pr=$(icm_prune_expr)
    eval "find \"\$_f_root\" $_f_pr -type f -print 2>/dev/null" \
        | awk -v p="$_f_root/" 'index($0, p) == 1 { print substr($0, length(p) + 1) }' \
        | sort
}

# Every markdown file under a root, relative paths.
icm_walk_md() {
    icm_walk_files "$1" | grep '\.md$' || true
}

# Every directory under a root, relative paths, exclusions applied.
icm_walk_dirs() {
    _d_root=$(icm_abspath "$1")
    [ -d "$_d_root" ] || return 0
    _d_pr=$(icm_prune_expr)
    eval "find \"\$_d_root\" $_d_pr -type d -print 2>/dev/null" \
        | awk -v p="$_d_root/" 'index($0, p) == 1 { print substr($0, length(p) + 1) }' \
        | sort
}

# ------------------------------------------------------------------ survey --
#
# The tree walk behind the TRANSFER story. It reports; it never writes and it
# never proposes a write. Depth is fixed at two: the target's own entries and
# one level of subfolders. Every verdict below is evidence, not a conclusion.
# A number in a folder name is a signal that a human still has to read.

# The directories the install manifest owns, one per line, plus the toolkit's
# own scratch space. Taken from the manifest so there is one list, not two.
icm_owned_dirs() {
    {
        icm_manifest | awk '{ p = index($2, "/"); if (p > 0) { print substr($2, 1, p - 1) } }'
        printf '.icm\n'
    } | sort -u
}

icm_is_owned_dir() {
    icm_owned_dirs | awk -v d="$1" '$0 == d { f = 1 } END { exit f ? 0 : 1 }'
}

# True when every direct file in a directory carries an extension listed under
# asset_extensions in icm.defaults.json. With no such key nothing is ever
# asset-only, because the list has exactly one home and this is not it.
icm_asset_only() {
    _ao_dir="$1"
    _ao_exts=$(icm_json_list "$ICM_DEFAULTS" asset_extensions)
    [ -n "$_ao_exts" ] || return 1
    _ao_seen=0
    for _ao_f in "$_ao_dir"/*; do
        [ -f "$_ao_f" ] || continue
        _ao_seen=1
        _ao_b=$(basename -- "$_ao_f")
        case "$_ao_b" in
            *.*) _ao_e=$(printf '%s' "${_ao_b##*.}" | tr 'A-Z' 'a-z') ;;
            *)   return 1 ;;
        esac
        _ao_hit=0
        for _ao_x in $_ao_exts; do
            [ "$_ao_e" = "$_ao_x" ] && { _ao_hit=1; break; }
        done
        [ "$_ao_hit" -eq 1 ] || return 1
    done
    [ "$_ao_seen" -eq 1 ]
}

# True when a directory carries a stage signal: a leading number in its name,
# or a child that looks like the place its work comes out.
icm_stage_signal() {
    _ss_dir="$1"
    _ss_base=$(basename -- "$_ss_dir")
    case "$_ss_base" in
        [0-9]*) return 0 ;;
    esac
    for _ss_c in output out final exports dist; do
        [ -d "$_ss_dir/$_ss_c" ] && return 0
    done
    return 1
}

# True when a directory is somebody else's dependency drop rather than work.
icm_vendor_drop() {
    for _vd_c in node_modules vendor venv .venv target; do
        [ -d "$1/$_vd_c" ] && return 0
    done
    return 1
}

# icm_survey_rows <target>
# One row per surveyed folder, tab separated:
#   <relpath>  <verdict>  <files>  <subfolders>  <stage-signal>  <asset-only>
icm_survey_rows() {
    _sr_root="$1"
    icm_tmp_init
    _sr_dirs="$ICM_TMPDIR/survey.dirs"
    : > "$_sr_dirs"
    icm_top_entries "$_sr_root" > "$ICM_TMPDIR/survey.top"
    while IFS= read -r _sr_e; do
        [ -n "$_sr_e" ] || continue
        [ -d "$_sr_root/$_sr_e" ] || continue
        if icm_is_owned_dir "$_sr_e"; then continue; fi
        printf '%s\n' "$_sr_e" >> "$_sr_dirs"
        icm_top_entries "$_sr_root/$_sr_e" > "$ICM_TMPDIR/survey.sub"
        while IFS= read -r _sr_s; do
            [ -n "$_sr_s" ] || continue
            [ -d "$_sr_root/$_sr_e/$_sr_s" ] || continue
            printf '%s/%s\n' "$_sr_e" "$_sr_s" >> "$_sr_dirs"
        done < "$ICM_TMPDIR/survey.sub"
    done < "$ICM_TMPDIR/survey.top"

    _sr_tab=$(printf '\t')
    while IFS= read -r _sr_d; do
        [ -n "$_sr_d" ] || continue
        _sr_p="$_sr_root/$_sr_d"
        _sr_nf=0
        _sr_nd=0
        icm_top_entries "$_sr_p" > "$ICM_TMPDIR/survey.entries"
        while IFS= read -r _sr_x; do
            [ -n "$_sr_x" ] || continue
            if [ -d "$_sr_p/$_sr_x" ]; then
                _sr_nd=$((_sr_nd + 1))
            else
                _sr_nf=$((_sr_nf + 1))
            fi
        done < "$ICM_TMPDIR/survey.entries"

        if icm_stage_signal "$_sr_p"; then _sr_sig=yes; else _sr_sig=no; fi
        if icm_asset_only "$_sr_p"; then _sr_ao=yes; else _sr_ao=no; fi

        if [ -f "$_sr_p/CONTEXT.md" ]; then
            _sr_v=has-card
        elif icm_vendor_drop "$_sr_p" || [ "$_sr_ao" = yes ] || [ "$_sr_nf" -lt 2 ]; then
            _sr_v=none
        elif [ "$_sr_sig" = yes ]; then
            _sr_v=staged
        else
            _sr_v=card
        fi

        printf '%s%s%s%s%s%s%s%s%s%s%s\n' \
            "$_sr_d" "$_sr_tab" "$_sr_v" "$_sr_tab" "$_sr_nf" "$_sr_tab" \
            "$_sr_nd" "$_sr_tab" "$_sr_sig" "$_sr_tab" "$_sr_ao"
    done < "$_sr_dirs"
}

# ----------------------------------------------------------------- counting --

# Character count. wc -c, the byte count: it is exact, locale independent, and
# it is what spec/budgets.md counts. wc -m is the permissive direction in a
# UTF-8 locale, and every generated IDENTITY.md carries multibyte box drawing.
icm_chars() {
    [ -f "$1" ] || { printf '0\n'; return 0; }
    wc -c < "$1" 2>/dev/null | awk '{ print $1 + 0 }'
}

icm_lines() {
    [ -f "$1" ] || { printf '0\n'; return 0; }
    wc -l < "$1" 2>/dev/null | awk '{ print $1 + 0 }'
}

# ----------------------------------------------------------------- markdown --

# Print the YAML frontmatter block (without the --- fences). Empty if none.
icm_fm_block() {
    awk '
        NR == 1 { if ($0 != "---") { exit 0 } inf = 1; next }
        inf && $0 == "---" { exit 0 }
        inf { print }
    ' "$1"
}

# icm_fm_get <file> <key> -> value with surrounding double quotes stripped
icm_fm_get() {
    awk -v key="$2" '
        NR == 1 { if ($0 != "---") { exit 0 } inf = 1; next }
        inf && $0 == "---" { exit 0 }
        inf {
            p = index($0, ":")
            if (p == 0) { next }
            k = substr($0, 1, p - 1)
            v = substr($0, p + 1)
            sub(/^[ \t]+/, "", k); sub(/[ \t]+$/, "", k)
            sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
            if (k == key) {
                if (length(v) > 1 && substr(v, 1, 1) == "\"" && substr(v, length(v), 1) == "\"") {
                    v = substr(v, 2, length(v) - 2)
                }
                print v
                exit 0
            }
        }
    ' "$1"
}

# Contents of the first fenced code block in a file.
icm_first_fence_block() {
    awk '
        f && /^ *```/ { exit }
        f { print }
        /^ *```/ && !f { f = 1 }
    ' "$1"
}

# Lines that still carry an unfilled placeholder in live prose, as
# "<line number>: <line>". A placeholder inside a code fence or inside
# backticks is a document quoting the syntax, not unfilled content, so it does
# not count. This is the single definition; icm-check and icm-apply share it.
icm_live_placeholders() {
    awk '
        /^ *```/ { inf = 1 - inf; next }
        /^ *~~~/ { inf = 1 - inf; next }
        inf == 1 { next }
        {
            line = $0
            out = ""
            while ((a = index(line, "`")) > 0) {
                out = out substr(line, 1, a - 1)
                rest = substr(line, a + 1)
                b = index(rest, "`")
                if (b == 0) { line = rest; break }
                line = substr(rest, b + 1)
            }
            out = out line
            if (index(out, "{{") > 0) { print FNR ": " $0 }
        }
    ' "$1"
}

# Count of backtick fence lines, then tilde fence lines, one per output line.
icm_fence_count() {
    awk '
        /^ {0,3}```/  { b++ }
        /^ {0,3}~~~/  { t++ }
        END { print b + 0; print t + 0 }
    ' "$1"
}

# ------------------------------------------------------------------ writing --

# The destination's permission bits as a four digit octal string, or "-" when
# there is nothing there. ls -l is the portable reader; its permission field is
# specified by POSIX, and stat is not on the toolkit's tool list.
icm_mode_of() {
    if [ ! -e "$1" ]; then
        printf -- '-\n'
        return 0
    fi
    ls -ld -- "$1" 2>/dev/null | awk '
        NR == 1 {
            p = substr($1, 2, 9)
            if (length(p) < 9) { print "-"; exit }
            u = 0; g = 0; o = 0; s = 0
            if (substr(p, 1, 1) == "r") { u += 4 }
            if (substr(p, 2, 1) == "w") { u += 2 }
            c = substr(p, 3, 1)
            if (c == "x") { u += 1 } else if (c == "s") { u += 1; s += 4 } else if (c == "S") { s += 4 }
            if (substr(p, 4, 1) == "r") { g += 4 }
            if (substr(p, 5, 1) == "w") { g += 2 }
            c = substr(p, 6, 1)
            if (c == "x") { g += 1 } else if (c == "s") { g += 1; s += 2 } else if (c == "S") { s += 2 }
            if (substr(p, 7, 1) == "r") { o += 4 }
            if (substr(p, 8, 1) == "w") { o += 2 }
            c = substr(p, 9, 1)
            if (c == "x") { o += 1 } else if (c == "t") { o += 1; s += 1 } else if (c == "T") { s += 1 }
            printf "%d%d%d%d\n", s, u, g, o
            exit
        }
        END { if (NR == 0) { print "-" } }
    '
}

# The hard link count of a path, or 0 when it cannot be read.
icm_nlink() {
    [ -e "$1" ] || { printf '0\n'; return 0; }
    ls -ld -- "$1" 2>/dev/null | awk 'NR == 1 { print $2 + 0; exit } END { if (NR == 0) print 0 }'
}

# Read stdin, write it to $1 through a temp file and a rename.
#
# The mode travels with the write. rename(2) only needs write permission on the
# directory, so without this a mode 600 file is silently widened to whatever the
# umask allows and a mode 444 file is rewritten without a word. $2, when given,
# is the mode to stamp on (four digit octal, as icm_mode_of prints it); with no
# $2 an existing destination's own mode is carried over.
icm_atomic_write() {
    _aw_dest="$1"
    _aw_mode="${2:-}"
    _aw_dir=$(dirname -- "$_aw_dest")
    mkdir -p "$_aw_dir"
    if [ -z "$_aw_mode" ] && [ -f "$_aw_dest" ] && [ ! -L "$_aw_dest" ]; then
        _aw_mode=$(icm_mode_of "$_aw_dest")
    fi
    _aw_tmp="$_aw_dest.icm-tmp.$$"
    cat > "$_aw_tmp"
    case "$_aw_mode" in
        ''|-) : ;;
        *) chmod "$_aw_mode" "$_aw_tmp" 2>/dev/null || true ;;
    esac
    mv -f "$_aw_tmp" "$_aw_dest"
}

# icm_block_state <file> <beginmark> <endmark> -> none | ok | malformed
#
# A managed block is exactly one begin marker followed by exactly one end
# marker, both outside any code fence. Anything else is malformed: a begin with
# no end, an end with no begin, a duplicate of either, or an end that comes
# first. icm_splice starts skipping at the begin marker and only stops at the
# end marker, so a missing end marker deletes the whole rest of the user's file
# and a lone end marker in prose is silently swallowed. Callers classify a
# malformed set as COLLIDE and never splice it.
icm_block_state() {
    [ -f "$1" ] || { printf 'none\n'; return 0; }
    awk -v bm="$2" -v em="$3" '
        /^ {0,3}```/ { fence = 1 - fence; next }
        /^ {0,3}~~~/ { fence = 1 - fence; next }
        fence == 1 { next }
        $0 == bm { nb++; if (first == "") { first = "b" } }
        $0 == em { ne++; if (first == "") { first = "e" } }
        END {
            if (nb == 0 && ne == 0) { print "none"; exit }
            if (nb == 1 && ne == 1 && first == "b") { print "ok"; exit }
            print "malformed"
        }
    ' "$1"
}

# icm_block_flaw <file> <beginmark> <endmark> -> a short reason for the report
icm_block_flaw() {
    awk -v bm="$2" -v em="$3" '
        /^ {0,3}```/ { fence = 1 - fence; next }
        /^ {0,3}~~~/ { fence = 1 - fence; next }
        fence == 1 { next }
        $0 == bm { nb++; if (first == "") { first = "b" } }
        $0 == em { ne++; if (first == "") { first = "e" } }
        END {
            if (nb > 0 && ne == 0) { print "no end marker" }
            else if (ne > 0 && nb == 0) { print "no begin marker" }
            else if (nb > 1 || ne > 1) { print "duplicate markers" }
            else if (first == "e") { print "end marker before begin marker" }
            else { print "markers not well formed" }
        }
    ' "$1"
}

# icm_splice <file> <blockfile> <beginmark> <endmark>
# Emits the file with the delimited block replaced, or appended when the
# delimiters are absent. Only the delimited region is ever rewritten. Refuses a
# marker set that is not exactly one begin then one end, so it can never eat the
# tail of a file it was asked to edit.
icm_splice() {
    case "$(icm_block_state "$1" "$3" "$4")" in
        malformed) icm_die "refusing to splice $1: $(icm_block_flaw "$1" "$3" "$4")" ;;
    esac
    icm_splice_unchecked "$@"
}

icm_splice_unchecked() {
    awk -v blk="$2" -v bm="$3" -v em="$4" '
        BEGIN { while ((getline l < blk) > 0) { B = B l "\n" } }
        $0 == bm { printf "%s", B; skip = 1; found = 1; next }
        $0 == em { skip = 0; next }
        skip != 1 { print; last = $0 }
        END {
            if (!found) {
                if (NR > 0 && last != "") { print "" }
                printf "%s", B
            }
        }
    ' "$1"
}

# ------------------------------------------------------------------ hashing --

icm_sha_init() {
    if [ -n "$ICM_SHA_MODE" ]; then
        return 0
    fi
    if command -v shasum >/dev/null 2>&1; then
        ICM_SHA_MODE="shasum"
    elif command -v sha256sum >/dev/null 2>&1; then
        ICM_SHA_MODE="sha256sum"
    else
        ICM_SHA_MODE="degraded"
    fi
}

icm_sha_mode_note() {
    icm_sha_init
    if [ "$ICM_SHA_MODE" = "degraded" ]; then
        printf 'no shasum and no sha256sum on PATH; file identity degraded to size+mtime\n'
    fi
}

# icm_sha <file> -> a stable fingerprint string
icm_sha() {
    icm_sha_init
    if [ ! -f "$1" ]; then
        printf 'absent\n'
        return 0
    fi
    case "$ICM_SHA_MODE" in
        shasum)    shasum -a 256 "$1" | awk '{ print $1 }' ;;
        sha256sum) sha256sum "$1" | awk '{ print $1 }' ;;
        *)
            _h_sz=$(wc -c < "$1" | awk '{ print $1 + 0 }')
            _h_mt=$(ls -ld -- "$1" 2>/dev/null | awk '{ print $6 "-" $7 "-" $8 }')
            printf 'nohash:%s:%s\n' "$_h_sz" "$_h_mt"
            ;;
    esac
}

# True when two files exist and are byte identical.
icm_same() {
    [ -f "$1" ] || return 1
    [ -f "$2" ] || return 1
    cmp -s "$1" "$2" 2>/dev/null && return 0
    diff -q "$1" "$2" >/dev/null 2>&1
}

# ---------------------------------------------------------------------- init --

icm_defaults_for() {
    if [ -f "$1/icm.defaults.json" ]; then
        icm_abspath "$1/icm.defaults.json"
    elif [ -f "$ICM_HOME/icm.defaults.json" ]; then
        icm_abspath "$ICM_HOME/icm.defaults.json"
    else
        icm_die "icm.defaults.json not found in $1 or $ICM_HOME"
    fi
}

# icm_init <target-dir>
icm_init() {
    icm_tmp_init
    ICM_DEFAULTS=$(icm_defaults_for "$1")
    # Flatten once, in this shell, so every later lookup (including the ones
    # that run inside subshells and pipelines) hits the cache.
    icm_json_load "$ICM_DEFAULTS"
    ICM_TOOLKIT=$(icm_json_get "$ICM_DEFAULTS" toolkit 2>/dev/null) || ICM_TOOLKIT="Momentrix ICM KAP Toolkit"
    ICM_VERSION=$(icm_json_get "$ICM_DEFAULTS" version 2>/dev/null) || ICM_VERSION="0"
    icm_sha_init
}

# ------------------------------------------------------------------- the map --

# The install manifest: "<role> <relative path>", one per line.
# role create -> a new file the toolkit owns
# role adopt  -> a file that already serves the role; only the icm block is ours
icm_manifest() {
    # icm_manifest [archetype]
    # No argument: every managed path, whatever the archetype. Callers that ask
    # "is this path ours" need the full set, so that stays the default.
    # With an argument (quick|full|wiki): only the rows that archetype installs.
    _mf_want=${1:-}
    case "$_mf_want" in
        ''|quick|full|wiki) ;;
        *) icm_die "unknown archetype: $_mf_want (want quick, full or wiki)" ;;
    esac
    cat <<'ICM_MANIFEST' | while read -r _mf_role _mf_path _mf_tier; do
create IDENTITY.md quick
create CONTEXT.md quick
create _config/conventions.md quick
create _config/glossary.md quick
create _config/voice.md quick
create _config/style.md quick
create _log/LOOP-LEDGER.md quick
create _log/FORGE-PROPOSALS.md quick
create output/CONTEXT.md full
create _config/grounding.md wiki
create raw/CONTEXT.md wiki
create wiki/index.md wiki
create wiki/log.md wiki
adopt CLAUDE.md quick
adopt .gitignore quick
ICM_MANIFEST
        [ -n "$_mf_role" ] || continue
        case "$_mf_want" in
            '')     printf '%s %s\n' "$_mf_role" "$_mf_path" ;;
            quick)  [ "$_mf_tier" = quick ] && printf '%s %s\n' "$_mf_role" "$_mf_path" ;;
            full)   [ "$_mf_tier" != wiki ] && printf '%s %s\n' "$_mf_role" "$_mf_path" ;;
            wiki)   printf '%s %s\n' "$_mf_role" "$_mf_path" ;;
        esac
    done
    return 0
}

icm_role_of() {
    icm_manifest | awk -v p="$1" '$2 == p { print $1; exit }'
}

icm_manifest_has() {
    # icm_manifest_has <relpath>
    # 0 when the archetype in ICM_ARCHETYPE installs that path, 1 when it does not.
    # This is what keeps the generated root CONTEXT.md closed: a routing row is
    # only written when its destination is a row in the same archetype's manifest.
    icm_manifest "${ICM_ARCHETYPE:-quick}" \
        | awk -v p="$1" '$2 == p { hit = 1 } END { exit(hit ? 0 : 1) }'
}

icm_route_row() {
    # icm_route_row <relpath> <what you are doing> <load first cell>
    # Prints nothing at all when this archetype does not install <relpath>.
    icm_manifest_has "$1" || return 0
    printf '| %s | `%s` | %s |\n' "$2" "$1" "$3"
}

icm_rulebook_row() {
    # icm_rulebook_row <relpath> <what it binds>
    icm_manifest_has "$1" || return 0
    printf '| `%s` | %s |\n' "$1" "$2"
}

# ---------------------------------------------------------------------- tree --

icm_tree_note() {
    case "$1" in
        IDENTITY.md) printf '# layer 0 - you are here\n' ;;
        CONTEXT.md)  printf '# layer 1 - routing\n' ;;
        CLAUDE.md)   printf '# adapter - aliases IDENTITY.md\n' ;;
        _config)     printf '# layer 3 - rule books\n' ;;
        raw)         printf '# layer 4a - immutable sources\n' ;;
        wiki)        printf '# layer 4b - compiled knowledge\n' ;;
        output)      printf '# layer 4b - what we shipped\n' ;;
        _log)        printf '# ledger and forge proposals\n' ;;
        *)           printf '\n' ;;
    esac
}

icm_tree_line() {
    printf '%s%-24s%s\n' "$1" "$2" "$3"
}

# The map has to describe the workspace apply is building, not the empty
# folder it starts from. Expected = what is on disk, plus what the manifest
# installs. Otherwise IDENTITY.md is written before its own folders exist and
# icm-check --drift fails on the very files apply just created.
# icm_detect_archetype <target> -> quick | full | wiki
# The checker is handed a finished workspace with no plan, so it reads the
# shape off the disk. wiki/ implies the Karpathy layers, output/ implies a
# staged pipeline, neither implies the quick three-layer install.
icm_detect_archetype() {
    if [ -d "$1/wiki" ] || [ -d "$1/raw" ]; then
        printf 'wiki\n'
    elif [ -d "$1/output" ]; then
        printf 'full\n'
    else
        printf 'quick\n'
    fi
}

icm_expected_top() {
    {
        icm_top_entries "$1"
        icm_manifest "${ICM_ARCHETYPE:-quick}" | awk '{ p = index($2, "/"); if (p > 0) { print substr($2, 1, p - 1) } else { print $2 } }'
    } | sort -u | grep -v '^$' || true
}

icm_expected_sub() {
    {
        icm_top_entries "$1/$2"
        icm_manifest | awk -v d="$2" '
            index($2, d "/") == 1 {
                r = substr($2, length(d) + 2)
                p = index(r, "/")
                if (p > 0) { print substr(r, 1, p - 1) } else { print r }
            }'
    } | sort -u | grep -v '^$' || true
}

icm_is_expected_dir() {
    if [ -d "$1/$2" ]; then
        return 0
    fi
    icm_manifest | awk -v d="$2" 'index($2, d "/") == 1 { f = 1 } END { exit f ? 0 : 1 }'
}

icm_tree_raw() {
    _t_root=$(icm_abspath "$1")
    icm_tmp_init
    printf '%s/\n' "$(basename "$_t_root")"
    _t_top="$ICM_TMPDIR/tree.top"
    icm_expected_top "$_t_root" > "$_t_top"
    _t_n=$(awk 'END { print NR + 0 }' "$_t_top")
    _t_i=0
    while IFS= read -r _t_e; do
        [ -n "$_t_e" ] || continue
        _t_i=$((_t_i + 1))
        if [ "$_t_i" -eq "$_t_n" ]; then
            _t_b='└── '; _t_lead='    '
        else
            _t_b='├── '; _t_lead='│   '
        fi
        if icm_is_expected_dir "$_t_root" "$_t_e"; then
            icm_tree_line "$_t_b" "$_t_e/" "$(icm_tree_note "$_t_e")"
            case "$_t_e" in
                _config|_log|wiki|raw|output|skills|scripts|spec|templates)
                    _t_sub="$ICM_TMPDIR/tree.sub"
                    icm_expected_sub "$_t_root" "$_t_e" > "$_t_sub"
                    _s_n=$(awk 'END { print NR + 0 }' "$_t_sub")
                    _s_i=0
                    while IFS= read -r _s_e; do
                        [ -n "$_s_e" ] || continue
                        _s_i=$((_s_i + 1))
                        if [ "$_s_i" -eq "$_s_n" ]; then _s_b='└── '; else _s_b='├── '; fi
                        if [ -d "$_t_root/$_t_e/$_s_e" ]; then
                            icm_tree_line "$_t_lead$_s_b" "$_s_e/" ""
                        else
                            icm_tree_line "$_t_lead$_s_b" "$_s_e" ""
                        fi
                    done < "$_t_sub"
                    rm -f "$_t_sub"
                    ;;
            esac
        else
            icm_tree_line "$_t_b" "$_t_e" "$(icm_tree_note "$_t_e")"
        fi
    done < "$_t_top"
    rm -f "$_t_top"
}

icm_tree() {
    icm_tree_raw "$1" | sed 's/  *$//'
}

# --------------------------------------------------- why there is no ---------
# --------------------------------------------------- template layer ----------
#
# There is no template lookup, no expansion pass and no precedence contest, and
# putting one back is a defect, not a feature.
#
# Every byte any script writes comes from an icm_body_* function below. One
# renderer, one body per managed path, both compiled into this file. Nothing can
# beat a body by being empty, truncated, unreadable or half written, because
# nothing else is consulted at all.
#
# The interview material is a different artifact with a different consumer: a
# skill fills it in conversation with a human and writes the result itself. It
# carries double-brace onboarding placeholders, single-brace fill instructions
# and leading HTML authoring comments, none of which is safe for a script to
# stamp into a live workspace. Its directory name is stated in README.md and
# IDENTITY.md and is deliberately absent from this file: a test asserts that no
# file under scripts/ names it, and that assertion is what stops the second
# source of truth from growing back.

# --------------------------------------------------------- built-in bodies ---

# --- manifest-aware row helpers ----------------------------------------------
# A generated file must never route to a path this archetype does not install.
# These three are the guard: every row asks the manifest first.

# icm_manifest_has <relpath> -> 0 when the current archetype installs it
icm_manifest_has() {
    icm_manifest "${ICM_ARCHETYPE:-quick}" | awk -v p="$1" '$2 == p { f = 1 } END { exit f ? 0 : 1 }'
}

# icm_route_row <relpath> <what you are doing> <load first>
icm_route_row() {
    icm_manifest_has "$1" || return 0
    printf '| %s | `%s` | %s |\n' "$2" "$1" "$3"
}

# icm_rulebook_row <relpath> <what it binds>
icm_rulebook_row() {
    icm_manifest_has "$1" || return 0
    printf '| `%s` | %s |\n' "$1" "$2"
}

icm_body_identity() {
    _bi_target=$(icm_abspath "$1")
    _bi_arch=${ICM_ARCHETYPE:-quick}
    printf '%s\n\n' "# $(basename "$_bi_target") - Identity"
    cat <<'ICM_EOF'
Layer 0. You are here. Read this before anything else, every session.

## Workspace Map

ICM_EOF
    printf '```\n'
    icm_tree "$_bi_target"
    printf '```\n\n'
    cat <<'ICM_EOF'
## Layers

| Layer | Where | Question it answers |
|---|---|---|
| 0 | `IDENTITY.md` | Where am I? |
| 1 | `CONTEXT.md` | Where do I go? |
| 2 | a folder `CONTEXT.md`, the job card | What do I do here? |
| 3 | `_config/` rule books | What rules apply? |
ICM_EOF
    case "$_bi_arch" in
        wiki) printf '| 4a | `raw/` | What is true? |\n'
              printf '| 4b | `wiki/` and `output/` | What do we know, what did we make? |\n' ;;
        full) printf '| 4b | `output/` | What did we make? |\n' ;;
    esac
    cat <<'ICM_EOF'

Layers 1 to 3 recurse. A folder that holds folders repeats the same pattern inside.

## Rules

- Read this file, then `CONTEXT.md`, then the job card for the folder you are working in. Nothing else loads by default.
- `_config/` holds rule books. They are not skills and they are not documentation. A rule book binds.
ICM_EOF
    if [ "$_bi_arch" = wiki ]; then
        cat <<'ICM_EOF'
- Every load-bearing fact in `wiki/` exists word for word in a `raw/` file that the article links to. No link, no fact.
- `raw/` is immutable. You add to it. You never edit it.
ICM_EOF
    fi
    cat <<'ICM_EOF'
- Nothing overwrites a file you did not write. Collisions land in `.icm/proposed/`.
- Every task ends with the Session Close in `CONTEXT.md`: miss lines, use lines, the placement question, the task line, all appended to `_log/LOOP-LEDGER.md`. Never rewrite history there.
- An agent proposes a rule change, it never makes one. Proposals go to `_log/FORGE-PROPOSALS.md`.
- When the map above stops matching the disk, the map is wrong. Fix the map.
ICM_EOF
    if [ "$_bi_arch" != wiki ]; then
        printf -- '- This workspace is the `%s` archetype. Add `raw/` and `wiki/` by re-planning with `--archetype wiki`.\n' "$_bi_arch"
    fi
}

icm_body_context_root() {
    _bc_target=$(icm_abspath "$1")
    printf '%s\n\n' "# $(basename "$_bc_target") - Routing"
    cat <<'ICM_EOF'
Layer 1. You have read `IDENTITY.md`. Now pick the job.

## Routing

| What you are doing | Go to | Load first |
|---|---|---|
ICM_EOF
    if icm_manifest_has _config/grounding.md; then
        _bc_ground='`_config/grounding.md`'
    else
        _bc_ground='-'
    fi
    icm_route_row raw/CONTEXT.md "Filing an incoming document" "$_bc_ground"
    icm_route_row wiki/index.md "Writing or updating a wiki article" "$_bc_ground"
    icm_route_row output/CONTEXT.md "Producing something a human reads" '`_config/voice.md`'
    icm_route_row _config/conventions.md "Checking a naming or folder rule" -
    icm_route_row _config/glossary.md "Checking what a word means here" -
    icm_route_row _config/voice.md "Checking how it is allowed to sound" -
    icm_route_row _config/style.md "Checking how a page is formatted" -
    icm_route_row _log/LOOP-LEDGER.md "Closing a task" -
    icm_route_row _log/FORGE-PROPOSALS.md "Proposing a rule change" -
    cat <<'ICM_EOF'

If the job is not in the table, the table is incomplete. Say so before you improvise.

## Session Start

1. Read `IDENTITY.md`. That is the map.
2. Read this file. Pick the row that matches the job.
3. Read the job card the row points to, and the rule book in the Load first column.
4. Do the work. Nothing else loads unless the job card says to load it.
5. Run the Session Close below before your last reply. It is part of the task, not an afterthought.

ICM_EOF
    icm_body_session_close
    cat <<'ICM_EOF'

## Rule Books

Rule books live in `_config/`. They bind. They are not suggestions and they are not skills.

| Rule book | Binds |
|---|---|
ICM_EOF
    icm_rulebook_row _config/conventions.md "Naming, folder shapes, layer discipline"
    icm_rulebook_row _config/glossary.md "This project's terms, and the one meaning each carries"
    icm_rulebook_row _config/voice.md "Audience, tone, vocabulary, evidence standard"
    icm_rulebook_row _config/style.md "Formatting mechanics: headings, tables, links, dates, numbers"
    icm_rulebook_row _config/grounding.md "Anything written into \`wiki/\`"
    cat <<'ICM_EOF'

Only a human edits a rule book. An agent proposes a change by appending to `_log/FORGE-PROPOSALS.md`.
ICM_EOF
}

# The Session Close is the write back obligation: the one block that makes the
# loop recursive. It lives in layer 1 because layer 1 is loaded on every run by
# every harness, whichever alias points at it. icm-loop.sh --block prints the
# same body between markers for hosts that are not ICM workspaces. One body,
# two consumers, no copy.
icm_body_session_close() {
    cat <<'ICM_EOF'
## Session Close

Before your last reply of any task, do these four, in order. Skipping one is itself a miss, sev 2. Log it.

1. **Miss check.** Did you ask for something already available, get corrected by hand, skip a step in your instructions, ship output that needed rework, or run when you should not have (or not run when you should)? Each one is one miss line in `_log/LOOP-LEDGER.md`, shape in that file. Name the rule book, job card or skill at fault, never a person. Name the mechanism, not the feeling. Grep first: a fault already open on that path is not logged twice. A fault that returns after a patch is logged with `RECURRENCE:` in front. Log it even when you recovered. No misses, write nothing.
2. **Use line.** One per skill or job card this task ran under.
3. **Placement question.** Did this task produce a procedure, rule or fact that nothing on disk holds? Do not create it. Append a proposal of kind `new` to `_log/FORGE-PROPOSALS.md` at the path `_config/conventions.md` gives it under Where A Learned Thing Lives, and stop. A human naming the id is what creates it.
4. **Task line.** Close against the job card, then append the task line and any call lines.

Sub agents carry these four steps too. One that cannot write files reports its lines in its final message and the caller appends them. One ledger per workspace, never one per agent.
ICM_EOF
}

icm_body_raw_context() {
    cat <<'ICM_EOF'
# raw - Job Card

Layer 2. The evidence floor.

## Purpose

Hold every incoming document exactly as it arrived. If a fact is not in this folder, it is not a fact.

## Inputs

| Input | Where it comes from |
|---|---|
| A document, transcript, export or page capture | You, or a tool run |
| The date it was collected | The day you filed it |

## Process

1. Save the document under this folder, named by date first, then a short slug.
2. Put a header on it: what it is, where it came from, the date collected.
3. Paste the body word for word. Do not summarise, tidy, translate or truncate.
4. Append an ingest line to `wiki/log.md`.
5. If it carried nothing usable, still file it, and log the ingest as no material.

## Outputs

- One immutable file per source.
- One ingest line in `wiki/log.md`.

## Routing

| Next | Go to |
|---|---|
| Turn this evidence into knowledge | `wiki/index.md` |
| Check the grounding rule | `_config/grounding.md` |
| Back to the routing table | `../CONTEXT.md` |
ICM_EOF
}

icm_body_output_context() {
    if icm_manifest_has wiki/index.md; then
        _bo_facts='`wiki/` articles, never memory'
        _bo_pull='Pull the facts from `wiki/`. If a fact is not there, it does not go in.'
    else
        _bo_facts='whatever the brief cites'
        _bo_pull='Gather the facts from what the brief cites. Do not write a number you cannot point at.'
    fi
    cat <<ICM_EOF
# output - Job Card

Layer 2. What we shipped.

## Purpose

Hold every deliverable a human or a customer receives. Nothing here is evidence and nothing here is knowledge. It is the product.

## Inputs

| Input | Where it comes from |
|---|---|
| The brief | The person who asked |
| The facts | $_bo_facts |
| The house style | \`_config/voice.md\` and \`_config/style.md\` |

## Process

1. Read the brief. Write down what done looks like before you start.
2. $_bo_pull
3. Draft it. Apply \`_config/voice.md\` and \`_config/style.md\` in full.
4. Reread against the brief. Cut what the brief did not ask for.
5. Save it here. Append the closing line to \`_log/LOOP-LEDGER.md\`.

## Outputs

- One file per deliverable.
- One ledger line recording it.

## Routing

| Next | Go to |
|---|---|
ICM_EOF
    icm_route_row wiki/index.md "Find a fact" '-'
    cat <<'ICM_EOF'
| Check the house style | `_config/voice.md` |
| Back to the routing table | `../CONTEXT.md` |
ICM_EOF
}

icm_body_conventions() {
    cat <<'ICM_EOF'
# Rule Book - Conventions

Binds: naming, folder shapes and layer discipline. This rule book is not a skill and not documentation. It binds.

## Quick Reference

| Thing | Convention |
|---|---|
| Folders and files | lowercase-with-hyphens, no spaces |
| Stage folders | zero-padded number prefix, `01-`, `02-`, `03-` |
| Output artifacts | topic slug first, then artifact type |
| Raw files | `YYYY-MM-DD-descriptive-slug.md` |
| Routing files | `CONTEXT.md`, one per folder that needs routing |
| Rule books | `_config/*.md`, reference only |
| Never edited | anything under `raw/` |

## Layer Discipline

Layers 1 to 3 recurse. A folder that holds sub-areas repeats the same shape inside itself: its own `CONTEXT.md`, and its own `_config/` only if it has rules of its own. A folder that does real work has a job card. A folder that only holds files does not need one.

## File Shapes

Each file type has one shape and it does not drift.

- Layer 0 `IDENTITY.md`: what this workspace is, Workspace Map, Rules.
- Layer 1 root `CONTEXT.md`: Routing, Session Start, Rule Books.
- Layer 2 job card: Purpose, Inputs, Process, Outputs, Routing. Nothing else.
- Layer 3 rule book: this shape. Quick Reference first, detail after.

Required sections and size ceilings live in `icm.defaults.json`, and the skip list lives in the spec. Do not restate either as a literal here. Cite the file, so there is one place to change it.

## One Home Per Fact

Every fact has exactly one home. Other files link to it. If the same sentence is authoritative in two places, one of them becomes a pointer. Search for a phrase: if it appears twice and both copies claim to be right, that is the bug.

## Where A Learned Thing Lives

A task teaches something. The kind of thing decides the layer, and the layer decides the path. Nothing is created at close: the Session Close writes a proposal naming this path, and a human creates it.

| What was learned | Kind | Lives at |
|---|---|---|
| A rule, a do or a never | Rule book | `_config/<book>.md`, the existing book that is nearest in subject. A new book only when none fits |
| How this folder does its job | Job card | that folder's `CONTEXT.md`, its Process section |
| A procedure invoked by name, reused across folders or workspaces | Skill | `skills/<name>/SKILL.md` in the harness that runs it |
| A fact about the world | Source and article | `raw/` first, then `wiki/`. Never a rule book |
| A fact about this workspace | Map or route | `IDENTITY.md` or the routing `CONTEXT.md` it belongs to |

Depth: the lowest folder that covers every place the thing applies. Two sibling folders both need it, it moves up one level. Never sideways.

## When a rule is wrong

Append the case to `_log/FORGE-PROPOSALS.md`. Do not edit this file.
ICM_EOF
}

icm_body_glossary() {
    cat <<'ICM_EOF'
# Rule Book - Glossary

Binds: what a word means here. One term, one meaning. This rule book is not a skill and not documentation. It binds.

## Workspace Vocabulary

These are fixed. They mean the same thing in every ICM workspace and no project redefines them.

| Term | Means |
|---|---|
| rule book | a file in `_config/`. Reference material: what is true and what is allowed. Never called a skill. |
| skill | only a `skills/<name>/SKILL.md`. Procedure a model runs. |
| job card | a folder `CONTEXT.md` at layer 2. Purpose, Inputs, Process, Outputs, Routing. |
| layer | one of the numbered ICM levels, 0 through 4b. |
| raw | layer 4a. Immutable source material. Never edited, never rewritten. |
| wiki | layer 4b. Compiled articles, each grounded in raw. |
| load-bearing fact | a number, a date or a quote. The kind of claim that must exist word for word in raw. |
| ledger | `_log/LOOP-LEDGER.md`. Append only, one line per closed task. |
| forge | the loop that proposes rule book changes. It proposes, it never edits. |

## Domain Terms

This project's own vocabulary. One row per term an outsider would get wrong. Add a row the first time a term causes a misunderstanding, not before. If a term needs a paragraph, it is not a glossary entry: give it a file and link to it from the Means column.

| Term | Means | Source |
|---|---|---|

No domain terms recorded yet.

## Banned Synonyms

Pairs where two words are used for one thing. Pick the survivor and say so.

| Do not write | Write instead | Why |
|---|---|---|

No banned synonyms recorded yet.

## When a rule is wrong

Append the case to `_log/FORGE-PROPOSALS.md`. Do not edit this file.
ICM_EOF
}

icm_body_voice() {
    cat <<'ICM_EOF'
# Rule Book - Voice

Binds: anything a human reads. What the writing sounds like and what it is allowed to claim. Formatting mechanics live in `_config/style.md`. This rule book is not a skill and not documentation. It binds.

## Quick Reference

| Question | Answer |
|---|---|
| Person | second person. Say "you", not "the user" |
| Sentence length | short declaratives, one idea each |
| Evidence standard | every number, date and quote traces to a linked `raw/` file |

## Voice

1. Plain, short declaratives. One idea per sentence.
2. Second person. Say "you", not "the user".
3. Say the thing, then stop. No wind-up, no summary of what you just said.
4. Lowercase folder names, always, including at the start of a sentence.
5. No hedging where you have evidence. No confidence where you do not.

## Honesty

6. Never state a number you did not read in a source. Cite where it came from.
7. Never describe a file you have not opened.
8. When you do not know, write that you do not know, and write what would settle it.

## Hard Constraints

These are not preferences. A draft that breaks one gets revised before it ships.

- No claim without a source. If it cannot be traced to a `raw/` file, it does not go in.
- No invented numbers, prices, dates or customer quotes. A missing number is reported as missing.
- Nothing padded. If a sentence can be deleted without losing a fact, delete it.

## Sounds Right, Sounds Wrong

Examples beat descriptions. A model can pattern-match a sentence, it has to interpret an adjective. Every time a draft comes back wrong, add the pair here, rather than adding another adjective above.

No pairs recorded yet.

## When a rule is wrong

Append the case to `_log/FORGE-PROPOSALS.md`. Do not edit this file.
ICM_EOF
}

icm_body_style() {
    cat <<'ICM_EOF'
# Rule Book - Style

Binds: how a page is assembled. Headings, tables, links, dates, numbers, fences. What the writing sounds like lives in `_config/voice.md`. This rule book is not a skill and not documentation. It binds.

## Quick Reference

| Element | Rule |
|---|---|
| Headings | `##` for sections, `###` sparingly, never skip a level |
| Tables | header row plus separator row, pipes at both ends, no blank cells |
| Links | relative. Same folder: `file.md`. Sibling folder: `../other/file.md` |
| Dates | ISO, `YYYY-MM-DD`, always |
| Numbers | as written in the source, units attached, no rounding without saying so |
| Emphasis | bold for the one word that carries the row, italics almost never |
| Lists | hyphen bullets, numbers only when order matters |

## Structure

1. The first line says what the document is. Not why it matters, what it is.
2. Headings are nouns or verbs, never questions.
3. A table beats a list when there are two columns of information. A list beats a paragraph when there are three or more items.
4. Every path is written in backticks and points at something that exists.
5. Fenced code blocks open and close. An unbalanced fence eats the rest of the file.

## Code Fences

Three backticks for a normal block. Name the language when it is code. A block that itself contains a fenced block uses four backticks on the outside and three on the inside, otherwise the inner fence closes the outer block early and everything after it renders as prose. Count the fence lines before saving. An odd count means one is unclosed.

## Tables Over Prose

If a paragraph is really three parallel facts, make it a table. Routing, inputs, outputs, terms and rules are all tables. Prose is for the sentence that explains why the table looks like that.

## When a rule is wrong

Append the case to `_log/FORGE-PROPOSALS.md`. Do not edit this file.
ICM_EOF
}

icm_body_grounding() {
    cat <<'ICM_EOF'
# Rule Book - Grounding

Binds: anything written into `wiki/`. This rule book is not a skill and not documentation. It binds.

## The invariant

Every load-bearing fact in a wiki article, meaning every number, every date and every quote, exists word for word in a `raw/` file that the article links to.

## The rules

1. **Link before you write.** Locate the sourced line first, then write the sentence around it. Never write the sentence and go hunting for evidence afterwards.
2. **Every article carries a Raw field.** It lists the raw files the article stands on. An article with no Raw field is not an article, it is a draft.
3. **Raw links point inside `raw/`.** Evidence that lives anywhere else is not evidence.
4. **Quote or derive, never blend.** A quote is word for word inside quote marks. A derived number says what it was derived from.
5. **Disagreement is recorded, not resolved.** When two sources conflict, both get cited and the article is marked as disputed.
6. **No fact without a date.** Undated claims rot silently.
7. **`raw/` is immutable.** A correction is a new raw file plus a new ingest line, never an edit.

## Article shape

Each article opens with a metadata block before the first section: what it covers, the date it was updated, and a Raw field listing the `raw/` files it stands on. The body follows, and everything load-bearing in it traces to one of those files. The article closes with what is still unknown, named as unknown rather than left out.

## What enforces this

- Write time: this rule book, applied by whoever is writing.
- Check time: the toolkit's evidence check when python3 is available, which reads each article's Raw links and looks for each literal in them. It reports, it never fixes.
- Nothing auto-corrects a fact. A fact mismatch is a mechanical report for a human.

## When a rule is wrong

Append the case to `_log/FORGE-PROPOSALS.md`. Do not edit this file.
ICM_EOF
}

icm_body_wiki_index() {
    cat <<'ICM_EOF'
# Knowledge Index

Layer 4b. One row per compiled article. If an article is not in this table, it does not exist.

| Article | Summary | Updated |
|---|---|---|

No articles yet. The first row lands the day the first file in `raw/` gets compiled.

## How a row gets here

1. A document is filed in `raw/` and logged in `wiki/log.md`.
2. The article is written against that document under the grounding rule.
3. The row is added here on the same pass. An article with no row is invisible, and an invisible article is a lie by omission.

## Article shape

Each article opens with a metadata block: what it covers, the date it was updated, and a Raw field listing the `raw/` files it stands on. Everything load-bearing in the body traces to one of those files.
ICM_EOF
}

icm_body_wiki_log() {
    cat <<'ICM_EOF'
# Wiki Log

Layer 4b. Every ingest, query and lint against `wiki/`, in the order it happened.

## Format

One entry per event, opening with a heading of the shape `[YYYY-MM-DD] action | subject`. The actions are ingest, query and lint. An ingest entry records Disposition and Raw. A cascade update is an `- Updated:` sub-item under the entry that caused it.

## Entries

Append only. Never rewrite an entry. A correction is a new entry.

No entries yet.
ICM_EOF
}

icm_body_ledger() {
    cat <<'ICM_EOF'
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
ICM_EOF
}

icm_body_forge_proposals() {
    cat <<'ICM_EOF'
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
ICM_EOF
}

icm_body_claude_block() {
    cat <<ICM_EOF
$ICM_BEGIN
<!-- Managed by the $ICM_TOOLKIT. Edit IDENTITY.md, not this block. -->
@IDENTITY.md
@CONTEXT.md

Read IDENTITY.md first, then CONTEXT.md, then the job card in the folder you are working in. Nothing else loads by default. Before your last reply, run the Session Close in CONTEXT.md.
$ICM_END
ICM_EOF
}

icm_body_gitignore_block() {
    cat <<ICM_EOF
# $ICM_BEGIN
# $ICM_TOOLKIT - plan, backups and collision proposals stay out of git
.icm/
# $ICM_END
ICM_EOF
}

# ------------------------------------------------------------- render layer --

# icm_sections_key <relpath> -> the icm.defaults.json required_sections key that
# governs that path, or nothing when the path carries no section contract.
icm_sections_key() {
    case "$1" in
        CLAUDE.md|.gitignore) : ;;
        IDENTITY.md)          printf 'IDENTITY.md\n' ;;
        CONTEXT.md)           printf 'CONTEXT.root.md\n' ;;
        */CONTEXT.md)         printf 'CONTEXT.stage.md\n' ;;
        *)                    printf '%s\n' "$1" ;;
    esac
}

# icm_render_verify <relpath> <rendered file>
#
# The gate that makes a silent hole impossible. A rendered body that is empty,
# that still carries a double-brace placeholder, or that is missing a section
# icm.defaults.json requires for its path, is a defect in this file. It is
# refused loudly, by name, and nothing is written to the target.
icm_render_verify() {
    _rv_rp="$1"
    _rv_f="$2"
    if [ ! -s "$_rv_f" ]; then
        icm_die "the built-in body for $_rv_rp rendered empty. nothing was written. this is a defect in scripts/icm_lib.sh, not in your project"
    fi
    if icm_live_placeholders "$_rv_f" | grep -q .; then
        _rv_hit=$(icm_live_placeholders "$_rv_f" | head -n 1)
        icm_die "the built-in body for $_rv_rp still carries an unfilled placeholder at line $_rv_hit. nothing was written"
    fi
    _rv_key=$(icm_sections_key "$_rv_rp")
    [ -n "$_rv_key" ] || return 0
    _rv_def="$ICM_DEFAULTS"
    [ -n "$_rv_def" ] || _rv_def=$(icm_defaults_for "$ICM_HOME")
    _rv_secs="$ICM_TMPDIR/render.secs"
    icm_json_list "$_rv_def" "required_sections.$_rv_key" > "$_rv_secs"
    while IFS= read -r _rv_sec; do
        [ -n "$_rv_sec" ] || continue
        awk -v s="$_rv_sec" 'index($0, s) == 1 { f = 1 } END { exit f ? 0 : 1 }' "$_rv_f" || {
            rm -f "$_rv_secs"
            icm_die "the built-in body for $_rv_rp is missing a required section: $_rv_sec (required_sections in icm.defaults.json). nothing was written"
        }
    done < "$_rv_secs"
    rm -f "$_rv_secs"
}

# icm_render <relpath> <target>  -> the file body the toolkit wants on stdout
#
# One body per managed path, compiled into this file, and nothing else. There is
# no template lookup and no fallback, so there is no way for a shorter, emptier
# or newer source to win quietly. The closed-set arm below is the whole policy:
# a path with no body is refused, never improvised.
icm_render() {
    icm_tmp_init
    _rd_out="$ICM_TMPDIR/render.out"
    case "$1" in
        IDENTITY.md)              icm_body_identity "$2" ;;
        CONTEXT.md)               icm_body_context_root "$2" ;;
        _config/conventions.md)   icm_body_conventions ;;
        _config/glossary.md)      icm_body_glossary ;;
        _config/voice.md)         icm_body_voice ;;
        _config/style.md)         icm_body_style ;;
        _config/grounding.md)     icm_body_grounding ;;
        raw/CONTEXT.md)           icm_body_raw_context ;;
        output/CONTEXT.md)        icm_body_output_context ;;
        wiki/index.md)            icm_body_wiki_index ;;
        wiki/log.md)              icm_body_wiki_log ;;
        _log/LOOP-LEDGER.md)      icm_body_ledger ;;
        _log/FORGE-PROPOSALS.md)  icm_body_forge_proposals ;;
        CLAUDE.md)                printf '# Project Instructions\n\n'; icm_body_claude_block ;;
        .gitignore)               icm_body_gitignore_block ;;
        *)                        icm_die "no renderer for $1" ;;
    esac > "$_rd_out"
    icm_render_verify "$1" "$_rd_out"
    cat "$_rd_out"
    rm -f "$_rd_out"
}

# icm_candidate <relpath> <target> -> the exact full content the target should
# hold after apply. For adopt roles on an existing file this is the current
# file with only the icm block rewritten.
icm_candidate() {
    _cd_rp="$1"
    _cd_target="$2"
    _cd_role=$(icm_role_of "$_cd_rp")
    _cd_file="$_cd_target/$_cd_rp"
    if [ "$_cd_role" != "adopt" ] || [ ! -f "$_cd_file" ] || [ -L "$_cd_file" ]; then
        icm_render "$_cd_rp" "$_cd_target"
        return 0
    fi
    icm_tmp_init
    _cd_blk="$ICM_TMPDIR/block.$$"
    case "$_cd_rp" in
        .gitignore) icm_body_gitignore_block > "$_cd_blk"; _cd_bm="# $ICM_BEGIN"; _cd_em="# $ICM_END" ;;
        *)          icm_body_claude_block > "$_cd_blk";    _cd_bm="$ICM_BEGIN";   _cd_em="$ICM_END" ;;
    esac
    if [ "$(icm_block_state "$_cd_file" "$_cd_bm" "$_cd_em")" = "malformed" ]; then
        # The markers are mangled, so there is no block to replace. The
        # candidate is the file with our block added and not one byte of the
        # original removed. It is only ever parked in .icm/proposed/ for a
        # human, because a malformed block classifies COLLIDE.
        cat "$_cd_file"
        printf '\n'
        cat "$_cd_blk"
    else
        icm_splice_unchecked "$_cd_file" "$_cd_blk" "$_cd_bm" "$_cd_em"
    fi
    rm -f "$_cd_blk"
}

# icm_markers_for <relpath> -> "<begin>\n<end>" for that path's managed block
icm_begin_for() {
    case "$1" in
        .gitignore) printf '%s\n' "# $ICM_BEGIN" ;;
        *)          printf '%s\n' "$ICM_BEGIN" ;;
    esac
}

icm_end_for() {
    case "$1" in
        .gitignore) printf '%s\n' "# $ICM_END" ;;
        *)          printf '%s\n' "$ICM_END" ;;
    esac
}

# icm_classify <relpath> <target> <candidate-file> -> CREATE|SKIP|ADOPT|COLLIDE
#
# Order matters and is load bearing:
#   1. anything at a managed path that is not a regular file is COLLIDE. -e is
#      false for a dangling symlink, so -L is tested in its own right, and this
#      sits ahead of the CREATE and ADOPT tests. Without it a broken link is
#      classified CREATE and replaced with no backup, a live link is converted
#      to a regular file, a directory aborts apply part way through and a FIFO
#      blocks forever.
#   2. a regular file with more than one name (a hard link) is COLLIDE: a
#      rename would break the link and the other name would keep stale content.
#   3. nothing there at all is CREATE.
#   4. byte identical to the candidate is SKIP.
#   5. an adopt role with a well formed (or absent) managed block is ADOPT.
#   6. everything else, including a mangled marker set, is COLLIDE.
icm_classify() {
    _cl_rp="$1"
    _cl_file="$2/$1"
    _cl_cand="$3"

    if [ -L "$_cl_file" ] || { [ -e "$_cl_file" ] && [ ! -f "$_cl_file" ]; }; then
        printf 'COLLIDE\n'
        return 0
    fi
    if [ -f "$_cl_file" ] && [ "$(icm_nlink "$_cl_file")" -gt 1 ]; then
        printf 'COLLIDE\n'
        return 0
    fi
    if [ ! -e "$_cl_file" ]; then
        printf 'CREATE\n'
        return 0
    fi
    if icm_same "$_cl_file" "$_cl_cand"; then
        printf 'SKIP\n'
        return 0
    fi
    if [ ! -w "$_cl_file" ]; then
        # A rename only needs write permission on the directory, so without this
        # a file the operator deliberately locked down is rewritten anyway.
        printf 'COLLIDE\n'
        return 0
    fi
    if [ "$(icm_role_of "$_cl_rp")" = "adopt" ]; then
        if [ "$(icm_block_state "$_cl_file" "$(icm_begin_for "$_cl_rp")" "$(icm_end_for "$_cl_rp")")" = "malformed" ]; then
            printf 'COLLIDE\n'
            return 0
        fi
        printf 'ADOPT\n'
        return 0
    fi
    printf 'COLLIDE\n'
}

# icm_collide_reason <relpath> <target> -> the reason column for a COLLIDE row
icm_collide_reason() {
    _cr_file="$2/$1"
    if [ -L "$_cr_file" ]; then
        printf 'not a regular file (symlink), candidate parked\n'
        return 0
    fi
    if [ -d "$_cr_file" ]; then
        printf 'not a regular file (directory), candidate parked\n'
        return 0
    fi
    if [ -e "$_cr_file" ] && [ ! -f "$_cr_file" ]; then
        printf 'not a regular file (fifo, socket or device), candidate parked\n'
        return 0
    fi
    if [ -f "$_cr_file" ] && [ "$(icm_nlink "$_cr_file")" -gt 1 ]; then
        printf 'hard linked to another name, candidate parked\n'
        return 0
    fi
    if [ -e "$_cr_file" ] && [ ! -w "$_cr_file" ]; then
        printf 'you cannot write it (mode %s), candidate parked\n' "$(icm_mode_of "$_cr_file")"
        return 0
    fi
    if [ "$(icm_role_of "$1")" = "adopt" ] && \
       [ "$(icm_block_state "$_cr_file" "$(icm_begin_for "$1")" "$(icm_end_for "$1")")" = "malformed" ]; then
        printf 'malformed icm block (%s), candidate parked\n' "$(icm_block_flaw "$_cr_file" "$(icm_begin_for "$1")" "$(icm_end_for "$1")")"
        return 0
    fi
    case "$1" in
        _config/*) printf 'rule book exists, candidate parked\n'; return 0 ;;
    esac
    printf 'exists and differs, candidate parked\n'
}

# icm_reason <status> <relpath> <target> -> the plan's REASON column.
# Never empty. A row a user cannot act on is a row that failed to explain
# itself.
icm_reason() {
    case "$1" in
        SKIP)   printf 'identical, nothing to do\n'; return 0 ;;
        COLLIDE) icm_collide_reason "$2" "$3"; return 0 ;;
    esac
    case "$2" in
        IDENTITY.md)  printf 'layer 0 identity, absent\n' ;;
        CONTEXT.md)   printf 'layer 1 routing, absent\n' ;;
        _config/*)    printf 'layer 3 rule book, absent\n' ;;
        raw/*)        printf 'layer 4a job card, absent\n' ;;
        wiki/*)       printf 'layer 4b knowledge, absent\n' ;;
        output/*)     printf 'layer 4b job card, absent\n' ;;
        _log/*)       printf 'ledger and proposals, absent\n' ;;
        .gitignore)   printf 'gitignore, icm block will be appended\n' ;;
        CLAUDE.md)    printf 'adapter, icm block will be appended\n' ;;
        *)            printf 'managed path, %s\n' "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" ;;
    esac
}

# ---------------------------------------------------------------------- git --

icm_is_git_repo() {
    command -v git >/dev/null 2>&1 || return 1
    ( cd "$1" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1 )
}

# Dirty means uncommitted work the toolkit could stomp on. Anything the
# toolkit itself parks under .icm/ does not count, otherwise the second run
# of icm-plan would refuse because of the first run's plan file.
icm_git_dirty() {
    ( cd "$1" && git status --porcelain 2>/dev/null ) \
        | awk '{ p = substr($0, 4); if (p !~ /^\.icm\//) print }' \
        | grep -q .
}

icm_git_dirty_list() {
    ( cd "$1" && git status --porcelain 2>/dev/null ) \
        | awk '{ p = substr($0, 4); if (p !~ /^\.icm\//) print }'
}
