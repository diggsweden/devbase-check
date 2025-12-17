#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINTERS_DIR="${SCRIPT_DIR}/../linters"

# shellcheck source=../utils/colors.sh
source "${SCRIPT_DIR}/../utils/colors.sh"

# shellcheck source=../summary/common.sh
source "${SCRIPT_DIR}/../summary/common.sh"

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
declare -A OUTPUTS

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

    # Store output for summary module
    OUTPUTS["$check"]="$output"

    # Parse status from output
    local status details
    if [[ $exit_code -eq 0 ]]; then
      if [[ -z "${output// /}" ]]; then
        # Empty output = linter disabled, skip entirely
        status="disabled"
        details=""
      elif grep -q "not found in PATH" <<<"$output"; then
        status="skip"
        details="not in PATH"
      elif grep -qiE "Skipping|Skip" <<<"$output"; then
        status="skip"
        details="skipped"
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

  # Count results first
  for linter_def in "${LINTERS[@]}"; do
    IFS='|' read -r check_name _ _ <<<"$linter_def"
    IFS='|' read -r status _ _ <<<"${RESULTS[$check_name]}"

    case "$status" in
    pass) ((passed++)) ;;
    skip) ((skipped++)) ;;
    n/a) ((na++)) ;;
    fail) ((failed++)) ;;
    esac
  done

  # Initialize summary module
  local total=$((passed + failed + skipped + na))
  summary_init "$total"

  # Add results to summary module
  for linter_def in "${LINTERS[@]}"; do
    IFS='|' read -r check_name tool _ <<<"$linter_def"
    IFS='|' read -r status real_tool raw_details <<<"${RESULTS[$check_name]}"

    # Skip disabled linters entirely
    [[ "$status" == "disabled" ]] && continue

    # Get output for this linter (for error details in GitHub summary)
    local output="${OUTPUTS[$check_name]:-}"

    summary_add_result "$check_name" "$real_tool" "$status" "0" "$raw_details" "$output"
  done

  # Finalize summary
  summary_finalize "$total" "$passed" "$failed" "$skipped"
  local summary_exit=$?

  return $summary_exit
}

main() {
  # Load appropriate summary module based on CI environment
  load_summary_module

  detect_language_linters

  run_linters
  local linter_exit=$?

  print_summary
  local summary_exit=$?

  # Exit with failure if either failed
  return $((linter_exit || summary_exit))
}

main
