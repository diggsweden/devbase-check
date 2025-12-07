#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Color and symbol definitions for consistent output

# Terminal colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export CYAN_BOLD='\033[1;36m'
export GRAY='\033[0;90m'
export DIM='\033[2m'
export BOLD='\033[1m'
export NC='\033[0m'

# Unicode symbols
export CHECK='✓'
export CROSS='✗'
export WARN='!'
export INFO='ⓘ'
export ARROW='→'

# Helper functions for linter scripts
print_header() {
  printf "\n%b************ %s ***********%b\n" "${YELLOW}" "$1" "${NC}"
}

print_success() {
  printf "%b%s %s%b\n" "${GREEN}" "${CHECK}" "$1" "${NC}"
}

print_error() {
  printf "%b%s %s%b\n" "${RED}" "${CROSS}" "$1" "${NC}" >&2
}

print_warning() {
  printf "%b%s %s%b\n" "${YELLOW}" "${WARN}" "$1" "${NC}" >&2
}

print_info() {
  printf "%b%s %s%b\n" "${CYAN}" "${INFO}" "$1" "${NC}"
}

print_arrow() {
  printf "%b%s %s%b\n" "${BLUE}" "${ARROW}" "$1" "${NC}"
}

# Helper functions for justfile (call from bash recipes)
# Usage: source colors.sh && just_header "Title" "command"
just_header() {
  local text="$1"
  local cmd="${2:-}"
  if [[ -n "$cmd" ]]; then
    printf "%b%s%b\n" "${CYAN_BOLD}" "$text" "${NC}"
    printf " %b%s%b\n" "${DIM}" "$cmd" "${NC}"
  else
    printf "%b%s%b\n" "${CYAN_BOLD}" "$text" "${NC}"
  fi
}

# Run command, show output only on failure
# Usage: source colors.sh && just_run "description" arg1 arg2 ...
just_run() {
  local desc="$1"
  shift
  printf " %b%s%b\n" "${DIM}" "$*" "${NC}"
  local output
  if output=$("$@" 2>&1); then
    printf "%b%s%b %s completed\n" "${GREEN}" "${CHECK}" "${NC}" "$desc"
    return 0
  else
    local code=$?
    printf "%b%s%b %s failed\n" "${RED}" "${CROSS}" "${NC}" "$desc"
    printf "%s\n" "$output"
    return $code
  fi
}

just_success() {
  printf "%b%s%b %s\n" "${GREEN}" "${CHECK}" "${NC}" "$1"
}

just_error() {
  printf "%b%s%b %s\n" "${RED}" "${CROSS}" "${NC}" "$1"
}

just_warn() {
  printf "%b%s%b %s\n" "${YELLOW}" "${WARN}" "${NC}" "$1"
}
