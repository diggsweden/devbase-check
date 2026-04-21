#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Force-update an existing devbase-check install. Unlike setup.sh's
# passive hour-TTL check, this is explicit: always fetches, always
# checks out the target ref, no prompts.
#
#   update.sh <install-dir>              — latest release tag
#   update.sh <install-dir> --ref <ref>  — specific branch/tag/sha
#
# Fetches are performed against the install's configured `origin`, so
# mirror-cloned installs stay on their mirror.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

usage() {
  cat <<'EOF'
Usage: update.sh <install-dir> [--ref <ref>]

Force-updates an existing devbase-check install, bypassing setup.sh's
hour TTL and update-check marker. Fetches from the install's `origin`.
For first-time installs, use `just setup-devtools` instead.

Arguments:
  <install-dir>  Path to the existing devbase-check checkout.

Options:
  --ref <ref>    Check out <ref> (branch, tag, or sha) instead of the
                 latest release tag on origin/main. Useful for trying an
                 unreleased branch, e.g. --ref feat/my-change.
  -h, --help     Show this help.
EOF
}

DIR=""
REF=""

while (($# > 0)); do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --ref)
    [[ $# -ge 2 ]] || {
      print_error "--ref requires an argument"
      exit 2
    }
    REF="$2"
    shift 2
    ;;
  --ref=*)
    REF="${1#--ref=}"
    shift
    ;;
  --)
    shift
    break
    ;;
  -*)
    print_error "unknown option: $1"
    usage >&2
    exit 2
    ;;
  *)
    if [[ -z "$DIR" ]]; then
      DIR="$1"
    else
      print_error "unexpected argument: $1"
      usage >&2
      exit 2
    fi
    shift
    ;;
  esac
done

if [[ -z "$DIR" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d "$DIR/.git" ]]; then
  print_error "$DIR is not a git checkout — run 'just setup-devtools' first"
  exit 1
fi

# Record where we are before moving — shown in the success line so the
# user knows what actually changed.
before=$(git -C "$DIR" describe --tags --exact-match HEAD 2>/dev/null ||
  git -C "$DIR" rev-parse --short HEAD 2>/dev/null ||
  echo "unknown")

# Preserve user's uncommitted/untracked state before the checkout. Only
# stash if there's actually something to stash, so we can truthfully
# tell the user afterwards. The if-chain keeps a stash failure from
# aborting the script under set -e.
stashed=0
if [[ -n "$(git -C "$DIR" status --porcelain 2>/dev/null)" ]] &&
  git -C "$DIR" stash --include-untracked --quiet 2>/dev/null; then
  stashed=1
fi

if [[ -n "$REF" ]]; then
  print_info "Fetching $REF from origin..."
  git -C "$DIR" fetch --depth 1 origin "$REF" --quiet
  # Detach to whatever was fetched — works uniformly for branch, tag, or sha.
  git -C "$DIR" checkout --detach FETCH_HEAD --quiet
  target="$REF"
else
  print_info "Fetching latest release tag..."
  git -C "$DIR" fetch --tags --depth 1 --quiet
  target=$(git -C "$DIR" describe --tags --abbrev=0 origin/main 2>/dev/null || true)
  if [[ -z "$target" ]]; then
    print_error "no release tag found on origin/main"
    exit 1
  fi
  git -C "$DIR" fetch --depth 1 origin tag "$target" --quiet 2>/dev/null || true
  git -C "$DIR" checkout "$target" --quiet
fi

# Refresh the passive update-check marker so setup.sh doesn't immediately
# re-check on the next `just verify`.
touch "$DIR/.last-update-check"

print_success "devbase-check updated to $target (from $before)"
if ((stashed)); then
  print_info "Local changes were stashed — run 'git -C $DIR stash list' to inspect"
fi
