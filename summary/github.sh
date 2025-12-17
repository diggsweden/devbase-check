#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# GitHub Actions summary module for devbase-check
# Writes markdown summary to GITHUB_STEP_SUMMARY
#
# Required interface functions:
#   summary_init $linter_count
#   summary_add_result $name $tool $status $duration $details
#   summary_finalize $total $passed $failed $skipped

# Storage for results
declare -a _GH_RESULTS=()
declare -a _GH_FAILURES=()
declare -i _GH_PASSED=0
declare -i _GH_FAILED=0
declare -i _GH_SKIPPED=0
declare -i _GH_NA=0
declare _GH_START_TIME=""

# Initialize summary output
# Called once at start
summary_init() {
  local linter_count="$1"
  _GH_RESULTS=()
  _GH_FAILURES=()
  _GH_PASSED=0
  _GH_FAILED=0
  _GH_SKIPPED=0
  _GH_NA=0
  _GH_START_TIME=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

  # Only write to file if GITHUB_STEP_SUMMARY is set
  [[ -z "${GITHUB_STEP_SUMMARY:-}" ]] && return

  cat <<EOF >>"$GITHUB_STEP_SUMMARY"
# Linting Results

**Linters Run:** ${linter_count}
**Started:** ${_GH_START_TIME}

---

## Individual Linter Results

| Linter | Tool | Status | Details |
|--------|------|--------|---------|
EOF
}

# Add a linter result
# Called for each linter after it runs
summary_add_result() {
  local linter_name="$1"
  local tool="$2"
  local status="$3"
  local duration="$4"
  local details="${5:-}"
  local output="${6:-}"

  # Skip disabled linters
  [[ "$status" == "disabled" ]] && return

  # Store for finalize
  _GH_RESULTS+=("${linter_name}|${tool}|${status}|${duration}|${details}")

  # Update counters
  case "$status" in
  pass) ((_GH_PASSED++)) || true ;;
  fail)
    ((_GH_FAILED++)) || true
    # Store failure details for expandable section
    _GH_FAILURES+=("${linter_name}|${output}")
    ;;
  skip) ((_GH_SKIPPED++)) || true ;;
  n/a) ((_GH_NA++)) || true ;;
  esac

  # Write row immediately if GITHUB_STEP_SUMMARY is set
  [[ -z "${GITHUB_STEP_SUMMARY:-}" ]] && return

  local status_emoji
  case "$status" in
  pass) status_emoji="Pass" ;;
  fail) status_emoji="Fail" ;;
  skip) status_emoji="Skipped" ;;
  n/a) status_emoji="N/A" ;;
  esac

  local detail_text="${details:-Success}"
  if [[ "$status" == "fail" ]]; then
    detail_text="[View errors below](#-failed-linters)"
  fi

  printf "| %s | %s | %s | %s |\n" \
    "$linter_name" "$tool" "$status_emoji" "$detail_text" >>"$GITHUB_STEP_SUMMARY"
}

# Finalize summary output
# Called once at end
summary_finalize() {
  local total="${1:-0}"
  local passed="${2:-$_GH_PASSED}"
  local failed="${3:-$_GH_FAILED}"
  local skipped="${4:-$_GH_SKIPPED}"

  [[ -z "${GITHUB_STEP_SUMMARY:-}" ]] && return

  # Add failed linters section if any failures
  if ((${#_GH_FAILURES[@]} > 0)); then
    cat <<EOF >>"$GITHUB_STEP_SUMMARY"

---

## Failed Linters

EOF

    for failure in "${_GH_FAILURES[@]}"; do
      name="${failure%%|*}"
      output="${failure#*|}"
      cat <<EOF >>"$GITHUB_STEP_SUMMARY"

<details>
<summary><b>${name}</b> - Click to expand error details</summary>

<br>

### Output:
\`\`\`
${output}
\`\`\`

</details>

EOF
    done
  fi

  # Summary section
  cat <<EOF >>"$GITHUB_STEP_SUMMARY"

---

### Summary

**Pass:** ${passed} | **Fail:** ${failed} | **Skipped:** ${skipped} | **N/A:** ${_GH_NA}

EOF

  if [[ $failed -eq 0 ]]; then
    printf "### All linters passed successfully!\n" >>"$GITHUB_STEP_SUMMARY"
  else
    printf "### Please fix the failing linters before merging.\n" >>"$GITHUB_STEP_SUMMARY"
  fi
}
