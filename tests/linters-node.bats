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
  export NODE_LINTERS="${BATS_TEST_DIRNAME}/../linters/node"
  cd "$TEST_DIR"
}

teardown() {
  unstub npx 2>/dev/null || true
  temp_del "$TEST_DIR"
}

@test "eslint.sh skips when no package.json present" {
  run "$NODE_LINTERS/eslint.sh"
  
  assert_success
  assert_output --partial "package.json"
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
