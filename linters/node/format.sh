#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"

readonly ACTION="${1:-check}"

emit_status() {
  [[ "${DEVBASE_CHECK_MARKERS:-0}" == "1" ]] || return 0
  printf "DEVBASE_CHECK_STATUS=%s\n" "$1"
  [[ -n "${2:-}" ]] && printf "DEVBASE_CHECK_DETAILS=%s\n" "$2"
}

check_prettier() {
  npx prettier --check .
  if [[ $? -eq 0 ]]; then
    print_success "Prettier check passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Prettier check failed - run 'just lint-node-format-fix' to fix"
    emit_status "fail" "failed"
    return 1
  fi
}

fix_prettier() {
  npx prettier --write .
  if [[ $? -eq 0 ]]; then
    print_success "Prettier formatting applied"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Prettier formatting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main() {
  print_header "NODE FORMATTING (PRETTIER)"

  if ! command -v npx >/dev/null 2>&1; then
    print_error "npx not found. Install Node.js and npm"
    emit_status "fail" "failed"
    return 1
  fi

  # Check if project has Prettier configured
  if [[ ! -f "package.json" ]]; then
    print_warning "No package.json found. Skipping Prettier"
    emit_status "skip" "skipped"
    return 0
  fi

  if ! grep -q "prettier" package.json 2>/dev/null; then
    print_warning "Prettier not configured in package.json. Skipping"
    emit_status "skip" "skipped"
    return 0
  fi

  case "$ACTION" in
  check) check_prettier ;;
  fix) fix_prettier ;;
  *)
    print_error "Unknown action: $ACTION"
    printf "Usage: %s [check|fix]\n" "$0"
    emit_status "fail" "failed"
    return 1
    ;;
  esac
}

main
