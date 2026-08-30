#!/bin/sh
# icm-apply.sh - execute a plan written by icm-plan.sh, and nothing else.
#
# The rules this script exists to enforce:
#   - nothing you wrote is ever deleted or rewritten. Most managed paths are
#     only written when nothing exists there. Two of them, CLAUDE.md and
#     .gitignore, are edited in place, and only between <!-- icm:begin --> and
#     <!-- icm:end -->. Every byte outside those markers is unchanged, and the
#     pre-image is copied under .icm/backup/<stamp>/files/ before the edit.
#     Anything else that already exists is a collision: the toolkit's version
#     goes to .icm/proposed/ with a diff beside it, and your file is not
#     touched.
#   - one apply at a time per target. The lock is taken before anything is
#     classified, because the race is between one run's decisions and another
#     run's writes.
#   - the manifest is durable. Every row is on disk before the next write
#     starts, and COMPLETE is written only after the last one, so an interrupted
#     run is a run rollback can replay rather than a run that vanished.
#   - running it twice changes nothing.
#
# POSIX sh only. No bashisms. No python required.

set -e

usage() {
    cat <<'ICM_USAGE'
usage: icm-apply.sh [--plan FILE] [--dry-run] [--no-check] [--force-unlock]
                    [-h|--help] [target-dir]

Executes <target>/.icm/plan.txt. Run icm-plan.sh first.
target-dir defaults to the current directory.

  CREATE   writes the file
  ADOPT    keeps your file, appends or rewrites only the delimited icm block,
           backing the pre-image up first
  COLLIDE  writes the candidate and a diff to .icm/proposed/<relpath> and
           leaves your file exactly as it is
  SKIP     already identical, does nothing
  REFUSE   never_write, or a path that resolves outside the target: nothing at
           all happens, and nothing is proposed
  SURVEY   plan's tree survey. apply does not act on survey rows.

Options:
  --plan FILE     use this plan instead of <target>/.icm/plan.txt
  --dry-run       say what would happen, write nothing at all
  --no-check      skip the closing icm-check.sh run
  --force-unlock  remove a lock left behind by a killed run, and say whose it was
  -h, --help      this text

To undo an apply, run scripts/icm-rollback.sh.

Exit: 0 applied clean or nothing to do, 1 applied and a human decision is
waiting, 2 refused before anything was written, 3 aborted part way through and
the target may be half changed.
ICM_USAGE
}

ICM_SELF=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
ICM_HOME=$(cd -P -- "$ICM_SELF/.." && pwd -P)
. "$ICM_HOME/scripts/icm_lib.sh"

TARGET=""
PLAN=""
DRY=0
NOCHECK=0
FORCE_UNLOCK=0

while [ $# -gt 0 ]; do
    case "$1" in
        --plan)    shift; [ $# -gt 0 ] || icm_die "--plan needs a file"; PLAN="$1" ;;
        --dry-run) DRY=1 ;;
        --no-check) NOCHECK=1 ;;
        --force-unlock) FORCE_UNLOCK=1 ;;
        --rollback)
            printf 'FAIL --rollback is not a flag on apply.\n' >&2
            printf 'note to undo an apply, run: scripts/icm-rollback.sh [--stamp STAMP] [target-dir]\n' >&2
            printf 'note run scripts/icm-rollback.sh --help for the options.\n' >&2
            exit 2
            ;;
        -h|--help) usage; exit 0 ;;
        --*)       printf 'FAIL unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
        *)
            if [ -n "$TARGET" ]; then
                printf 'FAIL more than one target given: %s\n' "$1" >&2
                printf 'note apply takes one target directory. quote a path that has spaces in it.\n' >&2
                exit 2
            fi
            TARGET="$1"
            ;;
    esac
    shift
done

[ -n "$TARGET" ] || TARGET="."
TARGET=$(icm_require_target "$TARGET") || exit 2
[ -n "$PLAN" ] || PLAN="$TARGET/.icm/plan.txt"

icm_init "$TARGET"

# ------------------------------------------------------------ traps and lock --
#
# A POSIX trap handler that does not exit returns to the script, so INT and TERM
# have to exit. They do it by falling into the EXIT handler, which is the one
# place the lock is released and the work directory is removed.

LOCKDIR=""
WRITE_PHASE=0
FINISHED=0
WROTE=0
STAMP=""

release_lock() {
    if [ -n "$LOCKDIR" ] && [ -d "$LOCKDIR" ]; then
        rm -f "$LOCKDIR/pid"
        rmdir "$LOCKDIR" 2>/dev/null || true
    fi
}

