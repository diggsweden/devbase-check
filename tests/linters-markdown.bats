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
  unstub rumdl 2>/dev/null || true
  temp_del "$TEST_DIR"
}

@test "markdown.sh check runs rumdl" {
  cat > test.md << 'EOF'
# Test
EOF
  stub rumdl "check . --disable MD013 : true"
  
  run --separate-stderr "$LINTERS_DIR/markdown.sh" check
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "passed"
}

@test "markdown.sh fix runs rumdl with --fix" {
  cat > test.md << 'EOF'
# Test
EOF
  stub rumdl "check --fix . --disable MD013 : true"
  
  run --separate-stderr "$LINTERS_DIR/markdown.sh" fix
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "fixed"
}
