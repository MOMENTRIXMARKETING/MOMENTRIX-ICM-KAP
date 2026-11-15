#!/bin/sh
# Extra suite for launchd/momentrix_icm_kap_nightly.bash and
# launchd/content_engine_sync.bash. Sourced from tests/run-tests.sh so it
# shares PASSN/FAILN and the helpers. bash is required for the scripts
# themselves; this file stays POSIX.

NIGHTLY="$ROOT/launchd/momentrix_icm_kap_nightly.bash"
CES="$ROOT/launchd/content_engine_sync.bash"

printf '\n%s\n' '-- launchd nightly and content-engine-sync --'

if ! command -v bash >/dev/null 2>&1; then
    t_fail "bash is required to syntax-check the launchd scripts" "no bash on PATH"
    return 0
fi

run bash -n "$NIGHTLY"
assert_rc "nightly script passes bash -n" 0

run bash -n "$CES"
assert_rc "content_engine_sync.sh passes bash -n" 0

# --- nightly: clean fixture exits 0 ---
ND=$(fixture t-nightly-ok)
mkdir -p "$ND/live/_log" "$ND/live/15-SKILLS" "$ND/live/16-TOOLS"
printf 'ledger\n' > "$ND/live/_log/LOOP-LEDGER.md"
printf '#!/bin/sh\necho synced 0, failed 0\nexit 0\n' > "$ND/live/16-TOOLS/momentrix-mirror-sync.sh"
chmod +x "$ND/live/16-TOOLS/momentrix-mirror-sync.sh"
# no toolkit clones: those are notes, not hard failures if missing? The
# script add_problem on missing .git. For a green run, plant two identical clones.
make_clone() {
    _c="$1"
    mkdir -p "$_c"
    git init -q "$_c"
    git -C "$_c" config user.email "test@example.com"
    git -C "$_c" config user.name "Test"
    git -C "$_c" checkout -q -B main
    printf 'x\n' > "$_c/README"
    git -C "$_c" add README
    git -C "$_c" commit -q -m init
    git init --bare -q "$_c.git"
    git -C "$_c" remote add origin "$_c.git"
    git -C "$_c" push -q -u origin main
}

make_clone "$ND/desk-tk"
# second clone from the same bare so HEADs match
git clone -q "$ND/desk-tk.git" "$ND/drop-tk"
git -C "$ND/drop-tk" checkout -q main

run env \
    MOMENTRIX_HOME="$ND" \
    TOOLKIT_DESKTOP="$ND/desk-tk" \
    TOOLKIT_DROPBOX="$ND/drop-tk" \
    LIVE_WORKSPACE="$ND/live" \
    MIRROR_SYNC_SCRIPT="$ND/live/16-TOOLS/momentrix-mirror-sync.sh" \
    bash "$NIGHTLY"
assert_rc "nightly exits 0 when every step succeeds" 0
assert_file "nightly wrote the run log on a clean run" "$ND/live/_log/NIGHTLY-ICM-KAP-CHECK-RUNLOG.md"

# --- nightly: EPERM from the mirror script exits 2 ---
NE=$(fixture t-nightly-eperm)
mkdir -p "$NE/live/_log" "$NE/live/15-SKILLS" "$NE/live/16-TOOLS"
printf 'ledger\n' > "$NE/live/_log/LOOP-LEDGER.md"
printf '#!/bin/sh\necho "bash: /tmp/mirror: Operation not permitted"\nexit 126\n' > "$NE/live/16-TOOLS/momentrix-mirror-sync.sh"
chmod +x "$NE/live/16-TOOLS/momentrix-mirror-sync.sh"
make_clone "$NE/desk-tk"
git clone -q "$NE/desk-tk.git" "$NE/drop-tk"
git -C "$NE/drop-tk" checkout -q main

