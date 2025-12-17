#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  export DEVTOOLS_ROOT="${BATS_TEST_DIRNAME}/.."
  export SUMMARY_FILE="${TEST_DIR}/github-summary.md"
  export GITHUB_STEP_SUMMARY="${SUMMARY_FILE}"
  cd "$TEST_DIR"
}

teardown() {
  unset GITHUB_STEP_SUMMARY
  common_teardown
}

@test "github.sh summary_init creates header with linter count" {
  source "${DEVTOOLS_ROOT}/summary/github.sh"
  
  summary_init 5
  
  assert_file_exists "$SUMMARY_FILE"
  run cat "$SUMMARY_FILE"
  assert_output --partial "Linting Results"
  assert_output --partial "Linters Run:** 5"
  assert_output --partial "| Linter | Tool | Status | Details |"
}

@test "github.sh summary_add_result adds pass row" {
  source "${DEVTOOLS_ROOT}/summary/github.sh"
  
  summary_init 1
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "5 files"
  
  run cat "$SUMMARY_FILE"
  assert_output --partial "| YAML | yamlfmt | Pass | 5 files |"
}

@test "github.sh summary_add_result adds fail row with link" {
  source "${DEVTOOLS_ROOT}/summary/github.sh"
  
  summary_init 1
  summary_add_result "Shell" "shellcheck" "fail" "1.0" "failed" "Error in script.sh line 5"
  
  run cat "$SUMMARY_FILE"
  assert_output --partial "| Shell | shellcheck | Fail | [View errors below]"
}

@test "github.sh summary_add_result adds skip row" {
  source "${DEVTOOLS_ROOT}/summary/github.sh"
  
  summary_init 1
  summary_add_result "License" "reuse" "skip" "0" "skipped"
  
  run cat "$SUMMARY_FILE"
  assert_output --partial "| License | reuse | Skipped | skipped |"
}

@test "github.sh summary_add_result skips disabled linters" {
  source "${DEVTOOLS_ROOT}/summary/github.sh"
  
  summary_init 1
  summary_add_result "XML" "xmllint" "disabled" "0" ""
  
  run cat "$SUMMARY_FILE"
  refute_output --partial "| XML |"
}

@test "github.sh summary_finalize adds summary section" {
  source "${DEVTOOLS_ROOT}/summary/github.sh"
  
  summary_init 3
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "ok"
  summary_add_result "Shell" "shellcheck" "pass" "0.3" "ok"
  summary_add_result "License" "reuse" "skip" "0" "skipped"
  summary_finalize 3 2 0 1
  
  run cat "$SUMMARY_FILE"
  assert_output --partial "### Summary"
  assert_output --partial "Pass:** 2"
  assert_output --partial "Fail:** 0"
  assert_output --partial "Skipped:** 1"
  assert_output --partial "All linters passed successfully!"
}

@test "github.sh summary_finalize shows failure message when linters fail" {
  source "${DEVTOOLS_ROOT}/summary/github.sh"
  
  summary_init 2
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "ok"
  summary_add_result "Shell" "shellcheck" "fail" "1.0" "failed" "Error output here"
  summary_finalize 2 1 1 0
  
  run cat "$SUMMARY_FILE"
  assert_output --partial "Please fix the failing linters"
}

@test "github.sh includes expandable error details for failures" {
  source "${DEVTOOLS_ROOT}/summary/github.sh"
  
  summary_init 1
  summary_add_result "Shell" "shellcheck" "fail" "1.0" "failed" "In script.sh line 5:
    echo \$foo
         ^-- SC2086: Double quote to prevent globbing"
  summary_finalize 1 0 1 0
  
  run cat "$SUMMARY_FILE"
  assert_output --partial "## Failed Linters"
  assert_output --partial "<details>"
  assert_output --partial "<summary><b>Shell</b>"
  assert_output --partial "SC2086"
  assert_output --partial "</details>"
}

@test "github.sh does nothing if GITHUB_STEP_SUMMARY not set" {
  unset GITHUB_STEP_SUMMARY
  source "${DEVTOOLS_ROOT}/summary/github.sh"
  
  summary_init 1
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "ok"
  summary_finalize 1 1 0 0
  
  # Should not create file
  assert_file_not_exists "$SUMMARY_FILE"
}
