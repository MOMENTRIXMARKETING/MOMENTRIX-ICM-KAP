#!/bin/sh
# icm-plan.sh - retrofit dry run.
#
# Two jobs, and only these two:
#   1. decide what installing the ICM layers would do to this target, and
#   2. walk the target's own tree and report which folders look like they want
#      a job card.
#
# It writes exactly one file: <target>/.icm/plan.txt. Nothing else in the target
# is created, modified or deleted, under any circumstances. Run this before
# icm-apply.sh, always.
#
# POSIX sh only. No bashisms. No python required.

set -e

usage() {
    cat <<'ICM_USAGE'
usage: icm-plan.sh [--archetype quick|full|wiki] [--allow-dirty] [--quiet]
                   [-h|--help] [target-dir]

Dry run. Prints the diff, then the survey of your own tree, and writes
<target>/.icm/plan.txt. target-dir defaults to the current directory.

  CREATE   the file is absent, apply would write it
  COLLIDE  apply must not write it, so apply would park a candidate in
           .icm/proposed/ and touch nothing
  ADOPT    your file is kept, apply would append a marked icm block and back
           the original up first
  SKIP     already installed and byte identical, apply would do nothing
  REFUSE   a never_write path, or a path that resolves outside the target
  SURVEY   a folder in your tree, and whether it looks like it wants a job card

Options:
  --archetype ID  which layer set to install. Default quick.
                    quick  Layers 0, 1 and 3: the map, the routing, the rule
                           books and the log. Nothing else. Earn complexity.
                    full   quick plus output/ for a staged pipeline.
                    wiki   full plus raw/ and wiki/, the Karpathy layers.
  --allow-dirty   plan even though the target is a git repo with uncommitted work
  --quiet         write the plan, print only the counts
  -h, --help      this text

Exit: 0 plan written and nothing needs a decision, 1 plan written with
collisions or refusals to decide, 2 refused (dirty repo, bad target, usage
error).
ICM_USAGE
}

ICM_SELF=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
ICM_HOME=$(cd -P -- "$ICM_SELF/.." && pwd -P)
. "$ICM_HOME/scripts/icm_lib.sh"

TARGET=""
ALLOW_DIRTY=0
QUIET=0
ARCHETYPE=quick

while [ $# -gt 0 ]; do
    case "$1" in
        --archetype)
            [ $# -ge 2 ] || { printf 'FAIL --archetype needs a value: quick, full or wiki\n' >&2; exit 2; }
            case "$2" in
                quick|full|wiki) ARCHETYPE=$2 ;;
                *) printf 'FAIL unknown archetype: %s\n' "$2" >&2
                   printf 'note pick one of: quick, full, wiki\n' >&2; exit 2 ;;
            esac
            shift ;;
        --archetype=*)
            case "${1#--archetype=}" in
                quick|full|wiki) ARCHETYPE=${1#--archetype=} ;;
                *) printf 'FAIL unknown archetype: %s\n' "${1#--archetype=}" >&2
                   printf 'note pick one of: quick, full, wiki\n' >&2; exit 2 ;;
            esac ;;
        --allow-dirty) ALLOW_DIRTY=1 ;;
        --quiet)       QUIET=1 ;;
        -h|--help)     usage; exit 0 ;;
        --apply|--rollback)
            printf 'FAIL %s is not a flag on plan.\n' "$1" >&2
            printf 'note plan only plans. to execute a plan, run: scripts/icm-apply.sh [target-dir]\n' >&2
            printf 'note to undo an apply, run: scripts/icm-rollback.sh [--stamp STAMP] [target-dir]\n' >&2
            exit 2
            ;;
        --*)           printf 'FAIL unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
        *)
            if [ -n "$TARGET" ]; then
                printf 'FAIL more than one target given: %s\n' "$1" >&2
                printf 'note plan takes one target directory. quote a path that has spaces in it.\n' >&2
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

# ------------------------------------------------------------------ refusals --

