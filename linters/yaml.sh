#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
source "${SCRIPT_DIR}/../utils/mise-tool.sh"

readonly ACTION="${1:-check}"

# Default config with standard exclusions
readonly DEFAULT_CONFIG="${SCRIPT_DIR}/config/.yamlfmt"

find_yaml_files() {
  find . -type f \( -name "*.yml" -o -name "*.yaml" \) \
    -not -path "./.git/*" \
    -not -path "./target/*" \
    -not -path "./node_modules/*" \
    -not -path "./vendor/*" \
    2>/dev/null
}

has_local_config() {
  local config_files=(
    ".yamlfmt"
    ".yamlfmt.yml"
    ".yamlfmt.yaml"
    "yamlfmt.yml"
    "yamlfmt.yaml"
  )

  for file in "${config_files[@]}"; do
    [[ -f "$file" ]] && return 0
  done

  return 1
}

get_config_flag() {
  # If project has its own config, do nothing
  if has_local_config; then
    return 0
  fi

  # Otherwise, use default config if it exists
  if [[ -f "${DEFAULT_CONFIG}" ]]; then
    printf "%s" "-conf ${DEFAULT_CONFIG}"
  fi
}

check_yaml() {
  local conf_flag
  conf_flag=$(get_config_flag)
  # shellcheck disable=SC2086
  if yamlfmt -lint $conf_flag .; then
    print_success "YAML linting passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "YAML linting failed - run 'just lint-yaml-fix' to fix"
    emit_status "fail" "failed"
    return 1
  fi
}

fix_yaml() {
  local conf_flag
  conf_flag=$(get_config_flag)
  # shellcheck disable=SC2086
  if yamlfmt $conf_flag .; then
    print_success "YAML files formatted"
    emit_status "pass" "ok"
    return 0
  else
    print_error "Failed to format YAML files"
    emit_status "fail" "failed"
    return 1
  fi
}

main() {
  print_header "YAML LINTING (YAMLFMT)"
  fail_if_mise_install_incomplete || return 1

  local files
  files=$(find_yaml_files)

  if [[ -z "$files" ]]; then
    print_info "No YAML files found to check"
    emit_status "na" "n/a"
    return 0
  fi

  if ! command -v yamlfmt >/dev/null 2>&1; then
    print_warning "yamlfmt not found in PATH - skipping YAML linting"
    echo "  Install: mise install"
    emit_status "skip" "not in PATH"
    return 0
  fi

  case "$ACTION" in
  check) check_yaml ;;
  fix) fix_yaml ;;
  *)
    print_error "Unknown action: $ACTION"
    printf "Usage: %s [check|fix]\n" "$0"
    emit_status "fail" "failed"
    return 1
    ;;
  esac
}

main
