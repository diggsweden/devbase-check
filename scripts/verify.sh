#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINTERS_DIR="${SCRIPT_DIR}/../linters"
# shellcheck source=../utils/colors.sh
source "${SCRIPT_DIR}/../utils/colors.sh"

# Base linters
LINTERS=(
  "Commits|conform|just lint-commits"
  "Secrets|gitleaks|just lint-secrets"
  "YAML|yamlfmt|just lint-yaml"
  "Markdown|rumdl|just lint-markdown"
  "Shell Scripts|shellcheck|just lint-shell"
  "Shell Format|shfmt|just lint-shell-fmt"
  "GitHub Actions|actionlint|just lint-actions"
  "License|reuse|just lint-license"
  "Containers|hadolint|just lint-container"
  "XML|xmllint|just lint-xml"
)

declare -A RESULTS

detect_language_linters() {
  local recipes
  recipes=$(just --list 2>&1 || true)

  # Java linters - check for individual recipes
  if grep -qE "^\s+lint-java-checkstyle(\s|#|$)" <<<"$recipes"; then
    LINTERS+=("Java Checkstyle|checkstyle|just lint-java-checkstyle")
  fi
  if grep -qE "^\s+lint-java-pmd(\s|#|$)" <<<"$recipes"; then
    LINTERS+=("Java PMD|pmd|just lint-java-pmd")
  fi
  if grep -qE "^\s+lint-java-spotbugs(\s|#|$)" <<<"$recipes"; then
    LINTERS+=("Java SpotBugs|spotbugs|just lint-java-spotbugs")
  fi

  # Node linters - check for individual recipes
  if grep -qE "^\s+lint-node-eslint(\s|#|$)" <<<"$recipes"; then
    LINTERS+=("Node ESLint|eslint|just lint-node-eslint")
  fi
  if grep -qE "^\s+lint-node-format(\s|#|$)" <<<"$recipes"; then
    LINTERS+=("Node Format|prettier|just lint-node-format")
  fi
  if grep -qE "^\s+lint-node-ts-types(\s|#|$)" <<<"$recipes"; then
    LINTERS+=("Node Types|tsc|just lint-node-ts-types")
  fi
}

run_linters() {
  local failed=0

  for linter_def in "${LINTERS[@]}"; do
    IFS='|' read -r check tool cmd <<<"$linter_def"

    local output exit_code=0
    output=$(eval "$cmd" 2>&1) || exit_code=$?
    echo "$output"

    # Parse status from output
    local status details
    if [[ $exit_code -eq 0 ]]; then
      if grep -q "not found in PATH" <<<"$output"; then
        status="skip"
        details="not in PATH"
      elif grep -qE "No .* (files? found|to check)|no commits to check" <<<"$output"; then
        status="n/a"
        details="n/a"
      else
        status="pass"
        details=$(grep -oE "[0-9]+ (files?|commits|workflows)" <<<"$output" | head -1)
        : "${details:=ok}"
      fi
    else
      status="fail"
      details="failed"
      ((failed++))
    fi

    RESULTS["$check"]="$status|$tool|$details"
  done

  return $failed
}

print_summary() {
  local passed=0 skipped=0 na=0 failed=0

  printf "\n%-22s %-12s\n" "Check" "Tool"
  printf "%.0s-" {1..45}
  printf "\n"

  for linter_def in "${LINTERS[@]}"; do
    IFS='|' read -r check_name tool _ <<<"$linter_def"
    IFS='|' read -r status real_tool raw_details <<<"${RESULTS[$check_name]}"

    # Format status icon
    local icon plain
    case "$status" in
    pass)
      # shellcheck disable=SC2153
      icon="${GREEN}${CHECK}${NC}"
      plain="✓"
      ((passed++))
      ;;
    skip)
      icon="${YELLOW}-${NC}"
      plain="-"
      ((skipped++))
      ;;
    n/a)
      icon="${CYAN}-${NC}"
      plain="-"
      ((na++))
      ;;
    fail)
      # shellcheck disable=SC2153
      icon="${RED}${CROSS}${NC}"
      plain="✗"
      ((failed++))
      ;;
    esac

    # Only show meaningful details
    local details=""
    case "$status" in
    skip) details="$raw_details" ;;
    n/a) [[ $raw_details != "n/a" ]] && details="$raw_details" ;;
    pass | fail)
      if [[ $raw_details =~ [0-9]+\ commit ]]; then
        details="$raw_details"
      fi
      ;;
    esac

    # Center icon in 5-char column
    local pad=$(((5 - ${#plain}) / 2))
    local right_pad=$((5 - ${#plain} - pad))

    printf "%-22s %b%-12s%b%*s%b%*s%-30s\n" \
      "$check_name" "${DIM}" "$real_tool" "${NC}" "$pad" "" "$icon" "$right_pad" "" "$details"
  done

  printf "%.0s-" {1..45}
  printf "\n\n"

  # Summary line
  local total=$((passed + failed + skipped + na))
  printf "Total: %b%d passed%b" "${GREEN}" "$passed" "${NC}"
  ((failed > 0)) && printf ", %b%d failed%b" "${RED}" "$failed" "${NC}"
  ((skipped > 0)) && printf ", %b%d skipped%b" "${YELLOW}" "$skipped" "${NC}"
  ((na > 0)) && printf ", %b%d n/a%b" "${CYAN}" "$na" "${NC}"
  printf " (of %d)\n\n" "$total"

  # Help message
  if ((failed > 0)); then
    printf "%bRun %bjust lint-fix%b to auto-fix some issues%b\n\n" \
      "${YELLOW}" "${GREEN}" "${YELLOW}" "${NC}"
    return 1
  fi

  return 0
}

main() {
  detect_language_linters

  run_linters
  local linter_exit=$?

  print_summary
  local summary_exit=$?

  # Exit with failure if either failed
  return $((linter_exit || summary_exit))
}

main
