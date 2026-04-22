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

# shellcheck source=../utils/mise-tool.sh
source "${SCRIPT_DIR}/../utils/mise-tool.sh"

# Base linters
LINTERS=(
  "Working Tree|git|just lint-version-control"
  "Commits|gommitlint|just lint-commits"
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

extract_status_marker() {
  local output="$1"
  local marker
  marker=$(grep -oE '^DEVBASE_CHECK_STATUS=(pass|fail|skip|na|n/a|disabled)$' <<<"$output" | tail -1 || true)
  printf "%s" "${marker#DEVBASE_CHECK_STATUS=}"
}

extract_details_marker() {
  local output="$1"
  local marker
  marker=$(grep -oE '^DEVBASE_CHECK_DETAILS=.*$' <<<"$output" | tail -1 || true)
  printf "%s" "${marker#DEVBASE_CHECK_DETAILS=}"
}

strip_status_markers() {
  local output="$1"
  grep -vE '^DEVBASE_CHECK_(STATUS|DETAILS)=' <<<"$output" || true
}

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

  # Rust linters - check for individual recipes
  if grep -qE "^\s+lint-rust-clippy(\s|#|$)" <<<"$recipes"; then
    LINTERS+=("Rust Clippy|clippy|just lint-rust-clippy")
  fi
  if grep -qE "^\s+lint-rust-fmt(\s|#|$)" <<<"$recipes"; then
    LINTERS+=("Rust Fmt|rustfmt|just lint-rust-fmt")
  fi
  # Audit lives outside the lint umbrella but `just verify` still surfaces it
  # in the summary so security regressions are visible alongside lint state.
  if grep -qE "^\s+rust-audit(\s|#|$)" <<<"$recipes"; then
    LINTERS+=("Rust Audit|cargo-audit|just rust-audit")
  fi
}

run_linters() {
  local failed=0

  for linter_def in "${LINTERS[@]}"; do
    IFS='|' read -r check tool cmd <<<"$linter_def"

    local raw_output output exit_code=0
    raw_output=$(DEVBASE_CHECK_MARKERS=1 eval "$cmd" 2>&1) || exit_code=$?

    output=$(strip_status_markers "$raw_output")
    [[ -n "$output" ]] && echo "$output"

    # Store output for summary module
    OUTPUTS["$check"]="$output"

    # Parse status from output
    local status details
    local status_marker details_marker
    status_marker=$(extract_status_marker "$raw_output")
    details_marker=$(extract_details_marker "$raw_output")

    if [[ -n "$status_marker" ]]; then
      case "$status_marker" in
      na) status="n/a" ;;
      *) status="$status_marker" ;;
      esac

      case "$status" in
      fail)
        details="${details_marker:-failed}"
        ((failed++))
        ;;
      skip) details="${details_marker:-skipped}" ;;
      n/a) details="${details_marker:-n/a}" ;;
      disabled) details="" ;;
      *) details="${details_marker:-ok}" ;;
      esac
    elif [[ $exit_code -eq 0 ]]; then
      if [[ -z "${output// /}" ]]; then
        # Empty output = linter disabled, skip entirely
        status="disabled"
        details=""
      elif grep -q "not found in PATH" <<<"$output"; then
        status="skip"
        details="not in PATH"
      elif grep -qiE "No .* found, skipping|No pom.xml found, skipping" <<<"$output"; then
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

print_usage() {
  cat <<'EOF'
Usage: verify.sh [OPTIONS]

Runs all configured linters and prints a summary. Before running, a
preflight checks that every tool pinned in .mise.toml is installed. If
any pin is missing, verify.sh fails fast with a single actionable error
("run: mise install") instead of letting each linter fail separately.

Options:
  --ignore-missing-linters   Proceed even when mise pins are missing.
                             Linters whose tool isn't installed emit a
                             skip marker; the rest run normally. Useful
                             in CI when a subset of tools is unavailable.
  -h, --help                 Show this help.

Environment:
  DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS=1     Skip the mise-pin check entirely
                                         and fall back to whatever tool is
                                         on PATH (with a visible warning).
                                         Intended for locked-down envs.
  DEVBASE_CHECK_IGNORE_MISSING_LINTERS=1 Same as --ignore-missing-linters.
EOF
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
    --ignore-missing-linters)
      export DEVBASE_CHECK_IGNORE_MISSING_LINTERS=1
      ;;
    -h | --help)
      print_usage
      exit 0
      ;;
    *)
      printf 'verify.sh: unknown argument: %s\n\n' "$arg" >&2
      print_usage >&2
      exit 2
      ;;
    esac
  done
}

# Single preflight so a broken mise install doesn't cascade the same error
# through every linter. Three outcomes:
#   - no missing pins: proceed silently.
#   - missing pins + opt-out (flag/env): print one warning + proceed.
#   - missing pins + no opt-out: print one error + exit 1.
# Either way, DEVBASE_CHECK_PREFLIGHT_DONE=1 is exported so the per-linter
# guard in utils/mise-tool.sh becomes a no-op.
mise_preflight() {
  mise_has_missing_pins || return 0

  local missing=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && missing+=("$line")
  done < <(mise_list_missing_pins)

  if [[ "${DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS:-0}" == "1" ]]; then
    print_warning "mise install is incomplete; falling back to system tools"
    ((${#missing[@]})) && printf '  - %s\n' "${missing[@]}"
    printf '\n'
    return 0
  fi

  if [[ "${DEVBASE_CHECK_IGNORE_MISSING_LINTERS:-0}" == "1" ]]; then
    print_warning "mise install is incomplete; affected linters will be skipped"
    ((${#missing[@]})) && printf '  - %s\n' "${missing[@]}"
    printf '  Fix: mise install\n\n'
    return 0
  fi

  print_error "mise install is incomplete — run: mise install"
  ((${#missing[@]})) && printf '  - %s\n' "${missing[@]}"
  printf '  (to skip: --ignore-missing-linters or DEVBASE_CHECK_IGNORE_MISSING_LINTERS=1)\n'
  return 1
}

main() {
  parse_args "$@"

  # Load appropriate summary module based on CI environment
  load_summary_module

  if ! mise_preflight; then
    return 1
  fi
  export DEVBASE_CHECK_PREFLIGHT_DONE=1

  detect_language_linters

  run_linters
  local linter_exit=$?

  print_summary
  local summary_exit=$?

  # Exit with failure if either failed
  return $((linter_exit || summary_exit))
}

main "$@"