on_exit() {
    _ax_st=$?
    if [ "$WRITE_PHASE" -eq 1 ] && [ "$FINISHED" -eq 0 ]; then
        printf 'FAIL apply aborted after %s write(s). the target may be half changed.\n' "$WROTE" >&2
        printf 'note the manifest is durable, so this run can still be undone:\n' >&2
        printf 'note   scripts/icm-rollback.sh --stamp %s %s\n' "$STAMP" "$TARGET" >&2
        case "$_ax_st" in
            0|1|2) _ax_st=3 ;;
        esac
    fi
    release_lock
    icm_cleanup
    exit "$_ax_st"
}

trap 'on_exit' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --------------------------------------------------------------- the refusals --

if [ ! -f "$PLAN" ]; then
    printf 'FAIL no plan at %s\n' "$PLAN" >&2
    printf 'note run icm-plan.sh first. apply never guesses.\n' >&2
    exit 2
fi

CR=$(printf '\r')
if grep -q "$CR" "$PLAN" 2>/dev/null; then
    printf 'FAIL the plan at %s contains carriage returns (CRLF line endings).\n' "$PLAN" >&2
    printf 'note an editor rewrote it. rerun: scripts/icm-plan.sh %s\n' "$TARGET" >&2
    exit 2
fi

PLAN_TARGET=$(sed -n 's/^# target: //p' "$PLAN" | head -n 1 | tr -d "$CR")
ICM_ARCHETYPE=$(sed -n 's/^# archetype: //p' "$PLAN" | head -n 1 | tr -d "$CR")
[ -n "$ICM_ARCHETYPE" ] || ICM_ARCHETYPE=quick
export ICM_ARCHETYPE
if [ -n "$PLAN_TARGET" ] && [ "$PLAN_TARGET" != "$TARGET" ]; then
    printf 'FAIL the plan was written for [%s], not [%s]\n' "$PLAN_TARGET" "$TARGET" >&2
    printf 'note the brackets are there so an invisible difference is visible.\n' >&2
    printf 'note rerun: scripts/icm-plan.sh %s\n' "$TARGET" >&2
    exit 2
fi

# The lock goes here: after the plan is known to belong to this target, before a
# stamp is taken, and before pass 1. A mutex scoped to the write pass does not
# close the race, because the write pass dispatches on decisions the other run
# has already invalidated.
if [ "$DRY" -eq 0 ]; then
    mkdir -p "$TARGET/.icm"
    if ! mkdir "$TARGET/.icm/lock" 2>/dev/null; then
        if [ "$FORCE_UNLOCK" -eq 1 ]; then
            printf 'warn removing the lock at %s/.icm/lock\n' "$TARGET"
            if [ -f "$TARGET/.icm/lock/pid" ]; then
                sed 's/^/warn   held by: /' "$TARGET/.icm/lock/pid"
            else
                printf 'warn   it carries no pid file, so nothing is known about who held it\n'
            fi
            rm -rf "$TARGET/.icm/lock"
            mkdir "$TARGET/.icm/lock" || icm_die "cannot take the lock at $TARGET/.icm/lock"
        else
            printf 'FAIL another apply is running in this target\n' >&2
            printf 'note the lock is %s/.icm/lock\n' "$TARGET" >&2
            if [ -f "$TARGET/.icm/lock/pid" ]; then
                sed 's/^/note   /' "$TARGET/.icm/lock/pid" >&2
            fi
            printf 'note if no apply is running, that lock was left by a killed run. clear it with:\n' >&2
            printf 'note   scripts/icm-apply.sh --force-unlock %s\n' "$TARGET" >&2
            exit 2
        fi
    fi
    LOCKDIR="$TARGET/.icm/lock"
    printf 'pid %s\nstarted %s\n' "$$" "$(icm_utc_iso)" > "$LOCKDIR/pid"
fi

STAMP=$(icm_utc_stamp)
BACKUP="$TARGET/.icm/backup/$STAMP"
PROPOSED="$TARGET/.icm/proposed"
ROWS="$ICM_TMPDIR/rows"
CANDDIR="$ICM_TMPDIR/cand"
TAB=$(printf '\t')
mkdir -p "$CANDDIR"
: > "$ROWS"

if [ "$DRY" -eq 0 ] && [ -e "$BACKUP" ]; then
    icm_die "a backup directory for stamp $STAMP already exists at $BACKUP. refusing to merge two runs into one backup."
fi

printf '# icm-apply\n'
printf 'target:   %s\n' "$TARGET"
printf 'plan:     %s\n' "$PLAN"
if [ "$DRY" -eq 1 ]; then
    printf 'mode:     dry run, nothing will be written\n'
