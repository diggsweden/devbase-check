#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"

maven_opts=(--batch-mode --no-transfer-progress --errors -Dstyle.color=always)

emit_status() {
  [[ "${DEVBASE_CHECK_MARKERS:-0}" == "1" ]] || return 0
  printf "DEVBASE_CHECK_STATUS=%s\n" "$1"
  [[ -n "${2:-}" ]] && printf "DEVBASE_CHECK_DETAILS=%s\n" "$2"
}

main() {
  print_header "JAVA LINTING (ALL)"

  if [[ ! -f pom.xml ]]; then
    print_warning "No pom.xml found, skipping"
    emit_status "skip" "skipped"
    return 0
  fi

  if ! command -v mvn >/dev/null 2>&1; then
    print_error "mvn not found. Install with: mise install maven"
    emit_status "fail" "failed"
    return 1
  fi

  print_info "Building project (skip tests)..."
  if ! mvn "${maven_opts[@]}" install -DskipTests; then
    print_error "Build failed"
    emit_status "fail" "failed"
    return 1
  fi

  local failed=0

  "${SCRIPT_DIR}/checkstyle.sh" || failed=1
  "${SCRIPT_DIR}/pmd.sh" || failed=1
  "${SCRIPT_DIR}/spotbugs.sh" || failed=1

  if [[ $failed -eq 0 ]]; then
    print_success "All Java linting passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Some Java linting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main
