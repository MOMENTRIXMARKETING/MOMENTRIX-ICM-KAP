#!/bin/sh
# icm-rollback.sh - the exact inverse of icm-apply.sh.
#
# Reads one apply manifest and undoes exactly what that run did:
#   MODIFIED  restored from the stored pre-image, with its mode, but only after
#             checking the file still holds the bytes apply left. Changed since
#             apply means a human has been in there: report and leave it alone.
#   CREATED   deleted, but only while still byte identical to what apply wrote.
#   PARKED    the parked candidate under .icm/proposed/ and its diff are
#             removed. Your file was never touched, so there is nothing to
#             restore.
#   MKDIR     the directory is removed, in reverse order, and only when this run
#             is the run that created it and it is now empty.
#   SKIPPED   that run did nothing to this path, so neither does this one.
#
# Running it twice is a no-op. Nothing a human edited is ever thrown away.
#
# POSIX sh only. No bashisms. No python required.

set -e

usage() {
    cat <<'ICM_USAGE'
usage: icm-rollback.sh [--stamp STAMP] [--list] [--force] [-h|--help] [target-dir]

Undoes one icm-apply.sh run. With no --stamp it takes the newest run that has
not already been rolled back. target-dir defaults to the current directory.

Options:
  --stamp STAMP  roll back this run (a directory name under .icm/backup/)
  --list         list the runs available to roll back, then stop
  --force        roll back even though the run is already marked rolled back
  -h, --help     this text

Exit: 0 fully undone or nothing to undo, 1 finished and a human decision is
waiting (a file you edited was kept, or a run is unusable), 2 refused (no
backup, bad stamp, usage error).
ICM_USAGE
}

ICM_SELF=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
ICM_HOME=$(cd -P -- "$ICM_SELF/.." && pwd -P)
. "$ICM_HOME/scripts/icm_lib.sh"

TARGET=""
STAMP=""
LIST=0
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --stamp)   shift; [ $# -gt 0 ] || icm_die "--stamp needs a value"; STAMP="$1" ;;
        --list)    LIST=1 ;;
        --force)   FORCE=1 ;;
        --plan)
            printf 'FAIL --plan is not a flag on rollback.\n' >&2
            printf 'note rollback reads a manifest, not a plan. pick a run with --stamp STAMP.\n' >&2
            printf 'note to execute a plan, run: scripts/icm-apply.sh [--plan FILE] [target-dir]\n' >&2
            exit 2
            ;;
        --dry-run)
            printf 'FAIL --dry-run is not a flag on rollback.\n' >&2
            printf 'note to see what a run did before undoing it, read its manifest:\n' >&2
            printf 'note   .icm/backup/<STAMP>/manifest.txt, listed by: scripts/icm-rollback.sh --list\n' >&2
            printf 'note --dry-run is a flag on scripts/icm-apply.sh.\n' >&2
            exit 2
            ;;
        -h|--help) usage; exit 0 ;;
        --*)       printf 'FAIL unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
        *)
            if [ -n "$TARGET" ]; then
                printf 'FAIL more than one target given: %s\n' "$1" >&2
                printf 'note rollback takes one target directory. quote a path that has spaces in it.\n' >&2
                exit 2
            fi
            TARGET="$1"
            ;;
    esac
    shift
done

[ -n "$TARGET" ] || TARGET="."
TARGET=$(icm_require_target "$TARGET") || exit 2

icm_init "$TARGET"
icm_trap_default

TAB=$(printf '\t')

BACKROOT="$TARGET/.icm/backup"
if [ ! -d "$BACKROOT" ]; then
    printf 'note no %s, there is nothing to roll back\n' "$BACKROOT"
    printf 'result: clean\n'
    exit 0
fi

RUNS="$ICM_TMPDIR/runs"
icm_top_entries "$BACKROOT" | sort > "$RUNS"

run_state() {
    # run_state <stamp> -> usable | interrupted | unusable | undone
    if [ -f "$BACKROOT/$1/ROLLED-BACK" ]; then
        printf 'undone\n'
    elif [ ! -f "$BACKROOT/$1/manifest.txt" ]; then
        printf 'unusable\n'
    elif [ ! -f "$BACKROOT/$1/COMPLETE" ]; then
        printf 'interrupted\n'
    else
        printf 'usable\n'
    fi
}