else
    printf 'stamp:    %s\n' "$STAMP"
fi
printf '\n'

_shanote=$(icm_sha_mode_note)
if [ -n "$_shanote" ]; then
    printf 'warn %s\n' "$_shanote"
fi

# ---------------------------------------------------- pass 1: decide, no writes --

IDX=0
WRITES=0
COLLISIONS=0
REFUSALS=0
SURVEYS=0

while IFS="$TAB" read -r P_STATUS P_ROLE P_RP P_SHA P_REASON; do
    case "$P_STATUS" in
        '#'*|'') continue ;;
        SURVEY)  SURVEYS=$((SURVEYS + 1)); continue ;;
    esac
    [ -n "$P_RP" ] || continue

    if ! icm_never_write_ok "$P_RP"; then
        printf 'FAIL refusing %s, %s is on the never_write list in icm.defaults.json\n' \
            "$P_RP" "$(icm_never_write_hit "$P_RP")"
        REFUSALS=$((REFUSALS + 1))
        continue
    fi
    ESCAPE=$(icm_path_escape "$TARGET" "$P_RP") || true
    if [ -n "$ESCAPE" ]; then
        printf 'FAIL refusing %s, %s\n' "$P_RP" "$ESCAPE"
        REFUSALS=$((REFUSALS + 1))
        continue
    fi

    IDX=$((IDX + 1))
    CAND="$CANDDIR/$IDX"
    icm_candidate "$P_RP" "$TARGET" > "$CAND"
    LIVE=$(icm_classify "$P_RP" "$TARGET" "$CAND")

    if [ "$LIVE" != "$P_STATUS" ]; then
        printf 'warn %s changed since the plan was written: plan said %s, disk says %s\n' \
            "$P_RP" "$P_STATUS" "$LIVE"
        if [ "$LIVE" = COLLIDE ]; then
            printf 'warn   %s\n' "$(icm_collide_reason "$P_RP" "$TARGET")"
        fi
    fi

    W=0
    case "$LIVE" in
        CREATE) W=1 ;;
        ADOPT)  W=1 ;;
        COLLIDE)
            COLLISIONS=$((COLLISIONS + 1))
            if [ -f "$PROPOSED/$P_RP" ] && icm_same "$PROPOSED/$P_RP" "$CAND" && [ -f "$PROPOSED/$P_RP.diff" ]; then
                W=0
            else
                W=1
            fi
            ;;
        SKIP)   W=0 ;;
    esac
    if [ "$W" -eq 1 ]; then
        WRITES=$((WRITES + 1))
    fi
    printf '%s%s%s%s%s%s%s%s%s\n' "$IDX" "$TAB" "$LIVE" "$TAB" "$P_ROLE" "$TAB" "$W" "$TAB" "$P_RP" >> "$ROWS"
done < "$PLAN"

if [ "$IDX" -eq 0 ]; then
    printf 'FAIL the plan has no rows apply can act on. rerun icm-plan.sh.\n' >&2
    printf 'note the plan is tab separated: STATUS ROLE RELPATH CANDIDATE-SHA REASON.\n' >&2
    exit 2
fi

# A plan that names one path twice cannot be executed safely: the second row
# would store the first row's output as the "pre-image".
DUP=$(awk -F "$TAB" '{ print $5 }' "$ROWS" | sort | uniq -d | head -n 1)
if [ -n "$DUP" ]; then
    printf 'FAIL the plan lists the same path twice: %s\n' "$DUP" >&2
    printf 'note rerun: scripts/icm-plan.sh %s\n' "$TARGET" >&2
    exit 2
fi

if [ "$SURVEYS" -gt 0 ]; then
    printf 'note the plan also carries %s survey row(s). apply does not act on them; run /icm-context.\n' "$SURVEYS"
fi

if [ "$WRITES" -eq 0 ]; then
    awk -F "$TAB" '{ printf "ok   %-8s %s\n", $2, $5 }' "$ROWS"
    printf '\nok   nothing to do, the workspace already matches the plan\n'
    if [ "$COLLISIONS" -gt 0 ] || [ "$REFUSALS" -gt 0 ]; then
        if [ "$COLLISIONS" -gt 0 ]; then
            printf 'warn %s collision(s) are still parked in .icm/proposed/ awaiting your call\n' "$COLLISIONS"
        fi
        if [ "$REFUSALS" -gt 0 ]; then
            printf 'warn %s path(s) were refused outright\n' "$REFUSALS"
        fi
        printf 'result: a decision is waiting\n'
        exit 1
    fi
    printf 'result: clean\n'
    exit 0
