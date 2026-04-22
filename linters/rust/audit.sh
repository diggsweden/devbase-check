#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Run cargo-audit against Cargo.lock to check for known RUSTSEC advisories.
# Auto-installs cargo-audit (pinned via CARGO_AUDIT_VERSION) when missing so
# behaviour matches between local dev and CI without forcing every consumer
# to mise-install another binary.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"
source "${SCRIPT_DIR}/../../utils/mise-tool.sh"

# renovate: datasource=crate depName=cargo-audit
readonly CARGO_AUDIT_VERSION="${CARGO_AUDIT_VERSION:-0.22.1}"

main() {
  print_header "RUST CARGO AUDIT"

  if [[ ! -f Cargo.toml ]]; then
    print_warning "No Cargo.toml found, skipping"
    emit_status "skip" "skipped"
    return 0
  fi

  if [[ ! -f Cargo.lock ]]; then
    print_warning "No Cargo.lock found, skipping (run 'cargo generate-lockfile' first)"
    emit_status "skip" "skipped"
    return 0
  fi

  if ! command -v cargo >/dev/null 2>&1; then
    print_error "cargo not found. Install Rust via rustup or mise"
    emit_status "fail" "failed"
    return 1
  fi

  if ! command -v cargo-audit >/dev/null 2>&1; then
    print_info "Installing cargo-audit ${CARGO_AUDIT_VERSION}..."
    if ! cargo install --locked cargo-audit --version "${CARGO_AUDIT_VERSION}"; then
      print_error "Failed to install cargo-audit"
      emit_status "fail" "failed"
      return 1
    fi
  fi

  if cargo audit -f Cargo.lock; then
    print_success "No known vulnerabilities"
    emit_status "pass" "ok"
    return 0
  else
    print_error "cargo audit found advisories"
    emit_status "fail" "failed"
    return 1
  fi
}

main