run env \
    MOMENTRIX_HOME="$NE" \
    TOOLKIT_DESKTOP="$NE/desk-tk" \
    TOOLKIT_DROPBOX="$NE/drop-tk" \
    LIVE_WORKSPACE="$NE/live" \
    MIRROR_SYNC_SCRIPT="$NE/live/16-TOOLS/momentrix-mirror-sync.sh" \
    bash "$NIGHTLY"
assert_rc "nightly exits 2 on Operation not permitted" 2
assert_file "nightly wrote the problem log on EPERM" "$NE/live/_log/NIGHTLY-ICM-KAP-CHECK-PROBLEMS.md"
if grep -q "Operation not permitted" "$NE/live/_log/NIGHTLY-ICM-KAP-CHECK-PROBLEMS.md"; then
    t_pass "nightly names Operation not permitted in the problem log"
else
    t_fail "nightly names Operation not permitted in the problem log" "$(cat "$NE/live/_log/NIGHTLY-ICM-KAP-CHECK-PROBLEMS.md")"
fi

# --- nightly: stale SKILLS/_LOGS is no longer required; 15-SKILLS is ---
NS=$(fixture t-nightly-skills)
mkdir -p "$NS/live/_log" "$NS/live/16-TOOLS"
printf 'ledger\n' > "$NS/live/_log/LOOP-LEDGER.md"
printf '#!/bin/sh\necho ok\nexit 0\n' > "$NS/live/16-TOOLS/momentrix-mirror-sync.sh"
chmod +x "$NS/live/16-TOOLS/momentrix-mirror-sync.sh"
make_clone "$NS/desk-tk"
git clone -q "$NS/desk-tk.git" "$NS/drop-tk"
git -C "$NS/drop-tk" checkout -q main
run env \
    MOMENTRIX_HOME="$NS" \
    TOOLKIT_DESKTOP="$NS/desk-tk" \
    TOOLKIT_DROPBOX="$NS/drop-tk" \
    LIVE_WORKSPACE="$NS/live" \
    MIRROR_SYNC_SCRIPT="$NS/live/16-TOOLS/momentrix-mirror-sync.sh" \
    bash "$NIGHTLY"
assert_rc "nightly fails when 15-SKILLS is missing" 1
if grep -q "15-SKILLS" "$NS/live/_log/NIGHTLY-ICM-KAP-CHECK-PROBLEMS.md"; then
    t_pass "nightly names the 15-SKILLS path in the problem log"
else
    t_fail "nightly names the 15-SKILLS path in the problem log" "$(cat "$NS/live/_log/NIGHTLY-ICM-KAP-CHECK-PROBLEMS.md" 2>/dev/null)"
fi

# --- content_engine_sync: missing repo fails closed, does not log ok ---
CE=$(fixture t-ces-norepo)
mkdir -p "$CE/scripts"
run env \
    MOMENTRIX_HOME="$CE" \
    REPO="$CE/missing-repo" \
    DESK="$CE/desk" \
    BASE="$CE/base" \
    LOG="$CE/scripts/content_engine_sync.log" \
    bash "$CES"
assert_rc "content_engine_sync exits 1 when the clone is missing" 1
if grep -q '^ok ' "$CE/scripts/content_engine_sync.log" 2>/dev/null; then
    t_fail "content_engine_sync does not log ok after a failure" "$(cat "$CE/scripts/content_engine_sync.log")"
else
    t_pass "content_engine_sync does not log ok after a failure"
fi
if grep -q "FAIL" "$CE/scripts/content_engine_sync.log"; then
    t_pass "content_engine_sync logs FAIL for a missing clone"
else
    t_fail "content_engine_sync logs FAIL for a missing clone" "$(cat "$CE/scripts/content_engine_sync.log" 2>/dev/null)"
fi

