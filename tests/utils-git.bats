#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests for utils/git-utils.sh
#
# These tests verify get_default_branch works correctly across different
# repository configurations:
# - Cloned repos (with origin/HEAD)
# - Local repos pushed to remote (origin/main exists but no origin/HEAD)
# - Pure local repos (no remote)
# - Repos with master instead of main

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  export DEVTOOLS_ROOT="${BATS_TEST_DIRNAME}/.."
  source "${DEVTOOLS_ROOT}/utils/git-utils.sh"
  cd "$TEST_DIR"
}

teardown() {
  common_teardown
}

# =============================================================================
# Helper: Create git repo with specific configuration
# =============================================================================

# Create a bare remote repo to simulate origin
create_bare_remote() {
  local remote_path="${TEST_DIR}/remote.git"
  git init -q --bare "$remote_path"
  echo "$remote_path"
}

# =============================================================================
# get_default_branch tests
# =============================================================================

@test "get_default_branch: cloned repo with origin/HEAD returns correct branch" {
  # Simulate a cloned repo by setting up origin/HEAD symbolic ref
  init_isolated_git_repo
  local remote_path
  remote_path=$(create_bare_remote)
  git remote add origin "$remote_path"
  git push -u origin main 2>/dev/null
  # Manually set origin/HEAD like git clone does
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

  run get_default_branch

  assert_success
  assert_output "main"
}

@test "get_default_branch: local repo pushed to remote (no origin/HEAD) returns main" {
  # This is the failing case: git init + git remote add + git push
  # origin/main exists but origin/HEAD does not
  init_isolated_git_repo
  local remote_path
  remote_path=$(create_bare_remote)
  git remote add origin "$remote_path"
  git push -u origin main 2>/dev/null
  # Do NOT set origin/HEAD - this simulates the real scenario

  run get_default_branch

  assert_success
  assert_output "main"
}

@test "get_default_branch: local repo with master pushed to remote returns master" {
  # Same as above but with master branch
  init_isolated_git_repo master

  local remote_path
  remote_path=$(create_bare_remote)
  git remote add origin "$remote_path"
  git push -u origin master 2>/dev/null

  run get_default_branch

  assert_success
  assert_output "master"
}

@test "get_default_branch: pure local repo with main returns main" {
  # No remote at all
  init_isolated_git_repo

  run get_default_branch

  assert_success
  assert_output "main"
}

@test "get_default_branch: pure local repo with master returns master" {
  # No remote, default branch is master
  init_isolated_git_repo master

  run get_default_branch

  assert_success
  assert_output "master"
}

@test "get_default_branch: prefers origin/main over local master" {
  # Edge case: local master exists, but origin/main also exists
  init_isolated_git_repo master

  local remote_path
  remote_path=$(create_bare_remote)
  git remote add origin "$remote_path"
  # Rename to main for push, then create local master
  git branch -m master main
  git push -u origin main 2>/dev/null
  git checkout -b master 2>/dev/null

  run get_default_branch

  assert_success
  assert_output "main"
}

@test "get_default_branch: empty repo falls back to main" {
  # Repo with no commits yet
  setup_isolated_home
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="${HOME}/.gitconfig"
  git init -q -b main

  run get_default_branch

  assert_success
  assert_output "main"
}

# =============================================================================
# branch_exists tests
# =============================================================================

@test "branch_exists: returns true for existing local branch" {
  init_isolated_git_repo

  run branch_exists "main"

  assert_success
}

@test "branch_exists: returns false for non-existing branch" {
  init_isolated_git_repo

  run branch_exists "nonexistent"

  assert_failure
}

@test "branch_exists: returns true for remote tracking branch" {
  init_isolated_git_repo
  local remote_path
  remote_path=$(create_bare_remote)
  git remote add origin "$remote_path"
  git push -u origin main 2>/dev/null

  run branch_exists "main"

  assert_success
}

# =============================================================================
# has_commits_since tests
# =============================================================================

@test "has_commits_since: returns true when commits exist on feature branch" {
  init_isolated_git_repo
  git checkout -b feature 2>/dev/null
  echo "feature" > feature.txt
  git add feature.txt
  git commit -q -m "Feature commit"

  run has_commits_since "main"

  assert_success
}

@test "has_commits_since: returns false when no commits since branch" {
  init_isolated_git_repo
  git checkout -b feature 2>/dev/null
  # No new commits

  run has_commits_since "main"

  assert_failure
}

@test "has_commits_since: returns false when base branch does not exist" {
  init_isolated_git_repo

  run has_commits_since "nonexistent"

  assert_failure
}

@test "has_commits_since: works with remote tracking branch as base" {
  init_isolated_git_repo
  local remote_path
  remote_path=$(create_bare_remote)
  git remote add origin "$remote_path"
  git push -u origin main 2>/dev/null
  git checkout -b feature 2>/dev/null
  echo "feature" > feature.txt
  git add feature.txt
  git commit -q -m "Feature commit"

  run has_commits_since "main"

  assert_success
}
