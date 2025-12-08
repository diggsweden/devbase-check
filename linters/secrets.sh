#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

get_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s@^refs/remotes/origin/@@" || echo "main"
}

main() {
  print_header "SECRET SCANNING (GITLEAKS)"

  if ! command -v gitleaks >/dev/null 2>&1; then
    print_warning "gitleaks not found in PATH - skipping secret scanning"
    echo "  Install: mise install"
    return 0
  fi

  local default_branch current_branch
  default_branch=$(get_default_branch)
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  local gitleaks_result
  if [[ "$current_branch" == "$default_branch" ]]; then
    print_info "On default branch, scanning all commits..."
    gitleaks detect --source=. --verbose --redact=50
    gitleaks_result=$?
  else
    print_info "Scanning commits different from ${default_branch}..."
    gitleaks detect --source=. --log-opts="${default_branch}..HEAD" --verbose --redact=50
    gitleaks_result=$?
  fi

  if [[ $gitleaks_result -eq 0 ]]; then
    print_success "No secrets found"
    return 0
  else
    print_error "Secret scanning failed - secrets may be present!"
    return 1
  fi
}

main
