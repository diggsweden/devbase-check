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
}

teardown() {
  unstub rumdl 2>/dev/null || true
  common_teardown
}

@test "markdown.sh check runs rumdl" {
  cat > test.md << 'EOF'
# Test
EOF
  stub_repeated rumdl "true"
  
  run --separate-stderr "$LINTERS_DIR/markdown.sh" check
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "passed"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "markdown.sh fix runs rumdl with --fix" {
  cat > test.md << 'EOF'
# Test
EOF
  stub_repeated rumdl "true"
  
  run --separate-stderr "$LINTERS_DIR/markdown.sh" fix
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "fixed"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "markdown.sh check reports fail marker when rumdl fails" {
  cat > test.md << 'EOF'
# Test
EOF
  stub_repeated rumdl "exit 1"

  run --separate-stderr "$LINTERS_DIR/markdown.sh" check

  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}
