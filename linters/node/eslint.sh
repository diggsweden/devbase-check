#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"
source "${SCRIPT_DIR}/../../utils/mise-tool.sh"

main() {
  print_header "NODE ESLINT (JS/TS)"
  fail_if_mise_install_incomplete || return 1

  if ! command -v npx >/dev/null 2>&1; then
    print_error "npx not found. Install Node.js and npm"
    emit_status "fail" "failed"
    return 1
  fi

  # Check if project has ESLint configured
  if [[ ! -f "package.json" ]]; then
    print_warning "No package.json found. Skipping ESLint"
    emit_status "skip" "skipped"
    return 0
  fi

  if ! grep -q "eslint" package.json 2>/dev/null; then
    print_warning "ESLint not configured in package.json. Skipping"
    emit_status "skip" "skipped"
    return 0
  fi

  # Check if there's an npm script for lint
  if grep -q '"lint"' package.json 2>/dev/null; then
    npm run lint
  else
    # Fallback to direct eslint command
    npx eslint .
  fi

  if [[ $? -eq 0 ]]; then
    print_success "ESLint check passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "ESLint check failed - run 'npm run lint -- --fix' or 'npx eslint . --fix' to fix"
    emit_status "fail" "failed"
    return 1
  fi
}

main
