#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-mock/stub.bash"

setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  export LINTERS_DIR="${BATS_TEST_DIRNAME}/../linters"
  cd "$TEST_DIR"
  git init -q
}

teardown() {
  unstub conform 2>/dev/null || true
  temp_del "$TEST_DIR"
}

@test "commits.sh skips on default branch" {
  run --separate-stderr "$LINTERS_DIR/commits.sh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "no commits to check"
}
