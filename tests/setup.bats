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

@test "setup.sh checks out latest tag on first run after bare clone" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"

  # Bare remote where the branch tip is an UNtagged commit — simulating
  # the common case where main has moved past the latest release tag.
  git init -q --bare "$remote_dir"
  local work="${TEST_DIR}/work"
  mkdir -p "$work"
  cd "$work"
  export GIT_EDITOR=true
  init_isolated_git_repo
  git tag -a v1.0.0 -m "v1.0.0"
  echo "updated" >file.txt
  git add file.txt
  git commit -q -m "Update"
  git tag -a v1.0.1 -m "v1.0.1"
  echo "post-release work" >file2.txt
  git add file2.txt
  git commit -q -m "Work after release"
  git remote add origin "$remote_dir"
  git push --all origin 2>/dev/null
  git push --tags origin 2>/dev/null

  # Simulate what the consumer shim does: plain clone, HEAD ends up on
  # the untagged branch tip.
  git clone --quiet "$remote_dir" "$fake_dir"
  cd "$fake_dir"

  # Precondition: fresh clone is on the branch tip (not a tag) and has no marker.
  run git describe --exact-match --tags HEAD
  assert_failure
  assert_not_exist "$fake_dir/.last-update-check"

  run "$SCRIPT_DIR/setup.sh" "$remote_dir" "$fake_dir"
  assert_success
  assert_file_exists "$fake_dir/.last-update-check"

  # HEAD should now be on v1.0.1.
  cd "$fake_dir"
  run git describe --tags --abbrev=0
  assert_output "v1.0.1"
}

@test "setup.sh is silent and leaves marker untouched when fetch fails" {
  local fake_dir="${TEST_DIR}/devtools"
  mkdir -p "$fake_dir"
  cd "$fake_dir"
  init_isolated_git_repo

  # Stub git to succeed on the calls setup.sh needs before fetch
  # (rev-parse etc.) but fail on fetch — simulating offline.
  stub_repeated git '[[ "$1" == "fetch"* ]] || [[ "$*" == *"fetch"* ]] && exit 1
                     exit 0'

  run "$SCRIPT_DIR/setup.sh" "https://example.com/repo" "$fake_dir"

  assert_success
  refute_output --partial "Could not check for updates"
  refute_output --partial "no network"
  assert_not_exist "$fake_dir/.last-update-check"
}

@test "DEVBASE_CHECK_SKIP_UPDATES=1 disables the update check entirely" {
  local fake_dir="${TEST_DIR}/devtools"
  mkdir -p "$fake_dir"

  # Stub git to fail so we'd see an error if setup.sh tried to fetch.
  stub_repeated git 'echo "git should not be called"; exit 1'

  DEVBASE_CHECK_SKIP_UPDATES=1 run "$SCRIPT_DIR/setup.sh" "https://example.com/repo" "$fake_dir"

  assert_success
  refute_output --partial "git should not be called"
  assert_not_exist "$fake_dir/.last-update-check"
}

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
  
  # Non-interactive no longer auto-updates by default (CI/Renovate owns
  # version bumps). Use the explicit opt-in.
  export DEVBASE_CHECK_AUTO_UPDATE=1
  run "$SCRIPT_DIR/setup.sh" "$remote_dir" "$fake_dir"

  assert_success
  assert_output --partial "Updated to v1.0.1"

  # Verify we're now on v1.0.1
  cd "$fake_dir"
  run git describe --tags --abbrev=0
  assert_output "v1.0.1"
}

@test "setup.sh does NOT auto-update on non-tty (CI/pipe) without opt-in" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"

  mkdir -p "$fake_dir"
  cd "$fake_dir"
  export GIT_EDITOR=true
  init_isolated_git_repo
  git tag -a v1.0.0 -m "v1.0.0"
  echo "new" >file.txt
  git add file.txt
  git commit -q -m "Update"
  git tag -a v1.0.1 -m "v1.0.1"

  git init -q --bare "$remote_dir"
  git remote add origin "$remote_dir"
  git push --all origin 2>/dev/null
  git push --tags origin 2>/dev/null

  git checkout v1.0.0 --quiet
  touch "$fake_dir/.last-update-check"
  env TZ=XXX0 touch -d "$(TZ=XXX+1:01 date +%FT%T)" "$fake_dir/.last-update-check"

  # CI env set, but no DEVBASE_CHECK_AUTO_UPDATE — must NOT update.
  # Redirect stdin from /dev/null so [[ -t 0 ]] is false even when bats
  # is invoked from an interactive terminal; otherwise setup.sh falls
  # through to the `read -p` prompt and the test hangs.
  export CI=true
  run "$SCRIPT_DIR/setup.sh" "$remote_dir" "$fake_dir" </dev/null

  assert_success
  refute_output --partial "Updated to v1.0.1"

  cd "$fake_dir"
  run git describe --tags --abbrev=0
  assert_output "v1.0.0"
}

