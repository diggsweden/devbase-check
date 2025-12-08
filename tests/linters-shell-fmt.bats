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
}

teardown() {
  unstub shfmt 2>/dev/null || true
  temp_del "$TEST_DIR"
}

@test "shell-fmt.sh check runs shfmt" {
  cat > test.sh << 'EOF'
#!/bin/bash
echo "test"
EOF
  stub_repeated shfmt "true"
  
  run --separate-stderr "$LINTERS_DIR/shell-fmt.sh" check
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "passed"
}

@test "shell-fmt.sh fix formats shell scripts" {
  cat > test.sh << 'EOF'
#!/bin/bash
echo "test"
EOF
  stub_repeated shfmt "true"
  
  run --separate-stderr "$LINTERS_DIR/shell-fmt.sh" fix
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "formatted"
}

@test "shell-fmt.sh reports when no scripts exist" {
  run --separate-stderr "$LINTERS_DIR/shell-fmt.sh" check
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "No shell"
}
