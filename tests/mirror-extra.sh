#!/bin/sh
# Extra suite for scripts/momentrix-mirror-sync.sh. Sourced from run-tests.sh.

SYNC="$ROOT/scripts/momentrix-mirror-sync.sh"

printf '\n%s\n' '-- momentrix-mirror-sync --'

run sh -n "$SYNC"
assert_rc "mirror-sync passes sh -n" 0
if command -v dash >/dev/null 2>&1; then
    run dash -n "$SYNC"
    assert_rc "mirror-sync passes dash -n" 0
fi

# --- happy path: new file is copied, additive ---
MS=$(fixture t-mirror-ok)
mkdir -p "$MS/src/_log" "$MS/src/09-MARKETING" "$MS/dest"
printf 'hello\n' > "$MS/src/09-MARKETING/NOTE.md"
printf 'keep me\n' > "$MS/dest/already.md"
run env MIRROR_SRC="$MS/src" MIRROR_DEST="$MS/dest" MIRROR_LOG="$MS/src/_log/mirror-sync.log" sh "$SYNC"
assert_rc "mirror-sync exits 0 when every copy succeeds" 0
assert_out "mirror-sync prints a synced summary" "failed 0"
assert_file "mirror-sync copied the new file" "$MS/dest/09-MARKETING/NOTE.md"
assert_file "mirror-sync left an existing dest-only file in place (additive)" "$MS/dest/already.md"

# --- read-only dest: chmod u+w and retry, should succeed ---
MR=$(fixture t-mirror-ro)
mkdir -p "$MR/src/_log" "$MR/src/04-STRUCTURE" "$MR/dest/04-STRUCTURE"
printf 'new content\n' > "$MR/src/04-STRUCTURE/THE_STRUCTURE.txt"
printf 'old content\n' > "$MR/dest/04-STRUCTURE/THE_STRUCTURE.txt"
# Make dest older and read-only.
touch -t 202601010101 "$MR/dest/04-STRUCTURE/THE_STRUCTURE.txt"
chmod 444 "$MR/dest/04-STRUCTURE/THE_STRUCTURE.txt"
run env MIRROR_SRC="$MR/src" MIRROR_DEST="$MR/dest" MIRROR_LOG="$MR/src/_log/mirror-sync.log" sh "$SYNC"
assert_rc "mirror-sync retries a read-only dest after chmod u+w" 0
if grep -q "new content" "$MR/dest/04-STRUCTURE/THE_STRUCTURE.txt"; then
    t_pass "read-only dest was overwritten after chmod u+w"
else
    t_fail "read-only dest was overwritten after chmod u+w" "$(ls -l "$MR/dest/04-STRUCTURE/THE_STRUCTURE.txt"; cat "$MR/src/_log/mirror-sync.log")"
fi

# --- dest tree is not writable: copy fails, error is logged not swallowed ---
MF=$(fixture t-mirror-fail)
mkdir -p "$MF/src/_log" "$MF/src/09-MARKETING" "$MF/dest"
printf 'payload\n' > "$MF/src/09-MARKETING/NOTE.md"
chmod 555 "$MF/dest"
run env MIRROR_SRC="$MF/src" MIRROR_DEST="$MF/dest" MIRROR_LOG="$MF/src/_log/mirror-sync.log" sh "$SYNC"
chmod -R u+rwX "$MF/dest" 2>/dev/null || true
assert_rc "mirror-sync exits 2 when a copy fails" 2
if grep -q "FAILCOPY 09-MARKETING/NOTE.md" "$MF/src/_log/mirror-sync.log" \
    && grep -q "errno=" "$MF/src/_log/mirror-sync.log"; then
    t_pass "failed copy logs FAILCOPY with a classified errno"
else
    t_fail "failed copy logs FAILCOPY with a classified errno" "$(cat "$MF/src/_log/mirror-sync.log")"
fi
if printf '%s\n' "$OUT" | grep -q "FAILCOPY"; then
    t_pass "failed copy is also printed to stderr, not swallowed"
else
    t_fail "failed copy is also printed to stderr, not swallowed" "$OUT"
fi

# --- missing dest tree ---
MM=$(fixture t-mirror-missing)
mkdir -p "$MM/src/_log"
run env MIRROR_SRC="$MM/src" MIRROR_DEST="$MM/no-such-dest" MIRROR_LOG="$MM/src/_log/mirror-sync.log" sh "$SYNC"
assert_rc "mirror-sync exits 1 when the mirror path is missing" 1
