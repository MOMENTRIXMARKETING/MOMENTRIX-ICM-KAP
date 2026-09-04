#!/bin/sh
# icm-loop.sh - the librarian for the loop.
#
# Three jobs, all mechanical, none of them judgment:
#   --index   read _log/LOOP-LEDGER.md and the workspace, write _log/SKILL-INDEX.md:
#             one row per skill, job card and rule book, with use counts, open
#             misses, recurrences and a verdict word from the kill rules.
#   --starve  the starvation check alone: real work in the window and not one
#             miss line means the write back is not firing.
#   --block   print the Session Close block between markers, for a host that is
#             not an ICM workspace and needs the write back pasted into whatever
#             file it loads on every run.
#
# It writes exactly one file, <target>/_log/SKILL-INDEX.md, and only in --index
# mode. It never touches the ledger, a rule book, a job card or a skill. The
# index is a compiled artifact, overwritten every run: the ledger is the record.
#
# No model is needed to run it. A cron, a CI job or a shell alias gets the same
# index a model would, which is the point: the loop must not depend on which
# agent is over the top of it.
#
# POSIX sh only. No bashisms. No python required.

set -e

usage() {
    cat <<'ICM_USAGE'
usage: icm-loop.sh [--index] [--starve] [--block] [--today YYYY-MM-DD]
                   [-h|--help] [target-dir]

Compiles the skill index from the ledger, or checks it for starvation, or
prints the Session Close block. target-dir defaults to the current directory.
With no mode flag, --index runs.

  --index         read _log/LOOP-LEDGER.md, write _log/SKILL-INDEX.md, print it
  --starve        starvation check only, nothing written
  --block         print the Session Close block between its markers, nothing written
  --today DATE    count windows back from DATE instead of today (tests, replays)
  -h, --help      this text

Windows and thresholds come from the loop section of icm.defaults.json.

Exit: 0 clean, 1 a verdict or the starvation check is waiting on a human,
2 refused (no ledger, bad target, usage error).
ICM_USAGE
}

ICM_SELF=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
ICM_HOME=$(cd -P -- "$ICM_SELF/.." && pwd -P)
. "$ICM_HOME/scripts/icm_lib.sh"

TARGET=""
MODE=""
TODAY=""

set_mode() {
    if [ -n "$MODE" ] && [ "$MODE" != "$1" ]; then
        printf 'FAIL one mode at a time: --%s and --%s\n' "$MODE" "$1" >&2
        exit 2
    fi
    MODE="$1"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --index)   set_mode index ;;
        --starve)  set_mode starve ;;
        --block)   set_mode block ;;
        --today)
            [ $# -ge 2 ] || { printf 'FAIL --today needs a date\n' >&2; exit 2; }
            TODAY="$2"
            shift ;;
        --today=*) TODAY="${1#--today=}" ;;
        -h|--help) usage; exit 0 ;;
        --*)       printf 'FAIL unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
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

[ -n "$MODE" ] || MODE=index
[ -n "$TARGET" ] || TARGET="."
[ -n "$TODAY" ] || TODAY=$(icm_today)
case "$TODAY" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) : ;;
    *) printf 'FAIL --today wants YYYY-MM-DD, got: %s\n' "$TODAY" >&2; exit 2 ;;
