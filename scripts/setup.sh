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
  git -C "$DIR" fetch --all --quiet
  # Stash any local changes to avoid checkout conflicts
  git -C "$DIR" stash --quiet 2>/dev/null || true
  git -C "$DIR" checkout "$version" --quiet
  print_success "Updated to $version"
}

clone_repo() {
  print_info "Cloning devbase-justkit to $DIR..."
  mkdir -p "$(dirname "$DIR")"
  git clone --depth 1 "$REPO" "$DIR" --quiet
  git -C "$DIR" fetch --tags --quiet

  local latest
  latest=$(get_latest_version)
  if [[ -n "$latest" && "$latest" != "unknown" ]]; then
    git -C "$DIR" fetch --depth 1 origin tag "$latest" --quiet
    git -C "$DIR" checkout "$latest" --quiet
  fi
  print_success "Installed devtools ${latest:-main}"
}

check_for_updates() {
  local current="$1"
  local latest="$2"

  if [[ "$current" != "$latest" && "$latest" != "unknown" ]]; then
    # Auto-update in CI/non-interactive mode, prompt in interactive mode
    if [[ "${CI:-false}" == "true" ]] || [[ ! -t 0 ]]; then
      print_info "Auto-updating devtools to $latest"
      update_to_version "$latest"
    else
      print_info "devtools installed: $current"
      read -p "Update available: $latest. Update? [y/N] " -n 1 -r
      printf "\n"
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_to_version "$latest"
      fi
    fi
  fi
}

main() {
  if [[ -d "$DIR" ]]; then
    git -C "$DIR" fetch --tags --quiet
    check_for_updates "$(get_current_version)" "$(get_latest_version)"
  else
    clone_repo
  fi
}

main
