#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
source "${SCRIPT_DIR}/../utils/mise-tool.sh"

readonly ACTION="${1:-check}"
shift || true
readonly DISABLE="${1:-MD013}"

readonly EXCLUDE=".github-shared,node_modules,vendor,target,CHANGELOG.md"

find_markdown_files() {
  find . -type f -name "*.md" \
    -not -path "./.git/*" \
    -not -path "./target/*" \
    -not -path "./node_modules/*" \
    -not -path "./vendor/*" \
    -not -path "./.github-shared/*" \
    -not -name "CHANGELOG.md" \
    2>/dev/null
}

check_markdown() {
  local args=(check . --exclude "$EXCLUDE")
  [[ -n "$DISABLE" ]] && args+=(--disable "$DISABLE")
  if rumdl "${args[@]}"; then
    print_success "Markdown linting passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Markdown linting failed - run 'just lint-markdown-fix' to fix"
    emit_status "fail" "failed"
    return 1
  fi
}

fix_markdown() {
  local args=(check --fix . --exclude "$EXCLUDE")
  [[ -n "$DISABLE" ]] && args+=(--disable "$DISABLE")
  if rumdl "${args[@]}"; then
    print_success "Markdown files fixed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Failed to fix markdown files"
    emit_status "fail" "failed"
    return 1
  fi
}

main() {
  print_header "MARKDOWN LINTING (RUMDL)"
  fail_if_mise_install_incomplete rumdl || return 1

  local files
  files=$(find_markdown_files)

  if [[ -z "$files" ]]; then
    print_info "No Markdown files found to check"
    emit_status "na" "n/a"
    return 0
  fi

  if ! command -v rumdl >/dev/null 2>&1; then
    print_warning "rumdl not found in PATH - skipping markdown linting"
    echo "  Install: mise install"
    emit_status "skip" "not in PATH"
    return 0
  fi

  case "$ACTION" in
  check) check_markdown ;;
  fix) fix_markdown ;;
  *)
    print_error "Unknown action: $ACTION"
    printf "Usage: %s [check|fix]\n" "$0"
    emit_status "fail" "failed"
    return 1
    ;;
  esac
}

main