# --- content_engine_sync: successful down-copy is counted; blocked dest fails ---
CG=$(fixture t-ces-copy)
mkdir -p "$CG/scripts" "$CG/repo/departments/marketing/CONTENT-ENGINE"
printf 'from brain\n' > "$CG/repo/departments/marketing/CONTENT-ENGINE/README.md"
git init -q "$CG/repo"
git -C "$CG/repo" config user.email "test@example.com"
git -C "$CG/repo" config user.name "Test"
git -C "$CG/repo" checkout -q -B main
git -C "$CG/repo" add departments
git -C "$CG/repo" commit -q -m init
git init --bare -q "$CG/remote.git"
git -C "$CG/repo" remote add origin "$CG/remote.git"
git -C "$CG/repo" push -q -u origin main
mkdir -p "$CG/desk"
run env \
    MOMENTRIX_HOME="$CG" \
    REPO="$CG/repo" \
    DESK="$CG/desk" \
    BASE="$CG/base" \
    LOG="$CG/scripts/content_engine_sync.log" \
    DRY_RUN=0 \
    bash "$CES"
assert_rc "content_engine_sync exits 0 when the Desktop dest is writable" 0
assert_file "content_engine_sync copied README.md onto Desktop" "$CG/desk/README.md"
if grep -q 'ok up=0 down=1' "$CG/scripts/content_engine_sync.log"; then
    t_pass "content_engine_sync logs ok down=1 only after a real copy"
else
    t_fail "content_engine_sync logs ok down=1 only after a real copy" "$(cat "$CG/scripts/content_engine_sync.log")"
fi

# Blocked dest: directory not writable, cp must fail and must not log ok down.
CB=$(fixture t-ces-blocked)
mkdir -p "$CB/scripts" "$CB/repo/departments/marketing/CONTENT-ENGINE"
printf 'from brain\n' > "$CB/repo/departments/marketing/CONTENT-ENGINE/README.md"
git init -q "$CB/repo"
git -C "$CB/repo" config user.email "test@example.com"
git -C "$CB/repo" config user.name "Test"
git -C "$CB/repo" checkout -q -B main
git -C "$CB/repo" add departments
git -C "$CB/repo" commit -q -m init
git init --bare -q "$CB/remote.git"
git -C "$CB/repo" remote add origin "$CB/remote.git"
git -C "$CB/repo" push -q -u origin main
# Pre-create dest file as read-only in a read-only directory? mkdir -p DESK works
# first; then make the dest file exist and not writable, and the parent 555
# so cp cannot replace it. Also chmod the dest file 444.
mkdir -p "$CB/desk"
# Leave desk existing but not writable after the script's mkdir -p (which
# succeeds on an existing dir). A 0444 file in a 0555 directory cannot be
# replaced.
printf 'stale\n' > "$CB/desk/README.md"
chmod 444 "$CB/desk/README.md"
chmod 555 "$CB/desk"
run env \
    MOMENTRIX_HOME="$CB" \
    REPO="$CB/repo" \
    DESK="$CB/desk" \
    BASE="$CB/base" \
    LOG="$CB/scripts/content_engine_sync.log" \
    DRY_RUN=0 \
    bash "$CES"
# restore perms so the test harness cleanup can delete the fixture
chmod -R u+rwX "$CB/desk" 2>/dev/null || true
assert_rc "content_engine_sync exits 1 when cp cannot write the dest" 1
if grep -q '^ok ' "$CB/scripts/content_engine_sync.log" 2>/dev/null; then
    t_fail "blocked copy does not log a successful ok down count" "$(cat "$CB/scripts/content_engine_sync.log")"
else
    t_pass "blocked copy does not log a successful ok down count"
fi

# Default GH_REPO is the current org.
if grep -q 'GH_REPO="\${GH_REPO:-MOMENTRIXSALES/MOMENTRIX-BRAIN}"' "$CES"; then
    t_pass "content_engine_sync defaults GH_REPO to MOMENTRIXSALES/MOMENTRIX-BRAIN"
else
    t_fail "content_engine_sync defaults GH_REPO to MOMENTRIXSALES/MOMENTRIX-BRAIN" "GH_REPO default missing or wrong"
fi
