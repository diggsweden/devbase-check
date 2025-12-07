#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

readonly ACTION="${1:-check}"

check_yaml() {
  if yamlfmt -lint .; then
    print_success "YAML linting passed"
    return 0
  else
    print_error "YAML linting failed - run 'just lint-yaml-fix' to fix"
    return 1
  fi
}

fix_yaml() {
  if yamlfmt .; then
    print_success "YAML files formatted"
    return 0
  else
    print_error "Failed to format YAML files"
    return 1
  fi
}

main() {
  print_header "YAML LINTING (YAMLFMT)"

  if ! command -v yamlfmt >/dev/null 2>&1; then
    print_warning "yamlfmt not found in PATH - skipping YAML linting"
    echo "  Install: mise install"
    return 0
  fi

  case "$ACTION" in
  check) check_yaml ;;
  fix) fix_yaml ;;
  *)
    print_error "Unknown action: $ACTION"
    printf "Usage: %s [check|fix]\n" "$0"
    return 1
    ;;
  esac
}

main
