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
  export RUST_LINTERS="${DEVTOOLS_ROOT}/linters/rust"
  export DEVBASE_CHECK_MARKERS=1
  cd "$TEST_DIR"
}

teardown() {
  unstub cargo 2>/dev/null || true
  unstub cargo-audit 2>/dev/null || true
  common_teardown
}

@test "lint.sh skips when no Cargo.toml present" {
  run "$RUST_LINTERS/lint.sh"

  assert_success
  assert_output --partial "No Cargo.toml"
  assert_output --partial "DEVBASE_CHECK_STATUS=skip"
}

@test "lint.sh runs cargo when Cargo.toml exists" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  stub_repeated cargo "true"

  run "$RUST_LINTERS/lint.sh"

  assert_success
}

@test "clippy.sh skips when no Cargo.toml present" {
  run "$RUST_LINTERS/clippy.sh"

  assert_success
  assert_output --partial "No Cargo.toml"
  assert_output --partial "DEVBASE_CHECK_STATUS=skip"
}

@test "clippy.sh reports pass marker when cargo succeeds" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  stub_repeated cargo "true"

  run "$RUST_LINTERS/clippy.sh"

  assert_success
  assert_output --partial "Clippy passed"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "clippy.sh reports fail marker when cargo fails" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  stub_repeated cargo "exit 1"

  run --separate-stderr "$RUST_LINTERS/clippy.sh"

  assert_failure
  [[ "$stderr" == *"Clippy failed"* ]] || [[ "$output" == *"Clippy failed"* ]]
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "format.sh check skips when no Cargo.toml present" {
  run "$RUST_LINTERS/format.sh" check

  assert_success
  assert_output --partial "No Cargo.toml"
  assert_output --partial "DEVBASE_CHECK_STATUS=skip"
}

@test "format.sh check reports pass marker when cargo succeeds" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  stub_repeated cargo "true"

  run "$RUST_LINTERS/format.sh" check

  assert_success
  assert_output --partial "Rust formatting check passed"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "format.sh check reports fail marker when cargo fails" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  stub_repeated cargo "exit 1"

  run --separate-stderr "$RUST_LINTERS/format.sh" check

  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "format.sh fix runs cargo fmt when Cargo.toml exists" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  stub_repeated cargo "true"

  run "$RUST_LINTERS/format.sh" fix

  assert_success
  assert_output --partial "Rust code formatted"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "format.sh rejects unknown action" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  stub_repeated cargo "true"

  run --separate-stderr "$RUST_LINTERS/format.sh" bogus

  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "test.sh skips when no Cargo.toml present" {
  run "$RUST_LINTERS/test.sh"

  assert_success
  assert_output --partial "No Cargo.toml"
  assert_output --partial "DEVBASE_CHECK_STATUS=skip"
}

@test "test.sh reports pass marker when cargo test succeeds" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  stub_repeated cargo "true"

  run "$RUST_LINTERS/test.sh"

  assert_success
  assert_output --partial "Rust tests passed"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "audit.sh skips when no Cargo.toml present" {
  run "$RUST_LINTERS/audit.sh"

  assert_success
  assert_output --partial "No Cargo.toml"
  assert_output --partial "DEVBASE_CHECK_STATUS=skip"
}

@test "audit.sh skips when no Cargo.lock present" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF

  run "$RUST_LINTERS/audit.sh"

  assert_success
  assert_output --partial "No Cargo.lock"
  assert_output --partial "DEVBASE_CHECK_STATUS=skip"
}

@test "audit.sh reports pass marker when cargo audit succeeds" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  : > Cargo.lock
  # cargo-audit is on PATH (stubbed), so install is skipped; cargo audit
  # returns success.
  stub_repeated cargo "true"
  stub_repeated cargo-audit "true"

  run "$RUST_LINTERS/audit.sh"

  assert_success
  assert_output --partial "No known vulnerabilities"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "audit.sh reports fail marker when cargo audit fails" {
  cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
edition = "2021"
EOF
  : > Cargo.lock
  stub_repeated cargo "exit 1"
  stub_repeated cargo-audit "true"

  run --separate-stderr "$RUST_LINTERS/audit.sh"

  assert_failure
  [[ "$stderr" == *"cargo audit found advisories"* ]] || [[ "$output" == *"cargo audit found advisories"* ]]
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}