esac
_td_m=${TODAY#*-}; _td_m=${_td_m%-*}; _td_d=${TODAY##*-}
if [ "${_td_m#0}" -lt 1 ] || [ "${_td_m#0}" -gt 12 ] || [ "${_td_d#0}" -lt 1 ] || [ "${_td_d#0}" -gt 31 ]; then
    printf 'FAIL --today is not a calendar date: %s\n' "$TODAY" >&2
    exit 2
fi

# --block needs no workspace. Everything else does.
if [ "$MODE" = block ]; then
    printf '%s\n' '<!-- ICM-LOOP:START -->'
    icm_body_session_close
    printf '%s\n' '<!-- ICM-LOOP:END -->'
    exit 0
fi

[ -d "$TARGET" ] || icm_die "no such directory: $TARGET"
TARGET=$(icm_abspath "$TARGET")
icm_init "$TARGET"
icm_trap_default

LEDGER=$(icm_json_get "$ICM_DEFAULTS" log.ledger 2>/dev/null) || LEDGER="_log/LOOP-LEDGER.md"
INDEX=$(icm_json_get "$ICM_DEFAULTS" log.skill_index 2>/dev/null) || INDEX="_log/SKILL-INDEX.md"
STARVE_DAYS=$(icm_json_num "$ICM_DEFAULTS" loop.starve_days 7)
RECENT_DAYS=$(icm_json_num "$ICM_DEFAULTS" loop.recent_days 30)
ARCHIVE_DAYS=$(icm_json_num "$ICM_DEFAULTS" loop.archive_days 60)
SEV3_N=$(icm_json_num "$ICM_DEFAULTS" loop.hole_sev3_count 1)
SEV2_N=$(icm_json_num "$ICM_DEFAULTS" loop.hole_sev2_count 2)
RECUR_N=$(icm_json_num "$ICM_DEFAULTS" loop.recurrence_rewrite_count 2)

LEDGER_FILE="$TARGET/$LEDGER"
[ -f "$LEDGER_FILE" ] || icm_die "no ledger at $LEDGER. nothing to index. run: sh \"\$ICM_HOME/scripts/icm-plan.sh\" then icm-apply.sh, or /icm-log miss"

icm_tmp_init
DISK="$ICM_TMPDIR/loop-disk.$$"
ROWS="$ICM_TMPDIR/loop-rows.$$"

# --------------------------------------------------------------- the walk ---
# What is on disk that the loop can hold to account. Three kinds, by path shape.
# The root CONTEXT.md is routing, not a job card, so it is not a row.
: > "$DISK"
icm_walk_md "$TARGET" | while IFS= read -r _w_rel; do
    case "$_w_rel" in
        skills/*/SKILL.md)
            _w_name=${_w_rel#skills/}
            _w_name=${_w_name%/SKILL.md}
            printf 'skill\t%s\t%s\n' "$_w_name" "$_w_rel" >> "$DISK" ;;
        */skills/*/SKILL.md)
            _w_name=${_w_rel%/SKILL.md}
            _w_name=${_w_name##*/}
            printf 'skill\t%s\t%s\n' "$_w_name" "$_w_rel" >> "$DISK" ;;
        _config/*.md|*/_config/*.md)
            _w_name=${_w_rel##*/}
            _w_name=${_w_name%.md}
            printf 'rule book\t%s\t%s\n' "$_w_name" "$_w_rel" >> "$DISK" ;;
        CONTEXT.md) : ;;
        */CONTEXT.md)
            _w_name=${_w_rel%/CONTEXT.md}
            printf 'job card\t%s\t%s\n' "$_w_name" "$_w_rel" >> "$DISK" ;;
    esac
done

# ------------------------------------------------------------- the count ---
# One awk pass over the ledger and the disk list. Every number here is a
# count. The verdict word is the kill rule that count trips, and the kill
# rules are stated in the index it writes, so a reader can check the sum.
#
# Ledger line shapes read, by the literal in column two:
#   | date | Miss    | sev | path | what | fix |
#   | date | Use     | name | path | task | outcome | misses |
#   | date | Patched | path | id |
# Anything else with a date in column one is a task line or a call line and
# counts as work done.
awk -F '|' \
    -v today="$TODAY" -v starve="$STARVE_DAYS" -v recent="$RECENT_DAYS" \
    -v archive="$ARCHIVE_DAYS" -v sev3n="$SEV3_N" -v sev2n="$SEV2_N" \
    -v recurn="$RECUR_N" -v disk="$DISK" -v mode="$MODE" -v ledger="$LEDGER" \
    -v target="$TARGET" -v icmhome="$ICM_HOME" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function isdate(s) { return s ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ }
