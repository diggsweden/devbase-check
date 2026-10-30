#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
source "${SCRIPT_DIR}/../utils/git-utils.sh"
source "${SCRIPT_DIR}/../utils/mise-tool.sh"

# Organisation rules are scanned in addition to the repository's own
# .gitleaks.toml. They are read from ORG_RULES_CONFIG in either:
#   DEVBASE_ORG_RULES_DIR   a local checkout of the rules repository
#   DEVBASE_ORG_RULES_REPO  a git URL, cloned and updated into ORG_RULES_CACHE
readonly ORG_RULES_CONFIG="gitleaks/rules.toml"
readonly ORG_RULES_CACHE="${XDG_DATA_HOME:-$HOME/.local/share}/devbase-check-org-rules"

# Print the path to the organisation gitleaks config, or nothing when no
# organisation rules are configured. Fails when they are configured but
# cannot be read, so that a broken setup never passes silently.
resolve_org_rules_config() {
  local dir="${DEVBASE_ORG_RULES_DIR:-}"

  if [[ -z "$dir" && -n "${DEVBASE_ORG_RULES_REPO:-}" ]]; then
    dir="$ORG_RULES_CACHE"
    if [[ -d "${dir}/.git" ]]; then
      if git -C "$dir" fetch --quiet --depth 1 origin >/dev/null 2>&1; then
        git -C "$dir" reset --quiet --hard FETCH_HEAD
      else
        print_warning "Could not update organisation rules - using cached copy" >&2
      fi
    elif ! git clone --quiet --depth 1 "$DEVBASE_ORG_RULES_REPO" "$dir" >/dev/null 2>&1; then
      print_error "Could not clone organisation rules from DEVBASE_ORG_RULES_REPO" >&2
      return 1
    fi
  fi

  [[ -z "$dir" ]] && return 0

  if [[ ! -f "${dir}/${ORG_RULES_CONFIG}" ]]; then
    print_error "Organisation rules not found: ${dir}/${ORG_RULES_CONFIG}" >&2
    return 1
  fi
  printf '%s\n' "${dir}/${ORG_RULES_CONFIG}"
}

# Scan commits in scope plus staged and unstaged changes.
# Usage: scan <log-opts> [gitleaks args...]
scan() {
  local log_opts="$1"
  shift
  local result=0

  if [[ -n "$log_opts" ]]; then
    gitleaks detect --source=. --log-opts="$log_opts" --verbose --redact=50 "$@" || result=1
  else
    gitleaks detect --source=. --verbose --redact=50 "$@" || result=1
  fi
  gitleaks protect --source=. --staged --verbose --redact=50 "$@" || result=1
  gitleaks protect --source=. --verbose --redact=50 "$@" || result=1

  return $result
}

main() {
  print_header "SECRET SCANNING (GITLEAKS)"
  fail_if_mise_install_incomplete gitleaks || return 1

  if ! command -v gitleaks >/dev/null 2>&1; then
    print_warning "gitleaks not found in PATH - skipping secret scanning"
    echo "  Install: mise install"
    emit_status "skip" "not in PATH"
    return 0
  fi

  local default_branch current_branch log_opts=""
  default_branch=$(get_default_branch)
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  if [[ "$current_branch" == "$default_branch" ]]; then
    print_info "On default branch, scanning all commits and uncommitted changes..."
  elif branch_exists "$default_branch"; then
    print_info "Scanning commits different from ${default_branch} and uncommitted changes..."
    log_opts="${default_branch}..HEAD"
  else
    print_info "No base branch found, scanning all commits and uncommitted changes..."
  fi

  local gitleaks_result=0
  scan "$log_opts" || gitleaks_result=1

  local org_rules_config
  if ! org_rules_config=$(resolve_org_rules_config); then
    gitleaks_result=1
  elif [[ -n "$org_rules_config" ]]; then
    print_info "Scanning with organisation rules: ${org_rules_config}"
    scan "$log_opts" --config="$org_rules_config" || gitleaks_result=1
  fi

  if [[ $gitleaks_result -eq 0 ]]; then
    print_success "No secrets found"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Secret scanning failed - secrets may be present!"
    emit_status "fail" "failed"
    return 1
  fi
}

main
