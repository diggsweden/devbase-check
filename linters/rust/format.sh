#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"
source "${SCRIPT_DIR}/../../utils/mise-tool.sh"

readonly ACTION="${1:-check}"

check_format() {
  if cargo fmt --all -- --check; then
    print_success "Rust formatting check passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Rust formatting check failed - run 'just lint-rust-fmt-fix' to fix"
    emit_status "fail" "failed"
    return 1
  fi
}

fix_format() {
  if cargo fmt --all; then
    print_success "Rust code formatted"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Rust formatting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main() {
  print_header "RUST FORMATTING (RUSTFMT)"

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

  case "$ACTION" in
  check) check_format ;;
  fix) fix_format ;;
  *)
    print_error "Unknown action: $ACTION"
    printf "Usage: %s [check|fix]\n" "$0"
    emit_status "fail" "failed"
    return 1
    ;;
  esac
}

main
