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
  export GIT_EDITOR=true
}

teardown() {
  common_teardown
}

# Build a bare remote with two tagged releases and one post-release commit,
# plus a feature branch 'feat/demo'. Clones into $fake_dir on branch main
# pointing at v1.0.1 (latest tag).
_fixture_remote() {
  local remote_dir="$1" fake_dir="$2"

  git init -q --bare "$remote_dir"
  local work="${TEST_DIR}/work"
  mkdir -p "$work"
  (
    cd "$work"
    init_isolated_git_repo
    git tag -a v1.0.0 -m "v1.0.0"
    echo "one" >file.txt
    git add file.txt
    git commit -q -m "one"
    git tag -a v1.0.1 -m "v1.0.1"

    # Branch point for the --ref test.
    git checkout -q -b feat/demo
    echo "feature" >feat.txt
    git add feat.txt
    git commit -q -m "feature commit"

    git checkout -q main 2>/dev/null || git checkout -q master 2>/dev/null
    git remote add origin "$remote_dir"
    git push --all origin 2>/dev/null
    git push --tags origin 2>/dev/null
  )
  git clone --quiet "$remote_dir" "$fake_dir"
  # Put the install on an outdated tag so "update" has something to do.
  git -C "$fake_dir" checkout -q v1.0.0
}

# =============================================================================
# Arg parsing
# =============================================================================

@test "update.sh requires an install-dir argument" {
  run "$SCRIPT_DIR/update.sh"
  assert_failure
  assert_output --partial "Usage:"
}

@test "update.sh rejects unknown flags" {
  run "$SCRIPT_DIR/update.sh" --bogus dir
  assert_failure
  assert_equal "$status" 2
  assert_output --partial "unknown option"
}

@test "update.sh --help exits 0 with usage" {
  run "$SCRIPT_DIR/update.sh" --help
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "--ref"
}

@test "update.sh errors cleanly when install dir is not a git checkout" {
  run "$SCRIPT_DIR/update.sh" "${TEST_DIR}/does-not-exist"
  assert_failure
  assert_output --partial "is not a git checkout"
  assert_output --partial "just setup-devtools"
}

# =============================================================================
# Default: update to latest tag
# =============================================================================

@test "update.sh: default (no --ref) checks out the latest tag on origin/main" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"
  _fixture_remote "$remote_dir" "$fake_dir"

  run "$SCRIPT_DIR/update.sh" "$fake_dir"
  assert_success
  assert_output --partial "updated to v1.0.1"

  run git -C "$fake_dir" describe --tags --exact-match HEAD
  assert_success
  assert_output "v1.0.1"
}

@test "update.sh refreshes the passive update-check marker" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"
  _fixture_remote "$remote_dir" "$fake_dir"

  run "$SCRIPT_DIR/update.sh" "$fake_dir"
  assert_success
  assert_file_exists "$fake_dir/.last-update-check"
}

@test "update.sh: default fails cleanly when origin/main has no tags" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"

  git init -q --bare "$remote_dir"
  local work="${TEST_DIR}/work"
  mkdir -p "$work"
  (
    cd "$work"
    init_isolated_git_repo
    git remote add origin "$remote_dir"
    git push --all origin 2>/dev/null
  )
  git clone --quiet "$remote_dir" "$fake_dir"

  run "$SCRIPT_DIR/update.sh" "$fake_dir"
  assert_failure
  assert_output --partial "no release tag found"
}

# =============================================================================
# --ref: specific branch / tag
# =============================================================================

@test "update.sh --ref <branch>: checks out the branch tip (detached)" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"
  _fixture_remote "$remote_dir" "$fake_dir"

  run "$SCRIPT_DIR/update.sh" "$fake_dir" --ref feat/demo
  assert_success
  assert_output --partial "updated to feat/demo"

  # HEAD should be on the feature branch's commit (has feat.txt).
  assert_file_exists "$fake_dir/feat.txt"
}

@test "update.sh --ref <tag>: checks out that specific tag" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"
  _fixture_remote "$remote_dir" "$fake_dir"

  # Move install ahead first so we can verify --ref v1.0.0 moves it back.
  git -C "$fake_dir" checkout -q v1.0.1

  run "$SCRIPT_DIR/update.sh" "$fake_dir" --ref v1.0.0
  assert_success
  assert_output --partial "updated to v1.0.0"

  run git -C "$fake_dir" describe --tags --exact-match HEAD
  assert_success
  assert_output "v1.0.0"
}

@test "update.sh --ref accepts --ref=<value> equals form" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"
  _fixture_remote "$remote_dir" "$fake_dir"

  run "$SCRIPT_DIR/update.sh" "$fake_dir" --ref=feat/demo
  assert_success
  assert_output --partial "updated to feat/demo"
}

@test "update.sh --ref without a value errors out" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"
  _fixture_remote "$remote_dir" "$fake_dir"

  run "$SCRIPT_DIR/update.sh" "$fake_dir" --ref
  assert_failure
  assert_equal "$status" 2
  assert_output --partial "--ref requires an argument"
}

# =============================================================================
# Local-state preservation
# =============================================================================

@test "update.sh stashes untracked files, completes the update, and tells the user where their work went" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"
  _fixture_remote "$remote_dir" "$fake_dir"

  # Untracked local experimentation that would otherwise conflict.
  echo "my local notes" >"$fake_dir/untracked.txt"

  run "$SCRIPT_DIR/update.sh" "$fake_dir"
  assert_success
  assert_output --partial "updated to v1.0.1"
  assert_output --partial "(from v1.0.0)"
  assert_output --partial "Local changes were stashed"
}

@test "devbase-check's own justfile exposes an 'update' escape-hatch recipe" {
  # Users stuck on an old consumer justfile fall back to:
  #   just -f $XDG_DATA_HOME/devbase-check/justfile update
  # This smoke test confirms the recipe exists and delegates to update.sh,
  # independent of the caller's cwd. (A full end-to-end invocation would
  # require a fixture clone; the recipe body check is a cheap guard that
  # catches the common breakage: a rename or relative-path regression.)
  local devbase_justfile="${DEVTOOLS_ROOT}/justfile"
  run just --justfile "$devbase_justfile" --show update
  assert_success
  assert_output --partial "scripts/update.sh"
  assert_output --partial "justfile_directory()"
}

@test "update.sh stays quiet about stashing when the tree is already clean" {
  local fake_dir="${TEST_DIR}/devtools"
  local remote_dir="${TEST_DIR}/remote.git"
  _fixture_remote "$remote_dir" "$fake_dir"

  run "$SCRIPT_DIR/update.sh" "$fake_dir"
  assert_success
  refute_output --partial "Local changes were stashed"
}