if icm_is_git_repo "$TARGET"; then
    if icm_git_dirty "$TARGET"; then
        if [ "$ALLOW_DIRTY" -eq 0 ]; then
            printf 'FAIL %s is a git repo with uncommitted changes.\n' "$TARGET" >&2
            printf 'note commit or stash first, so a retrofit is one reviewable diff:\n' >&2
            icm_git_dirty_list "$TARGET" | sed 's/^/     /' >&2
            printf 'note or rerun with --allow-dirty if you know what you are doing.\n' >&2
            exit 2
        fi
        printf 'warn target has uncommitted changes, --allow-dirty was given\n'
    fi
fi

# ----------------------------------------------------------------- the walk --

PLANDIR="$TARGET/.icm"
PLAN="$PLANDIR/plan.txt"
WORK="$ICM_TMPDIR/rows"
SURVEY="$ICM_TMPDIR/survey"
TAB=$(printf '\t')
: > "$WORK"
: > "$SURVEY"

row() {
    # row <status> <role> <relpath> <sha> <reason>
    printf '%s%s%s%s%s%s%s%s%s\n' \
        "$1" "$TAB" "$2" "$TAB" "$3" "$TAB" "$4" "$TAB" "$5" >> "$WORK"
}

ICM_ARCHETYPE="$ARCHETYPE"
export ICM_ARCHETYPE
icm_manifest "$ARCHETYPE" > "$ICM_TMPDIR/manifest"
while read -r ROLE RP REST; do
    [ -n "$ROLE" ] || continue
    [ -n "$RP" ] || continue

    if ! icm_never_write_ok "$RP"; then
        row REFUSE "$ROLE" "$RP" '-' \
            "never_write glob in icm.defaults.json ($(icm_never_write_hit "$RP"))"
        continue
    fi
    ESCAPE=$(icm_path_escape "$TARGET" "$RP") || true
    if [ -n "$ESCAPE" ]; then
        row REFUSE "$ROLE" "$RP" '-' "$ESCAPE"
        continue
    fi

    CAND="$ICM_TMPDIR/cand"
    icm_candidate "$RP" "$TARGET" > "$CAND"
    STATUS=$(icm_classify "$RP" "$TARGET" "$CAND")
    SHA=$(icm_sha "$CAND")
    REASON=$(icm_reason "$STATUS" "$RP" "$TARGET")
    row "$STATUS" "$ROLE" "$RP" "$SHA" "$REASON"
done < "$ICM_TMPDIR/manifest"

# ---------------------------------------------------------------- the survey --

icm_survey_rows "$TARGET" > "$SURVEY"

while IFS="$TAB" read -r S_RP S_V S_NF S_ND S_SIG S_AO; do
    [ -n "$S_RP" ] || continue
    row SURVEY '-' "$S_RP/" '-' \
        "survey: $S_V; files=$S_NF subfolders=$S_ND stage-signal=$S_SIG"
done < "$SURVEY"

# ------------------------------------------------------------- write the plan --

mkdir -p "$PLANDIR"
{
    printf '# icm plan\n'
    printf '# toolkit: %s %s\n' "$ICM_TOOLKIT" "$ICM_VERSION"
    printf '# defaults: %s\n' "$ICM_DEFAULTS"
    printf '# target: %s\n' "$TARGET"
    printf '# archetype: %s\n' "$ARCHETYPE"
    printf '# generated: %s\n' "$(icm_utc_iso)"
    printf '# format: STATUS%sROLE%sRELPATH%sCANDIDATE-SHA%sREASON\n' "$TAB" "$TAB" "$TAB" "$TAB"
    cat "$WORK"
} | icm_atomic_write "$PLAN"

# ---------------------------------------------------------------- the report --

n_of() {
    awk -F "$TAB" -v s="$1" '$1 == s { n++ } END { print n + 0 }' "$WORK"
}

section() {
    printf '\n%s\n' "$1"
    if awk -F "$TAB" -v s="$2" '$1 == s { f = 1 } END { exit f ? 0 : 1 }' "$WORK"; then
        awk -F "$TAB" -v s="$2" '$1 == s { printf "  %-34s %s\n", $3, $5 }' "$WORK"
    else
        printf '  (none)\n'
    fi
}

N_CREATE=$(n_of CREATE)
N_COLLIDE=$(n_of COLLIDE)
N_ADOPT=$(n_of ADOPT)
N_SKIP=$(n_of SKIP)
N_REFUSE=$(n_of REFUSE)
N_SURVEY=$(n_of SURVEY)

