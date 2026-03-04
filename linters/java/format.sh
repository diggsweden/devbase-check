#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"

maven_opts=(--batch-mode --no-transfer-progress --errors -Dstyle.color=always)
readonly ACTION="${1:-check}"

emit_status() {
  [[ "${DEVBASE_CHECK_MARKERS:-0}" == "1" ]] || return 0
  printf "DEVBASE_CHECK_STATUS=%s\n" "$1"
  [[ -n "${2:-}" ]] && printf "DEVBASE_CHECK_DETAILS=%s\n" "$2"
}

check_maven() {
  if ! command -v mvn >/dev/null 2>&1; then
    print_error "mvn not found. Install with: mise install maven"
    emit_status "fail" "failed"
    return 1
  fi
}

has_pom() {
  [[ -f pom.xml ]]
}

check_format() {
  print_info "Checking Java formatting..."
  if mvn "${maven_opts[@]}" formatter:validate; then
    print_success "Java formatting check passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Java formatting check failed - run 'just lint-java-fmt-fix' to fix"
    emit_status "fail" "failed"
    return 1
  fi
}

fix_format() {
  print_info "Formatting Java code..."
  if mvn "${maven_opts[@]}" formatter:format; then
    print_success "Java code formatted"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Java formatting failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main() {
  print_header "JAVA FORMATTING (FORMATTER)"

  if ! has_pom; then
    print_warning "No pom.xml found, skipping"
    emit_status "skip" "skipped"
    return 0
  fi

  if ! check_maven; then
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
