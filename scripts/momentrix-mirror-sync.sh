#!/bin/sh
# MOMENTRIX MIRROR SYNC
# Desktop/MOMENTRIX -> Dropbox-Momentrix mirror. Additive. Never deletes on
# the mirror side. Local Desktop/MOMENTRIX is the one truth. This only
# pushes, it never pulls back.
# rsync is not used: the Dropbox CloudStorage provider breaks its temp
# file rename.
# POSIX sh only: the scheduled task and this toolkit both invoke these
# scripts with sh. Newline list, not null delimited: IFS= read -r keeps
# the spaces in folder names, and no filename in this tree carries a
# literal newline.
#
# On copy failure the exact cp error and a classified errno (EPERM,
# EACCES, EROFS, or unknown) are logged. A read-only destination is
# chmod u+w and retried. A Dropbox online-only (dataless) destination
# that still will not accept the write is reported clearly so a human
# can make it available offline.
#
# Install on the Mac (one line; Desktop is the live copy):
#   cp scripts/momentrix-mirror-sync.sh ~/Desktop/MOMENTRIX/16-TOOLS/momentrix-mirror-sync.sh && chmod +x ~/Desktop/MOMENTRIX/16-TOOLS/momentrix-mirror-sync.sh

L="${MIRROR_SRC:-$HOME/Desktop/MOMENTRIX}"
M="${MIRROR_DEST:-$HOME/Library/CloudStorage/Dropbox-Momentrix/Matty Mannion/DESKTOP-MOMENTRIX/MOMENTRIX}"
LOG="${MIRROR_LOG:-$L/_log/mirror-sync.log}"
TS=$(date "+%Y-%m-%d %H:%M")

log_line() {
    mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
    printf '%s\n' "$TS  $1" >> "$LOG"
}

classify_errno() {
    # Classify from cp's stderr text. POSIX sh has no access to errno itself.
    _ce_msg=$1
    case "$_ce_msg" in
        *"Operation not permitted"*) printf '%s' EPERM ;;
        *"Permission denied"*)       printf '%s' EACCES ;;
        *"Read-only file system"*)   printf '%s' EROFS ;;
        *"is a directory"*)          printf '%s' EISDIR ;;
        *"No such file"*)            printf '%s' ENOENT ;;
        *)                           printf '%s' unknown ;;
    esac
}

dest_flags() {
    if [ ! -e "$1" ]; then
        printf '%s' ""
        return 0
    fi
    # BSD/macOS stat. Linux GNU stat has no %Sf; ignore and return empty.
    stat -f '%Sf' "$1" 2>/dev/null || printf '%s' ""
}

dest_mode() {
    if [ ! -e "$1" ]; then
        printf '%s' ""
        return 0
    fi
    # BSD first, GNU fallback.
    stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null || printf '%s' ""
}

is_dataless() {
    case "$(dest_flags "$1")" in
        *dataless*) return 0 ;;
        *)          return 1 ;;
    esac
}

# Try cp -p, then plain cp. stdout/stderr of the successful form are discarded.
# On failure, _CP_ERR and _CP_RC are set from the last attempt.
try_cp() {
    _CP_ERR=""
    _CP_RC=0
    if cp -p "$1" "$2" 2>/dev/null; then
        return 0
    fi
    _CP_ERR=$(cp -p "$1" "$2" 2>&1)
    _CP_RC=$?
    if [ "$_CP_RC" -eq 0 ]; then
        return 0
    fi
    if cp "$1" "$2" 2>/dev/null; then
        return 0
    fi
    _CP_ERR=$(cp "$1" "$2" 2>&1)
    _CP_RC=$?
    if [ "$_CP_RC" -eq 0 ]; then
        return 0
    fi
    return 1
}

[ -d "$M" ] || { log_line "FAIL mirror path not found"; echo "FAIL mirror path not found" >&2; exit 1; }

LIST=$(mktemp "${TMPDIR:-/tmp}/mirror-sync.XXXXXX") || exit 1
trap 'rm -f "$LIST"' EXIT
COPIED=0
FAILED=0
cd "$L" || exit 1
find . -type f ! -name ".DS_Store" ! -name "._*" ! -path "./_to_delete/*" ! -path "*/node_modules/*" ! -path "*/.git/*" > "$LIST"
while IFS= read -r f; do
    t="$M/${f#./}"
    if [ ! -f "$t" ] || [ "$f" -nt "$t" ]; then
        mkdir -p "$(dirname "$t")" 2>/dev/null
        if try_cp "$f" "$t"; then
            COPIED=$((COPIED+1))
            continue
        fi
        # Dest may be read-only or a Dropbox dataless stub. chmod and retry.
        if [ -e "$t" ]; then
            chmod u+w "$t" 2>/dev/null || true
            if try_cp "$f" "$t"; then
                COPIED=$((COPIED+1))
                continue
            fi
        fi
        FAILED=$((FAILED+1))
        _eno=$(classify_errno "$_CP_ERR")
        _flags=$(dest_flags "$t")
        _mode=$(dest_mode "$t")
        _msg="FAILCOPY ${f#./}  exit=${_CP_RC:-?} errno=$_eno mode=${_mode:-?} flags=${_flags:-none}  ${_CP_ERR}"
        if is_dataless "$t"; then
            _msg="FAILCOPY ${f#./}  still dataless after chmod u+w; make the Dropbox copy available offline. exit=${_CP_RC:-?} errno=$_eno mode=${_mode:-?} flags=$_flags  ${_CP_ERR}"
        fi
        log_line "$_msg"
        printf '%s\n' "$TS  $_msg" >&2
    fi
done < "$LIST"

LC=$(find "$L" -type f ! -name "._*" ! -path "*/_to_delete/*" | wc -l | tr -d " ")
MC=$(find "$M" -type f ! -name "._*" | wc -l | tr -d " ")
log_line "synced $COPIED, failed $FAILED, tree $LC, mirror $MC"
echo "synced $COPIED, failed $FAILED, tree $LC, mirror $MC"
[ "$FAILED" -gt 0 ] && exit 2
exit 0