if [ "$QUIET" -eq 0 ]; then
    printf '# icm-plan (dry run, nothing was changed)\n'
    printf 'target:   %s\n' "$TARGET"
    printf 'defaults: %s\n' "$ICM_DEFAULTS"
    printf 'plan:     %s\n' "$PLAN"

    section 'CREATE - absent, apply would write these' CREATE
    section 'COLLIDE - apply parks a candidate and touches nothing' COLLIDE
    if [ "$N_COLLIDE" -gt 0 ]; then
        printf 'note diff each one with: diff -u <path> .icm/proposed/<path>\n'
        printf 'note or read the prepared diff at: .icm/proposed/<path>.diff\n'
    fi
    section 'ADOPT - your file is kept, apply appends a marked icm block and backs up the original first' ADOPT
    section 'SKIP - already installed and identical, apply would do nothing' SKIP
    if [ "$N_REFUSE" -gt 0 ]; then
        section 'REFUSE - apply will not write these at all' REFUSE
        printf 'note a refusal is not a collision. nothing is parked and nothing is proposed.\n'
    fi

    printf '\nSURVEY - folders in your tree, and whether they look like they want a job card\n\n'
    if [ "$N_SURVEY" -gt 0 ]; then
        printf '| %-30s | %-8s | %5s | %-12s | %s\n' \
            'Folder' 'Verdict' 'Files' 'Stage signal' 'Suggested next step'
        printf '|-%.30s-|-%.8s-|-%.5s-|-%.12s-|-%s\n' \
            '------------------------------' '--------' '-----' '------------' '--------------------'
        while IFS="$TAB" read -r S_RP S_V S_NF S_ND S_SIG S_AO; do
            [ -n "$S_RP" ] || continue
            case "$S_V" in
                has-card) STEP="job card already there, nothing to do" ;;
                staged|card)
                    case "$S_RP" in
                        *\ *) STEP="/icm-context one \"$S_RP\"" ;;
                        *)    STEP="/icm-context one $S_RP" ;;
                    esac
                    ;;
                *)
                    if [ "$S_AO" = yes ]; then
                        STEP="asset-only, nothing to route"
                    else
                        STEP="needs classification, ask the user"
                    fi
                    ;;
            esac
            printf '| %-30s | %-8s | %5s | %-12s | %s\n' "$S_RP/" "$S_V" "$S_NF" "$S_SIG" "$STEP"
        done < "$SURVEY"
        printf '\nnote a verdict is evidence, not a conclusion. a number in a folder name is a\n'
        printf 'note signal that it might be a stage; it is not proof that it is one.\n'
        printf 'note nothing above is written by apply. job cards are written one at a time\n'
        printf 'note with /icm-context, in conversation, and nothing moves by default.\n'
    else
        printf '  (no folders of your own to survey)\n'
    fi
    printf '\n'
fi

printf 'ok   plan written: %s\n' "$PLAN"
printf 'ok   CREATE %s   COLLIDE %s   ADOPT %s   SKIP %s   REFUSE %s   SURVEY %s\n' \
    "$N_CREATE" "$N_COLLIDE" "$N_ADOPT" "$N_SKIP" "$N_REFUSE" "$N_SURVEY"
printf 'note plan wrote only .icm/plan.txt. until you run apply, .icm/ is not in your\n'
printf 'note .gitignore, so git status will show it as untracked. nothing else in your\n'
printf 'note project changed.\n'

if [ "$N_COLLIDE" -gt 0 ]; then
    printf 'warn %s file(s) collide. apply will never overwrite them; it writes the\n' "$N_COLLIDE"
    printf 'warn candidate to .icm/proposed/ and leaves your file exactly as it is.\n'
    printf 'result: collisions to decide\n'
    exit 1
fi

if [ "$N_REFUSE" -gt 0 ]; then
    printf 'warn %s path(s) are refused outright. read the REFUSE section: apply writes\n' "$N_REFUSE"
    printf 'warn nothing there, and there is nothing parked for you to merge.\n'
    printf 'result: refusals to decide\n'
    exit 1
fi

printf 'result: clean\n'
exit 0
