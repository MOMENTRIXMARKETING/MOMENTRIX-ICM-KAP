#!/bin/bash
# Nightly ICM-KAP check, 10:59pm via launchd.
# Pull-only: fetches/pulls from GitHub into both toolkit clones, NEVER pushes.
# Writes to the live Desktop/MOMENTRIX _log/ directory.
#
# Exit 0 only when every step succeeded. Any failed step, and any
# "Operation not permitted" (TCC / Full Disk Access), exits non-zero so
# launchd records a red last-exit instead of a false green.
#
# Paths can be overridden with environment variables for tests and for a
# non-default home. Defaults are Matty's MacBook-Pro-2 layout.
#
# Install (one line, on the Mac; do not reload launchd, the next 22:59 run
# picks this up):
#   cp launchd/momentrix_icm_kap_nightly.bash ~/scripts/momentrix_icm_kap_nightly.sh && chmod +x ~/scripts/momentrix_icm_kap_nightly.sh

set -u

HOME_DIR="${MOMENTRIX_HOME:-$HOME}"
TOOLKIT_DESKTOP="${TOOLKIT_DESKTOP:-$HOME_DIR/Desktop/LAPTOP CODING BRAIN/momentrix-icm-kap-toolkit}"
TOOLKIT_DROPBOX="${TOOLKIT_DROPBOX:-$HOME_DIR/Library/CloudStorage/Dropbox-Momentrix/Matty Mannion/CODE/momentrix-icm-kap-toolkit}"
# Desktop is the write folder. The Dropbox tree is the mirror, not the live workspace.
LIVE_WORKSPACE="${LIVE_WORKSPACE:-$HOME_DIR/Desktop/MOMENTRIX}"
LIVE_LOG_DIR="${LIVE_LOG_DIR:-$LIVE_WORKSPACE/_log}"
SKILLS_DIR="${SKILLS_DIR:-$LIVE_WORKSPACE/15-SKILLS}"
# Real sync script, not the TOOLS/ shim.
MIRROR_SYNC_SCRIPT="${MIRROR_SYNC_SCRIPT:-$LIVE_WORKSPACE/16-TOOLS/momentrix-mirror-sync.sh}"
RUNLOG="${RUNLOG:-$LIVE_LOG_DIR/NIGHTLY-ICM-KAP-CHECK-RUNLOG.md}"
PROBLEMLOG="${PROBLEMLOG:-$LIVE_LOG_DIR/NIGHTLY-ICM-KAP-CHECK-PROBLEMS.md}"

now="$(date +"%Y-%m-%d %H:%M")"
problems=()
desktop_head=""
dropbox_head=""
saw_eperm=0

notify() {
    osascript -e "display notification \"$1\" with title \"ICM-KAP Nightly Check\"" >/dev/null 2>&1 || true
}

add_problem() {
    problems+=("$1")
    case "$1" in
        *"Operation not permitted"*|*"Operation not permitted")
            saw_eperm=1
            ;;
    esac
}

# check_repo <path> <label> <outvar>
# Pull-only: fetches origin, fast-forwards only when the tree is clean.
# Never commits, never pushes.
check_repo() {
    local path="$1" label="$2"
    local outvar="$3"

    if [ ! -d "$path/.git" ]; then
        add_problem "$label: not a git repo at $path"
        return
    fi

    local fetch_err fetch_rc
    fetch_err="$(cd "$path" && git fetch origin 2>&1 1>/dev/null)"
    fetch_rc=$?
    if [ "$fetch_rc" -ne 0 ]; then
        add_problem "$label: git fetch failed — $fetch_err"
        return
    fi

    local dirty
    dirty="$(cd "$path" && git status --porcelain)"

    local counts
    counts="$(cd "$path" && git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)"
    local behind ahead
    behind="$(echo "$counts" | awk '{print $1}')"
    ahead="$(echo "$counts" | awk '{print $2}')"

    if [ -n "$dirty" ]; then
        local n
        n="$(echo "$dirty" | wc -l | tr -d ' ')"
        add_problem "$label: $n uncommitted local change(s) — left untouched, commit/push by hand if intended"
    fi

    if [ -n "$ahead" ] && [ "$ahead" -gt 0 ]; then
        add_problem "$label: $ahead commit(s) ahead of origin/main — this job never pushes, push by hand"
    fi

    if [ -n "$behind" ] && [ "$behind" -gt 0 ]; then
        if [ -z "$dirty" ] && { [ -z "$ahead" ] || [ "$ahead" -eq 0 ]; }; then
            local pull_err pull_rc
            pull_err="$(cd "$path" && git pull --ff-only 2>&1 1>/dev/null)"
            pull_rc=$?
            if [ "$pull_rc" -ne 0 ]; then
                add_problem "$label: $behind commit(s) behind origin, fast-forward pull failed — $pull_err"
            fi
        else
            add_problem "$label: $behind commit(s) behind origin but not fast-forwarded (dirty tree or local commits ahead)"
        fi
    fi

    local head
    head="$(cd "$path" && git rev-parse HEAD 2>/dev/null)"
    printf -v "$outvar" '%s' "$head"
}