fi

if [ "$DRY" -eq 1 ]; then
    awk -F "$TAB" '{ printf "note would %-8s %s\n", $2, $5 }' "$ROWS"
    printf '\nnote dry run finished, %s file(s) would be written\n' "$WRITES"
    printf 'result: dry run\n'
    exit 0
fi

# ------------------------------------------------------------- pass 2: write --
#
# The manifest is created with its header before the first write and every row
# is appended immediately after the write it describes. COMPLETE is written
# after the last row. Nothing is assembled in the work directory: an error, a
# Ctrl-C or a full disk must never be able to destroy the index that makes the
# pre-images reachable.

mkdir -p "$BACKUP/files"
MANIFEST="$BACKUP/manifest.txt"
{
    printf '# icm apply manifest\n'
    printf '# stamp: %s\n' "$STAMP"
    printf '# applied: %s\n' "$(icm_utc_iso)"
    printf '# target: %s\n' "$TARGET"
    printf '# toolkit: %s %s\n' "$ICM_TOOLKIT" "$ICM_VERSION"
    printf '# sha-mode: %s\n' "$ICM_SHA_MODE"
    printf '# format: ACTION%sRELPATH%sPRE-SHA%sPOST-SHA%sMODE\n' "$TAB" "$TAB" "$TAB" "$TAB"
} > "$MANIFEST"

man_row() {
    printf '%s%s%s%s%s%s%s%s%s\n' "$1" "$TAB" "$2" "$TAB" "$3" "$TAB" "$4" "$TAB" "$5" >> "$MANIFEST"
}

# Create every missing directory component of a relative path, recording each
# one, so rollback removes only the directories this run actually made.
ensure_dirs() {
    _ed_dir=$(dirname -- "$1")
    [ "$_ed_dir" = "." ] && return 0
    _ed_acc=""
    _ed_rest="$_ed_dir"
    while [ -n "$_ed_rest" ]; do
        case "$_ed_rest" in
            */*) _ed_head=${_ed_rest%%/*}; _ed_rest=${_ed_rest#*/} ;;
            *)   _ed_head="$_ed_rest";     _ed_rest="" ;;
        esac
        [ -n "$_ed_head" ] || continue
        if [ -z "$_ed_acc" ]; then _ed_acc="$_ed_head"; else _ed_acc="$_ed_acc/$_ed_head"; fi
        if [ ! -d "$TARGET/$_ed_acc" ]; then
            mkdir "$TARGET/$_ed_acc"
            man_row MKDIR "$_ed_acc" '-' '-' '-'
        fi
    done
    return 0
}

# Containment, checked again at write time. Pass 1 refused the escapes it could
# see; this is the guard that stands between a plan and the disk.
dest_ok() {
    _do_par=$(icm_parent_real "$TARGET/$1")
    if [ -z "$_do_par" ] || ! icm_under "$_do_par" "$TARGET"; then
        return 1
    fi
    return 0
}

WRITE_PHASE=1
N_CREATED=0
N_MODIFIED=0
N_PARKED=0
N_SKIPPED=0

