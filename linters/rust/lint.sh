#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"
source "${SCRIPT_DIR}/../../utils/mise-tool.sh"

main() {
  print_header "RUST LINTING (ALL)"

  if [[ ! -f Cargo.toml ]]; then
    print_warning "No Cargo.toml found, skipping"
    emit_status "skip" "skipped"
    return 0
  fi

  if ! command -v cargo >/dev/null 2>&1; then
    print_error "cargo not found. Install Rust via rustup or mise"
    emit_status "fail" "failed"
    return 1
  fi

  local failed=0
  "${SCRIPT_DIR}/clippy.sh" || failed=1

  if [[ $failed -eq 0 ]]; then
    print_success "All Rust linting passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Some Rust linting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main
