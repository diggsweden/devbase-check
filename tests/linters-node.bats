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
  export NODE_LINTERS="${DEVTOOLS_ROOT}/linters/node"
  export DEVBASE_CHECK_MARKERS=1
  cd "$TEST_DIR"
}

teardown() {
  unstub npx 2>/dev/null || true
  common_teardown
}

@test "eslint.sh skips when no package.json present" {
  run "$NODE_LINTERS/eslint.sh"
  
  assert_success
  assert_output --partial "package.json"
  assert_output --partial "DEVBASE_CHECK_STATUS=skip"
}

@test "eslint.sh skips when eslint not in package.json" {
  cat > package.json << 'EOF'
{
  "name": "test",
  "version": "1.0.0"
}
EOF
  
  run "$NODE_LINTERS/eslint.sh"
  
  assert_success
  assert_output --partial "ESLint"
  assert_output --partial "DEVBASE_CHECK_STATUS=skip"
}

@test "eslint.sh runs npx eslint when configured" {
  cat > package.json << 'EOF'
{
  "name": "test",
  "devDependencies": {
    "eslint": "^8.0.0"
  }
}
EOF
  stub_repeated npx "true"
  
  run "$NODE_LINTERS/eslint.sh"
  
  assert_success
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "eslint.sh reports fail marker when eslint fails" {
  cat > package.json << 'EOF'
{
  "name": "test",
  "devDependencies": {
    "eslint": "^8.0.0"
  }
}
EOF
  stub_repeated npx "exit 1"

  run --separate-stderr "$NODE_LINTERS/eslint.sh"

  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "format.sh skips when no package.json present" {
  run "$NODE_LINTERS/format.sh" check
  
  assert_success
  assert_output --partial "package.json"
}

@test "format.sh skips when prettier not in package.json" {
  cat > package.json << 'EOF'
{
  "name": "test",
  "version": "1.0.0"
}
EOF
  
  run "$NODE_LINTERS/format.sh" check
  
  assert_success
}

@test "types.sh skips when no package.json present" {
  run "$NODE_LINTERS/types.sh"
  
  assert_success
  assert_output --partial "package.json"
}

@test "types.sh skips when typescript not in package.json" {
  cat > package.json << 'EOF'
{
  "name": "test",
  "version": "1.0.0"
}
EOF
  
  run "$NODE_LINTERS/types.sh"
  
  assert_success
}