if [ "$LIST" -eq 1 ]; then
    printf '# icm-rollback runs under %s\n' "$BACKROOT"
    N_LISTED=0
    while IFS= read -r R; do
        [ -n "$R" ] || continue
        [ -d "$BACKROOT/$R" ] || continue
        N_LISTED=$((N_LISTED + 1))
        case "$(run_state "$R")" in
            undone)      printf 'note %s  (already rolled back)\n' "$R" ;;
            unusable)    printf 'warn %s  (incomplete run, no manifest, cannot be rolled back)\n' "$R" ;;
            interrupted) printf 'ok   %s  (interrupted run, no COMPLETE marker; rollback will replay it)\n' "$R" ;;
            *)           printf 'ok   %s\n' "$R" ;;
        esac
    done < "$RUNS"
    if [ "$N_LISTED" -eq 0 ]; then
        printf 'note no runs are recorded here\n'
    fi
    exit 0
fi

# Pick the newest run that can still be undone. A run with a manifest and no
# COMPLETE is an interrupted apply, which is exactly the case rollback exists
# for; it is never treated as a run that does not exist.
UNUSABLE=0
if [ -z "$STAMP" ]; then
    while IFS= read -r R; do
        [ -n "$R" ] || continue
        [ -d "$BACKROOT/$R" ] || continue
        case "$(run_state "$R")" in
            unusable)
                UNUSABLE=$((UNUSABLE + 1))
                continue
                ;;
            undone)
                if [ "$FORCE" -eq 0 ]; then continue; fi
                ;;
        esac
        STAMP="$R"
    done < "$RUNS"
fi

if [ -z "$STAMP" ]; then
    if [ "$UNUSABLE" -gt 0 ]; then
        printf 'FAIL %s run(s) under %s have no manifest, so nothing can be undone from them\n' \
            "$UNUSABLE" "$BACKROOT" >&2
        printf 'note list them with: scripts/icm-rollback.sh --list %s\n' "$TARGET" >&2
        printf 'note a run with no manifest was killed before it wrote one. check git, or\n' >&2
        printf 'note remove the files that run created by hand.\n' >&2
        printf 'result: a decision is waiting\n'
        exit 1
    fi
    printf 'note every recorded run under %s is already rolled back\n' "$BACKROOT"
    printf 'result: clean\n'
    exit 0
fi

RUNDIR="$BACKROOT/$STAMP"
MANIFEST="$RUNDIR/manifest.txt"
if [ ! -d "$RUNDIR" ]; then
    printf 'FAIL no run %s under %s\n' "$STAMP" "$BACKROOT" >&2
    printf 'note run with --list to see what is available.\n' >&2
    exit 2
fi
if [ ! -f "$MANIFEST" ]; then
    printf 'FAIL no manifest at %s\n' "$MANIFEST" >&2
    printf 'note that run was killed before it recorded anything, so there is nothing to\n' >&2
    printf 'note replay. run with --list to see what is available.\n' >&2
    exit 2
fi
if [ -f "$RUNDIR/ROLLED-BACK" ] && [ "$FORCE" -eq 0 ]; then
    printf 'note run %s was already rolled back on %s\n' "$STAMP" "$(cat "$RUNDIR/ROLLED-BACK")"
    printf 'result: clean\n'
    exit 0
fi

MAN_TARGET=$(sed -n 's/^# target: //p' "$MANIFEST" | head -n 1 | tr -d "$(printf '\r')")
if [ -n "$MAN_TARGET" ] && [ "$MAN_TARGET" != "$TARGET" ]; then
    printf 'FAIL that manifest belongs to [%s], not [%s]\n' "$MAN_TARGET" "$TARGET" >&2
    exit 2
fi

printf '# icm-rollback\n'
printf 'target:   %s\n' "$TARGET"
printf 'run:      %s\n' "$STAMP"
printf 'manifest: %s\n' "$MANIFEST"
if [ ! -f "$RUNDIR/COMPLETE" ]; then
    printf 'warn that apply run never finished; it has no COMPLETE marker.\n'
    printf 'warn replaying what it did record. anything it wrote after its last row is not\n'
    printf 'warn in the manifest and will be left alone.\n'
fi
printf '\n'

MAN_SHA=$(sed -n 's/^# sha-mode: //p' "$MANIFEST" | head -n 1)
icm_sha_init
if [ -n "$MAN_SHA" ] && [ "$MAN_SHA" != "$ICM_SHA_MODE" ]; then
    printf 'warn the run was recorded with sha-mode %s, this machine has %s.\n' "$MAN_SHA" "$ICM_SHA_MODE"
    printf 'warn hashes will not compare, so nothing will be deleted or restored.\n'
fi

LEFT=0
BROKEN=0
DONE=0
GITMOD="$ICM_TMPDIR/gitmod"
GITNEW="$ICM_TMPDIR/gitnew"
KEPT="$ICM_TMPDIR/kept"
MKDIRS="$ICM_TMPDIR/mkdirs"
SEEN="$ICM_TMPDIR/seen"
: > "$GITMOD"
: > "$GITNEW"
: > "$KEPT"
: > "$MKDIRS"
: > "$SEEN"

