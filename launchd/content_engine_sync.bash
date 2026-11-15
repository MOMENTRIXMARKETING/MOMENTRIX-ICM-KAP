#!/bin/bash
# Weekday 05:30 launchd job: sync Desktop/MOMENTRIX/09-MARKETING/CONTENT-ENGINE
# with the BRAIN checkout at ~/Projects/brain-content-sync.
#
# cp and find failures, including "Operation not permitted" (TCC), fail the
# job. "ok down=N" is only logged for copies that actually succeeded.
#
# Install (one line, on the Mac; do not reload launchd, the next weekday
# 05:30 run picks this up):
#   cp launchd/content_engine_sync.bash ~/scripts/content_engine_sync.sh && chmod +x ~/scripts/content_engine_sync.sh

set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

HOME_DIR="${MOMENTRIX_HOME:-$HOME}"
REPO="${REPO:-$HOME_DIR/Projects/brain-content-sync}"
REL="departments/marketing/CONTENT-ENGINE"
DESK="${DESK:-$HOME_DIR/Desktop/MOMENTRIX/09-MARKETING/CONTENT-ENGINE}"
BASE="${BASE:-$HOME_DIR/scripts/content_engine_sync.base}"
LOG="${LOG:-$HOME_DIR/scripts/content_engine_sync.log}"
BRANCH="${BRANCH:-content-sync-desktop}"
GH_REPO="${GH_REPO:-MOMENTRIXSALES/MOMENTRIX-BRAIN}"
DRY="${DRY_RUN:-0}"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

fail() {
    echo "FAIL $*" >&2
    log "FAIL $*"
    exit 1
}

# Fail closed on Operation not permitted, and on any other find error.
# find can print some paths and still exit non-zero (or zero) when a directory
# is TCC-blocked, so stderr is checked either way.
run_find_print0() {
    local root="$1" out="$2" err="$3"
    local rc=0
    find "$root" -type f -print0 >"$out" 2>"$err" || rc=$?
    if grep -q "Operation not permitted" "$err"; then
        cat "$err" >&2
        fail "find $root: Operation not permitted"
    fi
    if [ "$rc" -ne 0 ]; then
        cat "$err" >&2
        fail "find $root (exit $rc)"
    fi
}

safe_cp() {
    local src="$1" dest="$2" err
    err="$(mktemp)" || fail "mktemp"
    if ! cp "$src" "$dest" 2>"$err"; then
        if grep -q "Operation not permitted" "$err"; then
            cat "$err" >&2
            rm -f "$err"
            fail "cp $dest: Operation not permitted"
        fi
        cat "$err" >&2
        local msg
        msg="$(tr '\n' ' ' <"$err")"
        rm -f "$err"
        fail "cp $dest: $msg"
    fi
    rm -f "$err"
}

cd "$REPO" || fail "no clone at $REPO"
git fetch -q origin || fail "git fetch"
git checkout -q -B main origin/main && git reset -q --hard origin/main && git clean -fdq
BRAIN="$REPO/$REL"
[ -d "$BRAIN" ] || fail "$REL missing on main"
mkdir -p "$DESK" || fail "mkdir $DESK"
[ -d "$BASE" ] || { mkdir -p "$BASE"; rsync -a --delete --exclude .DS_Store "$BRAIN/" "$BASE/"; log "baseline set from main"; }

FIND_DESK="$(mktemp)" FIND_BRAIN="$(mktemp)" FIND_BASE="$(mktemp)"
FIND_ERR="$(mktemp)"
trap 'rm -f "$FIND_DESK" "$FIND_BRAIN" "$FIND_BASE" "$FIND_ERR"' EXIT

run_find_print0 "$DESK" "$FIND_DESK" "$FIND_ERR"

UP=()
while IFS= read -r -d '' f; do
    rel="${f#"$DESK"/}"
    case "$(basename "$f")" in .DS_Store|.gitkeep) continue ;; esac
    if [ ! -f "$BASE/$rel" ] || ! cmp -s "$f" "$BASE/$rel"; then
        if [ ! -f "$BRAIN/$rel" ] || ! cmp -s "$f" "$BRAIN/$rel"; then UP+=("$rel"); fi
    fi
done < "$FIND_DESK"

isUp() { local x; for x in "${UP[@]+"${UP[@]}"}"; do [ "$x" = "$1" ] && return 0; done; return 1; }

run_find_print0 "$BRAIN" "$FIND_BRAIN" "$FIND_ERR"

DOWN=0
while IFS= read -r -d '' f; do
    rel="${f#"$BRAIN"/}"
    isUp "$rel" && continue
    if [ ! -f "$DESK/$rel" ] || ! cmp -s "$f" "$DESK/$rel"; then
        if [ "$DRY" != "1" ]; then
            mkdir -p "$(dirname "$DESK/$rel")" || fail "mkdir $(dirname "$DESK/$rel")"
            safe_cp "$f" "$DESK/$rel"
        fi
        DOWN=$((DOWN + 1))
    fi
done < "$FIND_BRAIN"

run_find_print0 "$BASE" "$FIND_BASE" "$FIND_ERR"

GONE=0
while IFS= read -r -d '' f; do
    rel="${f#"$BASE"/}"
    [ -f "$BRAIN/$rel" ] && continue
    isUp "$rel" && continue
    if [ -f "$DESK/$rel" ] && cmp -s "$f" "$DESK/$rel"; then
        if [ "$DRY" != "1" ]; then
            rm -f "$DESK/$rel" || fail "rm $DESK/$rel"
        fi
        GONE=$((GONE + 1))
    fi
done < "$FIND_BASE"

while IFS= read -r d; do
    mkdir -p "$DESK/${d#"$BRAIN"}" || fail "mkdir $DESK/${d#"$BRAIN"}"
done < <(find "$BRAIN" -type d)

[ "$DRY" != "1" ] && rsync -a --delete --exclude .DS_Store "$BRAIN/" "$BASE/"

if [ "${#UP[@]}" -gt 0 ] && [ "$DRY" != "1" ]; then
    git checkout -q -B "$BRANCH" origin/main
    for rel in "${UP[@]}"; do
        mkdir -p "$(dirname "$BRAIN/$rel")"
        safe_cp "$DESK/$rel" "$BRAIN/$rel"
        git add "$REL/$rel"
    done
    git commit -qm "content sync: Desktop drops and edits $(date +%F)" && git push -q -f origin "$BRANCH" || fail "push $BRANCH"
    if ! gh pr list --repo "$GH_REPO" --head "$BRANCH" --state open --json number --jq '.[0].number' | grep -q .; then
        gh pr create --repo "$GH_REPO" --base main --head "$BRANCH" --title "CONTENT SYNC: Desktop drops and edits" --body "Weekday morning sync from Desktop/MOMENTRIX/09-MARKETING/CONTENT-ENGINE. New ideas and edits made on the Desktop, waiting for Matty's merge. Nothing sends." >/dev/null || fail "pr create"
    fi
    git checkout -q main
fi

log "ok up=${#UP[@]} down=$DOWN gone=$GONE dry=$DRY ${UP[*]+${UP[*]}}"
exit 0
