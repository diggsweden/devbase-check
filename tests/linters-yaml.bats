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
  unstub yamlfmt 2>/dev/null || true
  temp_del "$TEST_DIR"
}

@test "yaml.sh check succeeds when yamlfmt passes" {
  cat > test.yaml << 'EOF'
key: value
EOF
  stub yamlfmt "-lint . : true"
  
  run --separate-stderr "$LINTERS_DIR/yaml.sh" check
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "passed"
}

@test "yaml.sh check fails when yamlfmt finds issues" {
  cat > test.yaml << 'EOF'
key: value
EOF
  stub yamlfmt "-lint . : exit 1"
  
  run --separate-stderr "$LINTERS_DIR/yaml.sh" check
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"failed"* ]] || [[ "$output" == *"failed"* ]]
}

@test "yaml.sh fix formats files" {
  cat > test.yaml << 'EOF'
key: value
EOF
  stub yamlfmt ". : true"
  
  run --separate-stderr "$LINTERS_DIR/yaml.sh" fix
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "formatted"
}

@test "yaml.sh rejects unknown action" {
  stub yamlfmt ""
  
  run --separate-stderr "$LINTERS_DIR/yaml.sh" invalid
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"Unknown action"* ]] || [[ "$output" == *"Unknown action"* ]]
}
