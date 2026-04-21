#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

readonly REPO="${1:-}"
readonly DIR="${2:-}"

if [[ -z "$REPO" || -z "$DIR" ]]; then
  print_error "Usage: setup.sh <repo-url> <install-dir>"
  exit 1
fi

get_current_version() {
  git -C "$DIR" describe --tags --abbrev=0 2>/dev/null || echo "unknown"
}

get_latest_version() {
  git -C "$DIR" describe --tags --abbrev=0 origin/main 2>/dev/null || echo "unknown"
}

update_to_version() {
  local version="$1"
  # Fetch only the specific tag, shallow
  git -C "$DIR" fetch --depth 1 origin tag "$version" --quiet
  # Stash any local changes (including untracked files) to avoid checkout conflicts
  git -C "$DIR" stash --include-untracked --quiet 2>/dev/null || true
  git -C "$DIR" checkout "$version" --quiet
  print_success "Updated to $version"
  maybe_nudge_recipe_migration
}

# One-time nudge for users whose project justfile still has the old
# ~22-line setup-devtools recipe. Harmless if they've already migrated —
# the tip prints once per install dir, then is silenced by a marker.
maybe_nudge_recipe_migration() {
  local flag="$DIR/.tip-minimal-recipe-shown"
  [[ -f "$flag" ]] && return 0
  print_info "Tip: a shorter setup-devtools recipe is available — see ${DIR}/examples/base-justfile"
  touch "$flag"
}

clone_repo() {
  print_info "Cloning devbase-check to $DIR..."
  mkdir -p "$(dirname "$DIR")"
  git clone --depth 1 "$REPO" "$DIR" --quiet
  git -C "$DIR" fetch --tags --depth 1 --quiet

  local latest
  latest=$(get_latest_version)
  if [[ -n "$latest" && "$latest" != "unknown" ]]; then
    git -C "$DIR" fetch --depth 1 origin tag "$latest" --quiet
    git -C "$DIR" checkout "$latest" --quiet
  fi
  print_success "Installed devtools ${latest:-main}"
  maybe_nudge_recipe_migration
}

check_for_updates() {
  local current="$1"
  local latest="$2"

  [[ "$current" == "$latest" || "$latest" == "unknown" ]] && return 0

  # Explicit opt-in: auto-update regardless of shell type.
  if [[ "${DEVBASE_CHECK_AUTO_UPDATE:-0}" == "1" ]]; then
    print_info "Auto-updating devtools to $latest"
    update_to_version "$latest"
    return 0
  fi

  # Non-interactive (CI, pipes, background jobs): do NOT auto-update.
  # Version management in CI is the caller's responsibility — pin the
  # devbase-check version via Renovate or equivalent. Use
  # DEVBASE_CHECK_AUTO_UPDATE=1 to opt in if you really want
  # track-latest-tag behaviour.
  [[ ! -t 0 ]] && return 0

  # Interactive: ask once per check. A "no" means "not now" — the hour TTL
  # will let the next run ask again until the user accepts or a newer tag
  # ships.
  print_info "devtools installed: $current"
  read -p "Update available: $latest. Update? [y/N] " -n 1 -r
  printf "\n"
  [[ $REPLY =~ ^[Yy]$ ]] && update_to_version "$latest"
}

main() {
  # Opt-out: never check for updates.
  [[ "${DEVBASE_CHECK_SKIP_UPDATES:-0}" == "1" ]] && return 0

  if [[ ! -d "$DIR" ]]; then
    clone_repo
    return 0
  fi

  local marker="$DIR/.last-update-check"

  # First run after a bare clone (consumer bootstrap did `git clone` but
  # didn't pick a tag): no marker present and HEAD isn't a tag. Silently
  # check out the latest tag to complete the install — don't prompt the
  # user about upgrading something they just installed.
  if [[ ! -f "$marker" ]] &&
    ! git -C "$DIR" describe --exact-match --tags HEAD >/dev/null 2>&1; then
    # Full-depth fetch so `git describe` can resolve a tag reachable from
    # origin/main even when the branch tip is past the latest release.
    git -C "$DIR" fetch --tags --quiet 2>/dev/null || return 0
    local latest
    latest=$(get_latest_version)
    [[ -n "$latest" && "$latest" != "unknown" ]] && update_to_version "$latest"
    touch "$marker"
    return 0
  fi

  # Hour TTL between checks, keyed off the marker's mtime.
  if [[ -f "$marker" ]] && [[ -z "$(find "$marker" -mmin +60 2>/dev/null)" ]]; then
    return 0
  fi

  # Silent on network failure: don't touch the marker so the next run
  # retries instead of waiting out the TTL.
  git -C "$DIR" fetch --tags --depth 1 --quiet 2>/dev/null || return 0

  touch "$marker"
  check_for_updates "$(get_current_version)" "$(get_latest_version)"
}

main
