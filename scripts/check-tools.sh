#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
source "${SCRIPT_DIR}/../utils/mise-tool.sh"

activate_mise() {
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise hook-env -s bash 2>/dev/null)" || true
  fi
}

check_tool() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    # Annotate where the tool came from so users can spot a stray system
    # copy when a mise-pinned version was expected.
    if [[ -n "$(mise_tool_path "$tool")" ]]; then
      print_success "$tool (mise)"
    else
      print_success "$tool (system)"
    fi
    return 0
  fi
  if mise_has_missing_pins; then
    print_error "$tool (mise install is incomplete — run: mise install)"
  else
    print_error "$tool"
  fi
  return 1
}

check_devtools() {
  local devtools_dir="${XDG_DATA_HOME:-$HOME/.local/share}/devbase-check"
  if [[ -d "$devtools_dir" ]]; then
    print_success "devbase-check ($devtools_dir)"
    return 0
  else
    print_error "devbase-check (not installed)"
    return 1
  fi
}

main() {
  activate_mise

  local check_devtools_flag=false
  local tools=()

  for arg in "$@"; do
    if [[ "$arg" == "--check-devtools" ]]; then
      check_devtools_flag=true
    else
      tools+=("$arg")
    fi
  done

  if [[ ${#tools[@]} -eq 0 ]]; then
    tools=(mise git just)
  fi

  local missing_count=0

  printf "Checking tools...\n"
  printf "=================\n"

  if [[ "$check_devtools_flag" == true ]]; then
    if ! check_devtools; then
      missing_count=$((missing_count + 1))
    fi
  fi

  for tool in "${tools[@]}"; do
    if ! check_tool "$tool"; then
      missing_count=$((missing_count + 1))
    fi
  done

  printf "\n"

  if [[ $missing_count -gt 0 ]]; then
    print_error "Missing $missing_count tools!"
    printf "\n"
    print_info "Run: mise install"
    return 1
  else
    print_success "All tools available!"
    return 0
  fi
}

main "$@"
