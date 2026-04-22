#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"
source "${SCRIPT_DIR}/../../utils/mise-tool.sh"

main() {
  print_header "RUST CLIPPY"

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

  if cargo clippy --workspace --all-targets -- -D warnings; then
    print_success "Clippy passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Clippy failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main
