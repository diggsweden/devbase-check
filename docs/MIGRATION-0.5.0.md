<!--
SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government

SPDX-License-Identifier: CC0-1.0
-->

# Migration to devbase-check 0.5.0

0.5.0 is a quality-of-life release aimed at two recurring pain points:

1. **Users got silently stuck on old versions.** The `just lint-all` flow used to warn on any network hiccup and skip its own update check, so users behind VPNs or intermittent networks never received updates.
2. **"Tool not found" errors were opaque.** When `mise install` silently skipped a pin (classic case: `pipx:reuse` when pipx isn't on the host), linters either fell through to a stray system binary or failed with a generic error. The real cause — "your mise install is incomplete" — was invisible.

Both problems are now fixed. This guide tells you what changed, how to unstick if you're already stale, and how (optionally) to simplify your project's justfile.

---

## TL;DR — one action you probably want to take

Add an `update-devtools` recipe to your project's justfile (see [Consumer justfile updates](#consumer-justfile-updates-optional-but-recommended) below). From then on, `just update-devtools` force-updates to the latest release tag on demand, no prompts, no TTL.

If you've been on an old version and `just lint-all` has silently stopped picking up updates, see [For stuck users — how to unstick](#for-stuck-users--how-to-unstick).

---

## For stuck users — how to unstick

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

Previously, updates happened passively: `setup.sh` checked once an hour during `just setup-devtools` invocations, and either prompted or auto-updated. There was no way to say "update now regardless of the TTL" without touching the marker file by hand.

```bash
just update-devtools              # latest release tag, bypass TTL
just update-devtools --ref feat/my-change   # try an unreleased branch
just update-devtools --ref v0.4.2           # roll back to a specific tag
just update-devtools --help
```

Under the hood this runs `scripts/update.sh`, which:

- Fetches unconditionally (not gated by the marker).
- Stashes untracked/uncommitted state first so local experimentation isn't lost.
- For `--ref`, uses `git checkout --detach FETCH_HEAD` — works uniformly for branches, tags, and SHAs.
- Refreshes `.last-update-check` on success so setup.sh doesn't immediately re-check.

### Silent offline, retriable next run

`setup.sh` no longer warns on fetch failure, and — importantly — does not touch the hour-TTL marker when the fetch fails. Net effect: on a flaky network, the next `just lint-all` actually tries again instead of waiting out the hour. Users with sporadic connectivity now get updates on their next good-network moment instead of never.

### First-run self-healing

If the consumer's `setup-devtools` recipe did a bare clone but the tag-checkout didn't complete (e.g., network cut between `git clone` and `git checkout <tag>`), the next run now notices HEAD isn't on a tag and silently completes the install. No prompt, no error — it just works on the next invocation.

### Mise install is incomplete — one clear message, not a cascade

If any pin in `.mise.toml` is reported missing by `mise ls --missing`, `just lint-all` now fails fast with one message:

```text
✗ mise install is incomplete — run: mise install
  - pipx:reuse
  (to skip: --ignore-missing-linters or DEVBASE_CHECK_IGNORE_MISSING_LINTERS=1)
```

Each linter still has its own guard, but when running a specific linter (e.g. `./linters/license.sh`) it fires only when **that linter's own tool** is the one missing. Running `./linters/license.sh` when `aqua:mvdan/sh` is missing no longer errors — `reuse` is fine, the linter just runs.

### `--ignore-missing-linters` and related opt-outs

```bash
just lint-all --ignore-missing-linters     # proceed; affected linters skip
```

Affected linters emit a `skip` marker, so the summary table shows them as `-` with a `mise pin missing` detail rather than wrongly reporting pass/fail.

Three env-var opt-outs cover the other shapes:

| Variable | Effect |
|---|---|
| `DEVBASE_CHECK_IGNORE_MISSING_LINTERS=1` | Same as `--ignore-missing-linters`. |
| `DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS=1` | Skip the mise-pin check entirely; fall through to whatever's on PATH. For locked-down environments where `mise install` can't complete. |
| `DEVBASE_CHECK_SKIP_UPDATES=1` | Never run the passive update check. For CI pipelines pinned by SHA, air-gapped environments. |
| `DEVBASE_CHECK_AUTO_UPDATE=1` | Auto-accept updates without the `[y/N]` prompt. For humans who want auto-update in a terminal. |

---

## Consumer justfile updates (optional but recommended)

The example justfiles (`examples/{base,java,node}-justfile`) have been simplified. Applying the same changes to your own justfile is optional but gives you the benefit of the new flow without fighting it.

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

Now `just update-devtools` is at your fingertips.

The first time the new `setup.sh` runs in your install, it prints a one-time tip pointing at these example files, then stays quiet thereafter (marker file `.tip-minimal-recipe-shown`).

---

## Behavioural changes to be aware of

- **`setup.sh` is silent on fetch failure.** You will no longer see `Could not check for updates (no network connection)`. If you had log-scraping on that string, update it. The marker is also no longer touched when the fetch fails, so next-run behaviour changes from "wait an hour" to "retry immediately."

- **Per-linter guard is now tool-specific.** Calling `./linters/<x>.sh` directly only errors on a missing mise pin if **its** tool is the one affected. Node linters (`eslint`, `prettier`, `tsc`) no longer call the guard at all — they don't have mise pins (they use `npx`).

- **`check-tools.sh` output labels tool provenance.** Each listed tool now shows `(mise)` or `(system)` — useful for spotting a stray system copy when you thought you were running the pinned version.

- **Dependency changes.** `gommitlint` bumped to `0.9.10`. `rumdl` switched from the `ubi` backend to `aqua` and is pinned at `v0.1.62` (newer aqua versions fail attestation verification — upstream registry issue, tracked separately).

- **No breaking API changes.** Existing `just verify`, `just lint-all`, individual `just lint-*` recipes, and the script invocations continue to work. If you haven't updated your consumer justfile, everything keeps functioning — you just miss the benefits of the new flow until you migrate.

---

## Where things are

| Change | Files |
|---|---|
| Update flow | `scripts/setup.sh`, `scripts/update.sh` (new), `justfile` (new `update` recipe) |
| Mise-install guard | `utils/mise-tool.sh`, all `linters/*.sh` |
| Preflight + CLI | `scripts/verify.sh`, `justfile` |
| Consumer examples | `examples/{base,java,node}-justfile` |
| Tests | `tests/setup.bats`, `tests/update.bats`, `tests/verify.bats`, `tests/utils-mise-tool.bats` |

If you hit anything not covered here, the escape hatch is always:

```bash
just -f "${XDG_DATA_HOME:-$HOME/.local/share}/devbase-check/justfile" update
```