while IFS="$TAB" read -r R_IDX R_STATUS R_ROLE R_W R_RP; do
    [ -n "$R_RP" ] || continue
    CAND="$CANDDIR/$R_IDX"
    DEST="$TARGET/$R_RP"
    case "$R_STATUS" in
        CREATE)
            ensure_dirs "$R_RP"
            if ! dest_ok "$R_RP"; then
                printf 'FAIL refusing %s, it resolves outside %s\n' "$R_RP" "$TARGET"
                REFUSALS=$((REFUSALS + 1))
                continue
            fi
            icm_atomic_write "$DEST" < "$CAND"
            WROTE=$((WROTE + 1))
            man_row CREATED "$R_RP" '-' "$(icm_sha "$DEST")" "$(icm_mode_of "$DEST")"
            printf 'ok   created  %s\n' "$R_RP"
            N_CREATED=$((N_CREATED + 1))
            ;;
        ADOPT)
            if ! dest_ok "$R_RP"; then
                printf 'FAIL refusing %s, it resolves outside %s\n' "$R_RP" "$TARGET"
                REFUSALS=$((REFUSALS + 1))
                continue
            fi
            if [ -e "$BACKUP/files/$R_RP" ]; then
                icm_die "a pre-image for $R_RP already exists in this run; refusing to overwrite it"
            fi
            PRE=$(icm_sha "$DEST")
            PREMODE=$(icm_mode_of "$DEST")
            mkdir -p "$(dirname -- "$BACKUP/files/$R_RP")"
            cp -p "$DEST" "$BACKUP/files/$R_RP"
            icm_atomic_write "$DEST" "$PREMODE" < "$CAND"
            WROTE=$((WROTE + 1))
            man_row MODIFIED "$R_RP" "$PRE" "$(icm_sha "$DEST")" "$PREMODE"
            printf 'ok   adopted  %s (pre-image in .icm/backup/%s/files/%s)\n' "$R_RP" "$STAMP" "$R_RP"
            N_MODIFIED=$((N_MODIFIED + 1))
            ;;
        COLLIDE)
            if [ "$R_W" -eq 1 ]; then
                icm_atomic_write "$PROPOSED/$R_RP" < "$CAND"
                WROTE=$((WROTE + 1))
                # Only a regular file can be diffed. diff on a FIFO with no
                # writer blocks forever, and a directory or a device has no
                # text to compare. diff also exits 1 on a difference, which
                # set -e would treat as an error, so its status is discarded on
                # purpose.
                if [ -f "$DEST" ] && [ ! -L "$DEST" ]; then
                    diff -u "$DEST" "$PROPOSED/$R_RP" > "$PROPOSED/$R_RP.diff" 2>/dev/null || true
                else
                    {
                        printf '# no diff: %s is not a regular file.\n' "$R_RP"
                        printf '# %s\n' "$(icm_collide_reason "$R_RP" "$TARGET")"
                        printf '# the candidate beside this file is what the toolkit would write.\n'
                    } > "$PROPOSED/$R_RP.diff"
                fi
            fi
            man_row PARKED "$R_RP" "$(icm_sha "$DEST")" "$(icm_sha "$PROPOSED/$R_RP")" '-'
            printf 'warn collide  %s left untouched, candidate is in .icm/proposed/%s\n' "$R_RP" "$R_RP"
            printf 'warn   %s\n' "$(icm_collide_reason "$R_RP" "$TARGET")"
            N_PARKED=$((N_PARKED + 1))
            ;;
        SKIP)
            man_row SKIPPED "$R_RP" "$(icm_sha "$DEST")" "$(icm_sha "$DEST")" "$(icm_mode_of "$DEST")"
            printf 'ok   skipped  %s already identical\n' "$R_RP"
            N_SKIPPED=$((N_SKIPPED + 1))
            ;;
    esac
done < "$ROWS"

icm_utc_iso > "$BACKUP/COMPLETE"
FINISHED=1

printf '\nok   created %s   modified %s   parked %s   skipped %s\n' \
    "$N_CREATED" "$N_MODIFIED" "$N_PARKED" "$N_SKIPPED"
printf 'ok   manifest: %s\n' "$MANIFEST"

# ------------------------------------------------------------- the closing check --

if [ "$NOCHECK" -eq 0 ] && [ -f "$ICM_HOME/scripts/icm-check.sh" ]; then
    printf '\n'
    CHECKOUT="$ICM_TMPDIR/check.out"
    sh "$ICM_HOME/scripts/icm-check.sh" "$TARGET" > "$CHECKOUT" 2>&1 || true
    printf 'ok   icm-check.sh ran on the result:\n'
    sed -n '/^-- summary --$/,$p' "$CHECKOUT" | sed 's/^/     /'
    printf 'note the check does not change this run status. read the full report with:\n'
    printf 'note   scripts/icm-check.sh %s\n' "$TARGET"
fi

printf '\n'
printf 'note read IDENTITY.md, then CONTEXT.md. they are the map.\n'
printf 'note folders that do real work still have no job card. run /icm-context to write them.\n'
printf 'note review the new files, then commit them: git add -A && git status\n'
printf 'note undo this exact run with: scripts/icm-rollback.sh --stamp %s %s\n' "$STAMP" "$TARGET"

if [ "$N_PARKED" -gt 0 ] || [ "$REFUSALS" -gt 0 ]; then
    if [ "$N_PARKED" -gt 0 ]; then
        printf 'warn nothing that collided was overwritten. read .icm/proposed/ and merge by hand.\n'
        printf 'warn each candidate has a .diff beside it: diff -u <path> .icm/proposed/<path>\n'
    fi
    if [ "$REFUSALS" -gt 0 ]; then
        printf 'warn %s path(s) were refused outright. nothing was written or proposed for them.\n' "$REFUSALS"
    fi
    printf 'result: a decision is waiting\n'
    exit 1
fi

printf 'result: clean\n'
exit 0
