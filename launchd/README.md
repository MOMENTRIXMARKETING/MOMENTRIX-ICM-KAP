# Mac launchd scripts

Canonical copies of the Momentrix Mac scheduled jobs. The plists stay in
`~/Library/LaunchAgents` and keep pointing at `~/scripts/...`. Do not load or
unload launchd as part of this change. Copy the script, the next scheduled
run uses it.

These jobs are bash (not POSIX sh). They are kept out of `scripts/*.sh` so
CI's `dash -n` gate does not parse bash arrays.

## Install on MacBook-Pro-2 (one line each)

```sh
cp launchd/momentrix_icm_kap_nightly.bash ~/scripts/momentrix_icm_kap_nightly.sh && chmod +x ~/scripts/momentrix_icm_kap_nightly.sh
```

```sh
cp launchd/content_engine_sync.bash ~/scripts/content_engine_sync.sh && chmod +x ~/scripts/content_engine_sync.sh
```

After Full Disk Access is granted to `/bin/bash`, the next 22:59 and weekday
05:30 runs should get a real exit code. A red last-exit on
`com.momentrix.icm-kap-nightly` now means a real failure, not a swallowed one.
