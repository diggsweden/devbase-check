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
  unstub gitleaks 2>/dev/null || true
  common_teardown
}

@test "secrets.sh runs gitleaks" {
  stub_repeated gitleaks "true"
  
  run --separate-stderr "$LINTERS_DIR/secrets.sh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "No secrets"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "secrets.sh fails when secrets detected" {
  stub_repeated gitleaks "exit 1"
  
  run --separate-stderr "$LINTERS_DIR/secrets.sh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}
