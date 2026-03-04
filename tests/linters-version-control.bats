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
  export DEVBASE_CHECK_MARKERS=1
  cd "$TEST_DIR"
  init_git_repo
}

teardown() {
  common_teardown
}

@test "version-control.sh accepts clean working directory" {
  run --separate-stderr "$LINTERS_DIR/version-control.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "All changes are under version control"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "version-control.sh rejects unversioned file" {
  touch dummy-file
  run "$LINTERS_DIR/version-control.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
  assert_output --partial "Some changes are not under version control!

  This can happen if

    1. You forgot to version control your changes
    2. A linter automatically fixed a problem or reformatted the code.

  Please accept or discard any outstanding changes and try again."
}

@test "version-control.sh fails outside git repository" {
  nonrepo_dir=$(mktemp -d)

  run bash -c "cd '$nonrepo_dir' && '$LINTERS_DIR/version-control.sh'"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
  assert_output --partial "Not a Git repository - cannot verify version control state"

  rm -rf "$nonrepo_dir"
}
