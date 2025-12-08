#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"

setup() {
  export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../scripts"
}

@test "check-tools.sh checks for specified tools" {
  run "$SCRIPT_DIR/check-tools.sh" bash
  
  assert_output --partial "bash"
}

@test "check-tools.sh detects missing tools" {
  run "$SCRIPT_DIR/check-tools.sh" nonexistent-tool-12345
  
  assert_failure
  assert_output --partial "Missing"
}

@test "check-tools.sh succeeds when all tools present" {
  run "$SCRIPT_DIR/check-tools.sh" bash sh
  
  assert_success
}

@test "check-tools.sh handles multiple missing tools" {
  run "$SCRIPT_DIR/check-tools.sh" bash nonexistent1 sh nonexistent2
  
  assert_failure
  assert_output --partial "nonexistent1"
  assert_output --partial "nonexistent2"
}
