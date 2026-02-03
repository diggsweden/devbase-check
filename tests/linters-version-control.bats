#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-mock/stub.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  export LINTERS_DIR="${DEVTOOLS_ROOT}/linters"
  cd "$TEST_DIR"
  init_git_repo
}

teardown() {
  unstub conform 2>/dev/null || true
  common_teardown
}

@test "version-control.sh accepts clean working directory" {
  run --separate-stderr "$LINTERS_DIR/version-control.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "All changes are under version control"
}

@test "version-control.sh rejects unversioned file" {
  touch dummy-file
  run "$LINTERS_DIR/version-control.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  assert_output --partial "Some changes are not under version control!"
}