# Every removal and every restore is checked for containment first. A manifest
# is a file on disk and a file on disk can be edited.
inside_target() {
    _it_par=$(icm_parent_real "$TARGET/$1")
    [ -n "$_it_par" ] || return 1
    icm_under "$_it_par" "$TARGET"
}

# A manifest with two rows for one path is corrupt. After the first FAIL for a
# path, later rows for that same path are not processed.
path_failed() {
    awk -v p="$1" '$0 == p { f = 1 } END { exit f ? 0 : 1 }' "$SEEN"
}

mark_failed() {
    printf '%s\n' "$1" >> "$SEEN"
}

while IFS="$TAB" read -r ACTION RP PRE POST MODE; do
    case "$ACTION" in
        '#'*|'') continue ;;
    esac
    [ -n "$RP" ] || continue
    DEST="$TARGET/$RP"

    if [ "$ACTION" != MKDIR ] && path_failed "$RP"; then
        printf 'FAIL %s appears twice in this manifest; that manifest is corrupt, stopping on it\n' "$RP"
        BROKEN=$((BROKEN + 1))
        continue
    fi

    case "$ACTION" in
        MKDIR)
            printf '%s\n' "$RP" >> "$MKDIRS"
            ;;
        CREATED)
            if [ ! -e "$DEST" ] && [ ! -L "$DEST" ]; then
                printf 'note %s is already gone\n' "$RP"
                continue
            fi
            if ! inside_target "$RP"; then
                printf 'FAIL %s resolves outside %s, refusing to remove it\n' "$RP" "$TARGET"
                BROKEN=$((BROKEN + 1))
                mark_failed "$RP"
                continue
            fi
            NOW=$(icm_sha "$DEST")
            if [ "$NOW" = "$POST" ]; then
                rm -f "$DEST"
                printf '%s\n' "$RP" >> "$GITNEW"
                printf 'ok   removed  %s\n' "$RP"
                DONE=$((DONE + 1))
            else
                printf 'warn kept     %s has been edited since apply, it is yours now\n' "$RP"
                printf 'note %s was kept because you edited it. keep it, or delete it by hand and\n' "$RP"
                printf 'note rerun to close the run.\n'
                printf '%s\n' "$RP" >> "$KEPT"
                LEFT=$((LEFT + 1))
            fi
            ;;
        MODIFIED)
            PREIMG="$RUNDIR/files/$RP"
            if [ "$PRE" = "$POST" ]; then
                # A single correct run cannot produce this: icm_classify returns
                # SKIP whenever the candidate already equals the file, so an
                # ADOPT only happens when the content differs. Equal hashes mean
                # the stored pre-image is the post-apply file.
                printf 'FAIL %s has a pre-image hash equal to its post-apply hash. that pre-image is\n' "$RP"
                printf 'FAIL not your original, so restoring it would write the toolkit output back.\n'
                printf 'note look for your original in an earlier run: scripts/icm-rollback.sh --list %s\n' "$TARGET"
                BROKEN=$((BROKEN + 1))
                mark_failed "$RP"
                continue
            fi
            if [ ! -f "$PREIMG" ]; then
                printf 'FAIL no pre-image for %s at %s, refusing to guess\n' "$RP" "$PREIMG"
                BROKEN=$((BROKEN + 1))
                mark_failed "$RP"
                continue
            fi
            if ! inside_target "$RP"; then
                printf 'FAIL %s resolves outside %s, refusing to write it\n' "$RP" "$TARGET"
                BROKEN=$((BROKEN + 1))
                mark_failed "$RP"
                continue
            fi
            PRENOW=$(icm_sha "$PREIMG")
            if [ "$PRENOW" != "$PRE" ]; then
                printf 'FAIL the stored pre-image of %s does not match its recorded hash, refusing\n' "$RP"
                BROKEN=$((BROKEN + 1))
                mark_failed "$RP"
                continue
            fi
            if [ ! -e "$DEST" ]; then
                printf 'warn %s is gone; restoring the pre-image\n' "$RP"
                icm_atomic_write "$DEST" "$MODE" < "$PREIMG"
                printf '%s\n' "$RP" >> "$GITMOD"
                printf 'ok   restored %s\n' "$RP"
                DONE=$((DONE + 1))
                continue
            fi
            if [ -L "$DEST" ] || [ ! -f "$DEST" ]; then
                printf 'FAIL %s is no longer a regular file, refusing to write through it\n' "$RP"
                BROKEN=$((BROKEN + 1))
                mark_failed "$RP"
                continue
            fi
            NOW=$(icm_sha "$DEST")
            if [ "$NOW" != "$POST" ]; then
                printf 'warn kept     %s changed after apply (now %s, apply left %s), it is yours now\n' \
                    "$RP" "$NOW" "$POST"
                printf 'note %s was kept because you edited it. keep it, or restore the pre-image by\n' "$RP"
                printf 'note hand from .icm/backup/%s/files/%s and rerun to close the run.\n' "$STAMP" "$RP"
                printf '%s\n' "$RP" >> "$KEPT"
                LEFT=$((LEFT + 1))
                continue
            fi
            icm_atomic_write "$DEST" "$MODE" < "$PREIMG"
            printf '%s\n' "$RP" >> "$GITMOD"
            printf 'ok   restored %s from its pre-image\n' "$RP"
            DONE=$((DONE + 1))
            ;;
        PARKED|COLLIDE)
            PROP="$TARGET/.icm/proposed/$RP"
            if [ ! -e "$PROP" ]; then
                printf 'note the candidate for %s is already gone; your file was never touched\n' "$RP"
                rm -f "$PROP.diff"
                continue
            fi
            NOW=$(icm_sha "$PROP")
            if [ "$NOW" = "$POST" ]; then
                rm -f "$PROP" "$PROP.diff"
                _pdir=$(dirname -- "$PROP")
                case "$_pdir" in
                    "$TARGET/.icm/proposed"/*) rmdir "$_pdir" 2>/dev/null || true ;;
                esac
                printf 'ok   dropped  the parked candidate for %s\n' "$RP"
                DONE=$((DONE + 1))
            else
                printf 'warn kept     .icm/proposed/%s has been edited, leaving it\n' "$RP"
                printf 'note .icm/proposed/%s was kept because you edited it. merge it into your file,\n' "$RP"
                printf 'note or delete it by hand and rerun to close the run.\n'
                printf '%s\n' ".icm/proposed/$RP" >> "$KEPT"
                LEFT=$((LEFT + 1))
            fi
            ;;
        SKIPPED|SKIP)
            printf 'note %s was untouched by that run\n' "$RP"
            ;;
    esac
done < "$MANIFEST"

# Directories, last and in reverse, and only the ones this run made. A blind
# rmdir of every parent deletes a user's own pre-existing empty wiki/, raw/ or
# output/ and then calls the result clean.
if [ -s "$MKDIRS" ]; then
    sed -n '1!G;h;$p' "$MKDIRS" > "$ICM_TMPDIR/mkdirs.rev"
    while IFS= read -r D; do
        [ -n "$D" ] || continue
        DDIR="$TARGET/$D"
        [ -d "$DDIR" ] || continue
        _dpar=$(icm_parent_real "$DDIR")
        if [ -z "$_dpar" ] || ! icm_under "$_dpar" "$TARGET"; then
            printf 'FAIL %s resolves outside %s, refusing to remove it\n' "$D" "$TARGET"
            BROKEN=$((BROKEN + 1))
            continue
        fi
        if rmdir "$DDIR" 2>/dev/null; then
            printf 'ok   removed  %s/\n' "$D"
        else
            printf 'note %s/ is not empty, so it stays\n' "$D"
        fi
    done < "$ICM_TMPDIR/mkdirs.rev"
fi

if [ "$LEFT" -eq 0 ] && [ "$BROKEN" -eq 0 ]; then
    icm_utc_iso > "$RUNDIR/ROLLED-BACK"
fi

printf '\nok   undone %s   left alone %s\n' "$DONE" "$LEFT"

if icm_is_git_repo "$TARGET"; then
    if [ -s "$GITMOD" ] || [ -s "$GITNEW" ] || [ -s "$KEPT" ]; then
        printf '\nnote git holds the other copy of the truth. compare what is there now with:\n'
        printf 'note   git -C %s status --porcelain\n' "$TARGET"
    fi
    if [ -s "$KEPT" ]; then
        printf 'note these were kept for you, because you edited them after apply:\n'
        while IFS= read -r G; do
            [ -n "$G" ] || continue
            printf 'note   %s\n' "$G"
        done < "$KEPT"
        printf 'note nothing above was removed. deleting them is your call, not a verification\n'
        printf 'note step, and git clean would take the edit with it.\n'
    fi
fi

if [ "$BROKEN" -gt 0 ]; then
    printf 'warn %s row(s) could not be undone safely. nothing was guessed at.\n' "$BROKEN"
    printf 'result: incomplete\n'
    exit 1
fi

if [ "$LEFT" -gt 0 ]; then
    printf 'ok   everything this run did was undone except %s path(s) you edited, which were\n' "$LEFT"
    printf 'ok   kept on purpose. that is the tool doing its job, not a failure.\n'
    printf 'result: complete, %s kept\n' "$LEFT"
    exit 1
fi

printf 'result: clean\n'
exit 0
