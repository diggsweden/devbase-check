#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  cd "$TEST_DIR"
  cp "$DEVTOOLS_ROOT/justfile" justfile
  mkdir -p tests/libs
  stub_repeated bats 'exit "${BATS_STUB_STATUS:-0}"'
}

teardown() {
  common_teardown
}

@test "all just test recipes propagate Bats failures and runner errors" {
  local code
  for code in 1 2; do
    export BATS_STUB_STATUS="$code"
    run just test
    assert_failure
    run just test-verbose
    assert_failure
    run just test-file example.bats
    assert_failure
    run just test-filter example
    assert_failure
  done
}

@test "all just test recipes succeed when Bats succeeds" {
  export BATS_STUB_STATUS=0
  run just test
  assert_success
  run just test-verbose
  assert_success
  run just test-file example.bats
  assert_success
  run just test-filter example
  assert_success
}