function dn(s,   y, m, d, a, yy, mm) {
    y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
    a = int((14 - m) / 12); yy = y + 4800 - a; mm = m + 12 * a - 3
    return d + int((153 * mm + 2) / 5) + 365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) - 32045
}
function seen(p) { if (!(p in known)) { known[p] = 1; order[++norder] = p } }
BEGIN {
    tnow = dn(today)
    while ((getline line < disk) > 0) {
        n = split(line, f, "\t")
        if (n < 3) continue
        seen(f[3]); kind[f[3]] = f[1]; name[f[3]] = f[2]; ondisk[f[3]] = 1
    }
    close(disk)
    first = ""; nlines = 0
}
/^\|/ {
    d = trim($2)
    if (!isdate(d)) next
    nlines++
    if (first == "" || dn(d) < dn(first)) first = d
    age = tnow - dn(d)
    sel = trim($3)
    if (sel == "Miss") {
        sev = trim($4) + 0; p = trim($5); what = trim($6)
        if (p == "") p = "none"
        seen(p); if (!(p in kind)) kind[p] = (p == "none") ? "none" : "?"
        if (!(p in name)) name[p] = p
        nmiss++
        if (age >= 0 && age < starve) miss_win++
        misstotal[p]++
        if (dn(d) > lastpatch_dn[p]) {
            openmiss[p]++
            if (sev >= 3) osev3[p]++
            if (sev >= 2) osev2[p]++
            if (sev > maxsev[p]) maxsev[p] = sev
            if (what ~ /^RECURRENCE:/) recur[p]++
        }
        next
    }
    if (sel == "Use") {
        nm = trim($4); p = trim($5)
        if (p == "") p = nm
        seen(p); if (!(p in kind)) kind[p] = "?"
        if (!(p in name)) name[p] = nm
        nuse++
        if (age >= 0 && age < starve) work_win++
        if (age >= 0 && age < recent) uses30[p]++
        if (age >= 0 && age < archive) uses60[p]++
        if (lastuse[p] == "" || dn(d) > dn(lastuse[p])) lastuse[p] = d
        next
    }
    if (sel == "Patched") {
        p = trim($4)
        seen(p); if (!(p in kind)) kind[p] = "?"
        if (!(p in name)) name[p] = p
        if (dn(d) >= lastpatch_dn[p]) {
            lastpatch_dn[p] = dn(d); lastpatch[p] = d
            # misses before this patch are closed: reset the open counters
            openmiss[p] = 0; osev3[p] = 0; osev2[p] = 0; maxsev[p] = 0; recur[p] = 0
        }
        next
    }
    # a task line or a call line: work happened
    ntask++
    if (age >= 0 && age < starve) work_win++
}
END {
    ledger_age = (first == "") ? -1 : tnow - dn(first)
    starved = 0
    if (work_win > 0 && miss_win == 0) starved = 1
    if (mode == "starve") {
        if (first == "") {
            printf "note the ledger has no dated lines yet. install date unknown, nothing to judge\n"
            exit 0
        }
        printf "note window %d days back from %s: %d task or use lines, %d miss lines\n", starve, today, work_win, miss_win
        if (starved) {
            printf "FAIL STARVED. real work and not one miss in %d days means the Session Close is not firing. reinstall it before touching a rule book. run: sh \"$ICM_HOME/scripts/icm-loop.sh\" --block\n", starve
            exit 1
        }
        if (work_win == 0) printf "note no work logged in the window either. quiet week or a dead workspace\n"
        else printf "ok   the write back is firing\n"
        exit 0
    }
    waiting = 0
    printf "# SKILL INDEX\n\n"
    printf "Compiled by icm-loop.sh on %s from `%s`. Overwritten every run. Do not edit: the ledger is the record, this is the count.\n\n", today, ledger
    if (first == "") printf "Ledger: no dated lines yet.\n\n"
    else printf "Ledger: first line %s, %d days old, %d dated lines (%d task or call, %d use, %d miss).\n\n", first, ledger_age, nlines, ntask, nuse, nmiss
    printf "## Starvation\n\n"
    if (first == "") printf "Unknown. Nothing dated in the ledger.\n\n"
    else if (starved) { printf "STARVED. %d task or use lines and 0 miss lines in the last %d days. The Session Close is not firing. Reinstall it before touching a rule book.\n\n", work_win, starve; waiting = 1 }
    else if (work_win == 0) printf "Quiet. No task or use lines in the last %d days, %d miss lines.\n\n", starve, miss_win
    else printf "Firing. %d task or use lines and %d miss lines in the last %d days.\n\n", work_win, miss_win, starve
    printf "## Index\n\n"
    printf "| Name | Kind | Path | Uses %dd | Uses %dd | Last used | Open misses | Max sev | Recurrences | Last patched | Verdict |\n", recent, archive
    printf "|---|---|---|---|---|---|---|---|---|---|---|\n"
    for (i = 1; i <= norder; i++) {
        p = order[i]
        # A ledger path outside the three kinds the walk collects (a spec, a
        # script, a doc) is still a real file, and a toolkit skill lives in
        # the toolkit, not the workspace. Ask both disks before calling it a
        # ghost. Quotes in a path are escaped for the shell.
        if (!(p in ondisk) && p != "none") {
            q = p; gsub(/"/, "\\\"", q)
            if (system("[ -f \"" target "/" q "\" ]") == 0) { ondisk[p] = 1; kind[p] = "other" }
            else if (system("[ -f \"" icmhome "/" q "\" ]") == 0) { ondisk[p] = 1; kind[p] = "toolkit skill" }
        }
        k = kind[p]
        v = "ok"
        if (p == "none") v = (openmiss[p] > 0) ? "uncovered" : "ok"
        else if (recur[p] >= recurn) v = "rewrite"
        else if (osev3[p] >= sev3n || osev2[p] >= sev2n) v = "hole"
        else if (!(p in ondisk)) v = "ghost"
        else if ((k == "skill" || k == "job card") && ledger_age >= archive && uses60[p] == 0) v = "archive"
        else if ((k == "skill" || k == "job card") && uses30[p] >= 3 && misstotal[p] == 0) v = "check-write-back"
        else if ((k == "skill" || k == "job card") && uses60[p] == 0 && misstotal[p] == 0) v = "unlogged"
        if (v != "ok" && v != "unlogged") waiting = 1
        u30 = (k == "rule book") ? "-" : uses30[p] + 0
        u60 = (k == "rule book") ? "-" : uses60[p] + 0
        lu = (lastuse[p] == "") ? "-" : lastuse[p]
        lp = (lastpatch[p] == "") ? "-" : lastpatch[p]
        printf "| %s | %s | `%s` | %s | %s | %s | %d | %d | %d | %s | %s |\n", name[p], k, p, u30, u60, lu, openmiss[p] + 0, maxsev[p] + 0, recur[p] + 0, lp, v
    }
    printf "\n## Verdicts\n\n"
    printf "Every verdict is a mechanical report. The count is a fact, the action is a human decision, and the forge writes the proposal.\n\n"
    printf "| Verdict | The count that tripped it | What a human decides |\n|---|---|---|\n"
    printf "| rewrite | %d or more open misses starting RECURRENCE: | The last fix was wrong at the concept level. Rewrite the file, do not patch it |\n", recurn
    printf "| hole | %d open miss at sev 3, or %d at sev 2 or higher, since the last patch | The forge proposes the smallest edit |\n", sev3n, sev2n
    printf "| ghost | The ledger names a path that is not on disk | Fix the path in future lines, or the file was moved without a patched line |\n"
    printf "| uncovered | Misses logged against none | No file covers this ground. Placement question: what kind, what path |\n"
    printf "| archive | Ledger older than %d days and no use line in that window | It is not part of how you work. Archive it |\n", archive
    printf "| check-write-back | 3 or more uses in %d days and never one miss | Under logged, not perfect. Fix the Session Close before touching the file |\n", recent
    printf "| unlogged | On disk, no use and no miss yet, ledger younger than %d days | Nothing yet. Young, not dead |\n", archive
    printf "| ok | None of the above | Nothing |\n"
    exit waiting
}' "$LEDGER_FILE" > "$ROWS" && RC=0 || RC=$?

if [ "$RC" -gt 1 ]; then
    cat "$ROWS" >&2
    icm_die "the index pass failed"
fi

if [ "$MODE" = starve ]; then
    cat "$ROWS"
    exit "$RC"
fi

icm_atomic_write "$TARGET/$INDEX" < "$ROWS"
cat "$ROWS"
printf '\n'
if [ "$RC" -eq 0 ]; then
    printf 'ok   wrote %s, nothing waiting\n' "$INDEX"
else
    printf 'warn wrote %s, at least one verdict is waiting on a human. next: /icm-forge run\n' "$INDEX"
fi
exit "$RC"
