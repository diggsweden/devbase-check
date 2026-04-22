<!--
SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government

SPDX-License-Identifier: CC0-1.0
-->

# For stuck users — how to unstick

If you've been seeing (or silently missing) `Could not check for updates (no network connection)` warnings, or your devbase-check install hasn't moved in months, you're likely caught in the old recipe's pre-fetch trap. Pick one:

**Option 1 — manual pull** (preserves the existing checkout):

```bash
dir="${XDG_DATA_HOME:-$HOME/.local/share}/devbase-check"
git -C "$dir" fetch --tags
latest=$(git -C "$dir" describe --tags --abbrev=0 origin/main)
git -C "$dir" checkout "$latest"
```

**Option 2 — use the escape-hatch recipe** (works even if your consumer justfile hasn't been updated):

```bash
just -f "${XDG_DATA_HOME:-$HOME/.local/share}/devbase-check/justfile" update
```

This bypasses your own project's justfile entirely and uses devbase-check's internal `update` recipe, which resolves paths via `justfile_directory()` and works from any cwd.

**Option 3 — nuke and re-clone**:

```bash
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/devbase-check"
just setup-devtools
```

Any of the three gets you onto 0.5.0. After that, the new `setup.sh` is self-healing: it stays silent on transient network failures and retries on the next run instead of warning + giving up.

---

## What's new

### `just update-devtools` — explicit, on-demand update

Previously, updates happened passively: `setup.sh` checked once an hour during `just setup-devtools` invocations, and either prompted or auto-updated.

```bash
just update-devtools              # latest release tag, bypass TTL
just update-devtools --ref feat/my-change   # try an unreleased branch
just update-devtools --ref v0.4.2           # roll back to a specific tag
just update-devtools --help
```

## Consumer justfile updates (optional but recommended)

The example justfiles (`examples/{base,java,node}-justfile`) have been simplified.

### Shrink `setup-devtools`

**Before** (~22 lines of inline shell that duplicated `setup.sh`):

```just
setup-devtools:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -d "{{devtools_dir}}" ]]; then
        if ! git -C "{{devtools_dir}}" fetch --tags --depth 1 --quiet 2>/dev/null; then
            printf "\033[0;33m! Could not check for updates (no network connection)\033[0m\n"
        elif [[ -f "{{devtools_dir}}/scripts/setup.sh" ]]; then
            "{{devtools_dir}}/scripts/setup.sh" "{{devtools_repo}}" "{{devtools_dir}}"
        fi
    else
        printf "Cloning devbase-check to %s...\n" "{{devtools_dir}}"
        mkdir -p "$(dirname "{{devtools_dir}}")"
        git clone --depth 1 "{{devtools_repo}}" "{{devtools_dir}}"
        # ... more inline clone/checkout ...
    fi
```

**After** (two lines, delegates everything):

```just
setup-devtools:
    @[[ -d "{{devtools_dir}}" ]] || { mkdir -p "$(dirname "{{devtools_dir}}")" && git clone --depth 1 "{{devtools_repo}}" "{{devtools_dir}}"; }
    @"{{devtools_dir}}/scripts/setup.sh" "{{devtools_repo}}" "{{devtools_dir}}"
```

Why this is better: no consumer-side pre-fetch. The consumer's recipe doesn't warn or short-circuit on network failure. All logic lives in one place (`setup.sh`), which improves idempotently as we release new versions.

### Add `update-devtools`

```just
update-devtools *ARGS:
    @"{{devtools_dir}}/scripts/update.sh" "{{devtools_dir}}" {{ ARGS }}
```

---

If you hit anything not covered here, the escape hatch is always:

```bash
just -f "${XDG_DATA_HOME:-$HOME/.local/share}/devbase-check/justfile" update
```