# --- whole-of-MOMENTRIX mirror: Desktop -> Dropbox, additive only ---
mirror_summary=""
if [ ! -x "$MIRROR_SYNC_SCRIPT" ]; then
    add_problem "Mirror sync script missing or not executable: $MIRROR_SYNC_SCRIPT"
else
    mirror_out="$("$MIRROR_SYNC_SCRIPT" 2>&1)"
    mirror_rc=$?
    mirror_summary="$mirror_out"
    if [ "$mirror_rc" -ne 0 ]; then
        add_problem "Desktop/MOMENTRIX -> Dropbox mirror had failures: $mirror_out"
    fi
    case "$mirror_out" in
        *"Operation not permitted"*)
            add_problem "Desktop/MOMENTRIX -> Dropbox mirror: Operation not permitted"
            ;;
    esac
fi

# --- git clones: pull-only, never push ---
check_repo "$TOOLKIT_DESKTOP" "Desktop toolkit" desktop_head
check_repo "$TOOLKIT_DROPBOX" "Dropbox toolkit clone" dropbox_head

if [ -n "$desktop_head" ] && [ -n "$dropbox_head" ] && [ "$desktop_head" != "$dropbox_head" ]; then
    add_problem "Toolkit clones out of sync: Desktop=$desktop_head Dropbox=$dropbox_head"
fi

# --- live workspace: 15-SKILLS is the live skills folder (not SKILLS/_LOGS) ---
if [ ! -d "$LIVE_WORKSPACE" ]; then
    add_problem "Live workspace not found at $LIVE_WORKSPACE"
else
    if [ ! -f "$LIVE_LOG_DIR/LOOP-LEDGER.md" ]; then
        add_problem "LOOP-LEDGER.md missing from $LIVE_LOG_DIR"
    fi
    if [ ! -d "$SKILLS_DIR" ]; then
        add_problem "Skills dir missing: $SKILLS_DIR"
    fi
fi

# --- write run log (always) and problem log (only on problems) ---
mkdir -p "$LIVE_LOG_DIR" 2>/dev/null || add_problem "Could not create log dir: $LIVE_LOG_DIR"

if [ "${#problems[@]}" -eq 0 ]; then
    echo "- ${now}  nightly ICM-KAP check OK — mirror: ${mirror_summary:-skipped}; both toolkit clones pulled clean and in sync, live workspace logs present" >> "$RUNLOG" 2>/dev/null \
        || add_problem "Could not write $RUNLOG"
else
    echo "- ${now}  nightly ICM-KAP check found ${#problems[@]} issue(s) (mirror: ${mirror_summary:-skipped}), see NIGHTLY-ICM-KAP-CHECK-PROBLEMS.md" >> "$RUNLOG" 2>/dev/null \
        || true
    {
        echo "## ${now}"
        for p in "${problems[@]}"; do
            echo "- $p"
        done
        echo
    } >> "$PROBLEMLOG" 2>/dev/null || true
    notify "${#problems[@]} issue(s) found — check NIGHTLY-ICM-KAP-CHECK-PROBLEMS.md. Nothing was pushed to GitHub."
fi

# Re-count in case a log write itself failed after the empty check.
if [ "${#problems[@]}" -eq 0 ]; then
    exit 0
fi
if [ "$saw_eperm" -ne 0 ]; then
    exit 2
fi
exit 1
