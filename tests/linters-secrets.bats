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
  unstub gitleaks 2>/dev/null || true
  temp_del "$TEST_DIR"
}

@test "secrets.sh runs gitleaks" {
  stub_repeated gitleaks "true"
  
  run --separate-stderr "$LINTERS_DIR/secrets.sh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "No secrets"
}

@test "secrets.sh fails when secrets detected" {
  stub_repeated gitleaks "exit 1"
  
  run --separate-stderr "$LINTERS_DIR/secrets.sh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
}
