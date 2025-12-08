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
  unstub actionlint 2>/dev/null || true
  temp_del "$TEST_DIR"
}

@test "github-actions.sh runs actionlint when workflows exist" {
  mkdir -p .github/workflows
  cat > .github/workflows/test.yml << 'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo test
EOF
  stub_repeated actionlint "true"
  
  run --separate-stderr "$LINTERS_DIR/github-actions.sh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "passed"
}

@test "github-actions.sh skips when no workflows exist" {
  run --separate-stderr "$LINTERS_DIR/github-actions.sh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "No GitHub"
}
