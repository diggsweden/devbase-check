#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Console summary module for devbase-check
# Outputs a formatted table to the terminal
#
# Required interface functions:
#   summary_init $linter_count
#   summary_add_result $name $tool $status $duration $details
#   summary_finalize $total $passed $failed $skipped

# shellcheck source=../utils/colors.sh
SUMMARY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SUMMARY_SCRIPT_DIR}/../utils/colors.sh"

# Storage for results (to print in table format at finalize)
declare -a _CONSOLE_RESULTS=()
declare -i _CONSOLE_PASSED=0
declare -i _CONSOLE_FAILED=0
declare -i _CONSOLE_SKIPPED=0
declare -i _CONSOLE_NA=0

# Initialize summary output
# Called once at start
summary_init() {
  local linter_count="$1"
  _CONSOLE_RESULTS=()
  _CONSOLE_PASSED=0
  _CONSOLE_FAILED=0
  _CONSOLE_SKIPPED=0
  _CONSOLE_NA=0
}

# Add a linter result
# Called for each linter after it runs
summary_add_result() {
  local linter_name="$1"
  local tool="$2"
  local status="$3"
  local duration="$4"
  local details="${5:-}"

  # Store result for later printing
  _CONSOLE_RESULTS+=("${linter_name}|${tool}|${status}|${duration}|${details}")

  # Update counters
  case "$status" in
  pass) ((_CONSOLE_PASSED++)) || true ;;
  fail) ((_CONSOLE_FAILED++)) || true ;;
  skip) ((_CONSOLE_SKIPPED++)) || true ;;
  n/a) ((_CONSOLE_NA++)) || true ;;
  esac
}

# Finalize and print summary table
# Called once at end
summary_finalize() {
  local total="${1:-0}"
  local passed="${2:-$_CONSOLE_PASSED}"
  local failed="${3:-$_CONSOLE_FAILED}"
  local skipped="${4:-$_CONSOLE_SKIPPED}"

  printf "\n%-22s %-12s\n" "Check" "Tool"
  printf "%.0s-" {1..45}
  printf "\n"

  for result in "${_CONSOLE_RESULTS[@]}"; do
    IFS='|' read -r check_name tool status duration details <<<"$result"

    # Skip disabled linters entirely
    [[ "$status" == "disabled" ]] && continue

    # Format status icon
    local icon plain
    case "$status" in
    pass)
      icon="${GREEN}${CHECK}${NC}"
      plain="$CHECK"
      ;;
    skip)
      icon="${YELLOW}-${NC}"
      plain="-"
      ;;
    n/a)
      icon="${CYAN}-${NC}"
      plain="-"
      ;;
    fail)
      icon="${RED}${CROSS}${NC}"
      plain="$CROSS"
      ;;
    esac

    # Only show meaningful details
    local display_details=""
    case "$status" in
    skip) display_details="$details" ;;
    n/a) [[ "$details" != "n/a" ]] && display_details="$details" ;;
    pass | fail)
      if [[ "$details" =~ [0-9]+\ commit ]]; then
        display_details="$details"
      fi
      ;;
    esac

    # Center icon in 5-char column
    local pad=$(((5 - ${#plain}) / 2))
    local right_pad=$((5 - ${#plain} - pad))

    printf "%-22s %b%-12s%b%*s%b%*s%-30s\n" \
      "$check_name" "${DIM}" "$tool" "${NC}" "$pad" "" "$icon" "$right_pad" "" "$display_details"
  done

  printf "%.0s-" {1..45}
  printf "\n\n"

  # Summary line
  local actual_total=$((passed + failed + skipped + _CONSOLE_NA))
  printf "Total: %b%d passed%b" "${GREEN}" "$passed" "${NC}"
  ((failed > 0)) && printf ", %b%d failed%b" "${RED}" "$failed" "${NC}"
  ((skipped > 0)) && printf ", %b%d skipped%b" "${YELLOW}" "$skipped" "${NC}"
  ((_CONSOLE_NA > 0)) && printf ", %b%d n/a%b" "${CYAN}" "$_CONSOLE_NA" "${NC}"
  printf " (of %d)\n\n" "$actual_total"

  # Help message
  if ((failed > 0)); then
    printf "%bRun %bjust lint-fix%b to auto-fix some issues%b\n\n" \
      "${YELLOW}" "${GREEN}" "${YELLOW}" "${NC}"
    return 1
  fi

  return 0
}
