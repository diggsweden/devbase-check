#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  export SCRIPT_DIR="${DEVTOOLS_ROOT}/scripts"
}

teardown() {
  common_teardown
}

@test "setup.sh requires repository URL argument" {
  run "$SCRIPT_DIR/setup.sh"
  
  assert_failure
  assert_output --partial "Usage:"
}

@test "setup.sh requires target directory argument" {
  run "$SCRIPT_DIR/setup.sh" "https://example.com/repo"
  
  assert_failure
  assert_output --partial "Usage:"
}

# =============================================================================
# Update check caching tests
# =============================================================================

@test "setup.sh creates marker file after update check" {
  local fake_dir="${TEST_DIR}/devtools"
  mkdir -p "$fake_dir"
  cd "$fake_dir"
  init_isolated_git_repo
  
  # Stub git fetch to succeed
  stub_repeated git 'exit 0'
  
  run "$SCRIPT_DIR/setup.sh" "https://example.com/repo" "$fake_dir"
  
  assert_success
  assert_file_exists "$fake_dir/.last-update-check"
}

@test "setup.sh skips update check if marker file is recent" {
  setup_isolated_home
  local fake_dir="${TEST_DIR}/devtools"
  mkdir -p "$fake_dir"
  
  # Create recent marker file
  touch "$fake_dir/.last-update-check"
  
  # Stub git fetch to fail (should not be called)
  stub_repeated git 'echo "git should not be called"; exit 1'
  
  run "$SCRIPT_DIR/setup.sh" "https://example.com/repo" "$fake_dir"
  
  assert_success
  refute_output --partial "git should not be called"
}

@test "setup.sh checks for updates if marker file is older than 1 hour" {
  local fake_dir="${TEST_DIR}/devtools"
  mkdir -p "$fake_dir"
  cd "$fake_dir"
  init_isolated_git_repo
  
  # Create OLD marker file (61 minutes ago)
  touch "$fake_dir/.last-update-check"
  env TZ=XXX0 touch -d "$(TZ=XXX+1:01 date +%FT%T)" "$fake_dir/.last-update-check"
  
  run "$SCRIPT_DIR/setup.sh" "https://example.com/repo" "$fake_dir"
  
  # Should have run (git fetch succeeds, updates marker)
  assert_success
  # Marker file should be updated to now
  local marker_age
  marker_age=$(find "$fake_dir/.last-update-check" -mmin +1 2>/dev/null || true)
  assert_equal "$marker_age" ""
}

# =============================================================================
# Update with untracked files tests
# =============================================================================

@test "setup.sh update handles untracked files without failing" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"

  # Create local repo with two commits and tags
  mkdir -p "$fake_dir"
  cd "$fake_dir"
  export GIT_EDITOR=true  # Prevent editor from opening
  init_isolated_git_repo
  git tag -a v1.0.0 -m "v1.0.0"  # Use annotated tag with message
  
  # Make a new commit and tag v1.0.1
  echo "updated" > file.txt
  git add file.txt
  git commit -q -m "Update"
  git tag -a v1.0.1 -m "v1.0.1"
  
  # Create a bare remote and push everything
  git init -q --bare "$remote_dir"
  git remote add origin "$remote_dir"
  git push --all origin 2>/dev/null
  git push --tags origin 2>/dev/null
  
  # Go back to v1.0.0 (simulating outdated install)
  git checkout v1.0.0 --quiet
  
  # Create untracked files (simulating user's local experiments)
  # These would conflict with checkout if not handled properly
  echo "my local test" > untracked-test-file.txt
  mkdir -p new-utils
  echo "local utility" > new-utils/my-util.sh
  
  # Create old marker to trigger update check
  touch "$fake_dir/.last-update-check"
  env TZ=XXX0 touch -d "$(TZ=XXX+1:01 date +%FT%T)" "$fake_dir/.last-update-check"
  
  # Run setup in non-interactive mode (CI=true auto-updates)
  export CI=true
  run "$SCRIPT_DIR/setup.sh" "$remote_dir" "$fake_dir"
  
  assert_success
  assert_output --partial "Updated to v1.0.1"
  
  # Verify we're now on v1.0.1
  cd "$fake_dir"
  run git describe --tags --abbrev=0
  assert_output "v1.0.1"
}
