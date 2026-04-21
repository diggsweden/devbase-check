#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"
source "${SCRIPT_DIR}/../../utils/mise-tool.sh"

main() {
  print_header "NODE TYPE CHECKING (TSC)"

  if ! command -v npx >/dev/null 2>&1; then
    print_error "npx not found. Install Node.js and npm"
    emit_status "fail" "failed"
    return 1
  fi

  # Check if project has TypeScript configured
  if [[ ! -f "tsconfig.json" ]] && [[ ! -f "package.json" ]]; then
    print_warning "No tsconfig.json or package.json found. Skipping type checking"
    emit_status "skip" "skipped"
    return 0
  fi

  if [[ -f "package.json" ]] && ! grep -q "typescript" package.json 2>/dev/null; then
    print_warning "TypeScript not configured in package.json. Skipping"
    emit_status "skip" "skipped"
    return 0
  fi

  # Check if there's an npm script for type checking
  if [[ -f "package.json" ]] && grep -q '"typecheck"' package.json 2>/dev/null; then
    npm run typecheck
  elif [[ -f "package.json" ]] && grep -q '"type-check"' package.json 2>/dev/null; then
    npm run type-check
  elif [[ -x "node_modules/.bin/tsc" ]]; then
    # Use locally installed tsc
    node_modules/.bin/tsc --noEmit
  else
    # Fallback: use npx with explicit typescript package
    # Note: 'npx tsc' alone would install wrong package (deprecated 'tsc' not 'typescript')
    npx -p typescript tsc --noEmit
  fi

  if [[ $? -eq 0 ]]; then
    print_success "Type checking passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Type checking failed - fix type errors"
    emit_status "fail" "failed"
    return 1
  fi
}

main
