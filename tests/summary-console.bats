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
  cd "$TEST_DIR"
}

teardown() {
  common_teardown
}

@test "console.sh summary_init resets state" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  # Add some results first
  summary_init 5
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "ok"
  
  # Re-init should reset
  summary_init 3
  
  # Finalize and check count
  run summary_finalize 0 0 0 0
  
  # Should only show header - no results (all cleared)
  assert_output --partial "Check"
  assert_output --partial "Total:"
}

@test "console.sh summary_add_result tracks passed" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  summary_init 2
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "5 files"
  summary_add_result "Shell" "shellcheck" "pass" "0.3" "ok"
  
  run summary_finalize
  assert_output --partial "2 passed"
}

@test "console.sh summary_add_result tracks failed" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  summary_init 2
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "ok"
  summary_add_result "Shell" "shellcheck" "fail" "1.0" "failed"
  
  run summary_finalize
  assert_output --partial "1 passed"
  assert_output --partial "1 failed"
  assert_failure
}

@test "console.sh summary_add_result tracks skipped" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  summary_init 1
  summary_add_result "License" "reuse" "skip" "0" "skipped"
  
  run summary_finalize
  assert_output --partial "1 skipped"
}

@test "console.sh summary_add_result tracks n/a" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  summary_init 1
  summary_add_result "Containers" "hadolint" "n/a" "0" "n/a"
  
  run summary_finalize
  assert_output --partial "1 n/a"
}

@test "console.sh summary_finalize shows table with linter names" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  summary_init 3
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "ok"
  summary_add_result "Shell Scripts" "shellcheck" "pass" "0.3" "ok"
  summary_add_result "License" "reuse" "skip" "0" "skipped"
  
  run summary_finalize
  assert_output --partial "YAML"
  assert_output --partial "Shell Scripts"
  assert_output --partial "License"
  assert_output --partial "yamlfmt"
  assert_output --partial "shellcheck"
  assert_output --partial "reuse"
}

@test "console.sh summary_finalize skips disabled linters" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  summary_init 2
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "ok"
  summary_add_result "XML" "xmllint" "disabled" "0" ""
  
  run summary_finalize
  assert_output --partial "YAML"
  refute_output --partial "XML"
}

@test "console.sh summary_finalize shows help message on failure" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  summary_init 1
  summary_add_result "Shell" "shellcheck" "fail" "1.0" "failed"
  
  run summary_finalize
  assert_output --partial "just lint-fix"
  assert_failure
}

@test "console.sh summary_finalize returns success when all pass" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  summary_init 2
  summary_add_result "YAML" "yamlfmt" "pass" "0.5" "ok"
  summary_add_result "Shell" "shellcheck" "pass" "0.3" "ok"
  
  run summary_finalize
  assert_success
}

@test "console.sh shows details for skipped linters" {
  source "${DEVTOOLS_ROOT}/summary/console.sh"
  
  summary_init 1
  summary_add_result "License" "reuse" "skip" "0" "not in PATH"
  
  run summary_finalize
  assert_output --partial "not in PATH"
}
