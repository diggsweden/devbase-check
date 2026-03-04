#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Git utility functions for devbase-check linters
#
# This module provides reliable git branch detection that works across:
# - Cloned repositories (with origin/HEAD set)
# - Locally created repositories pushed to remote (no origin/HEAD)
# - Pure local repositories (no remote at all)

# Get the default branch name for comparison operations
#
# Detection order:
# 1. Remote origin HEAD symbolic ref (set by git clone)
# 2. Remote tracking branches origin/main or origin/master
# 3. Local branches main or master
# 4. Fallback to "main"
#
# Usage: get_default_branch
# Returns: Branch name on stdout, always succeeds
get_default_branch() {
  local branch

  # 1. Try remote origin HEAD symbolic ref (works for cloned repos)
  branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s@^refs/remotes/origin/@@")
  if [[ -n "$branch" ]]; then
    echo "$branch"
    return 0
  fi

  # 2. No symbolic HEAD - check if origin/main or origin/master tracking branch exists
  #    This handles repos created locally and pushed (git push -u origin main)
  for candidate in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$candidate" 2>/dev/null; then
      echo "$candidate"
      return 0
    fi
  done

  # 3. No remote branches - check local main/master branches
  #    This handles pure local repos with no remote
  for candidate in main master; do
    if git show-ref --verify --quiet "refs/heads/$candidate" 2>/dev/null; then
      echo "$candidate"
      return 0
    fi
  done

  # 4. Fallback - assume main (modern git default)
  echo "main"
}

# Check if a branch exists (local or remote tracking)
#
# Usage: branch_exists <branch_name>
# Returns: 0 if exists, 1 if not
branch_exists() {
  local branch="$1"

  if [[ "$branch" == refs/* ]]; then
    git show-ref --verify --quiet "$branch" 2>/dev/null
    return $?
  fi

  if [[ "$branch" == origin/* ]]; then
    git show-ref --verify --quiet "refs/remotes/$branch" 2>/dev/null
    return $?
  fi

  git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null ||
    git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null
}

# Check if we have any commits to compare against a base branch
#
# Usage: has_commits_since <base_branch>
# Returns: 0 if there are commits, 1 if none or error
has_commits_since() {
  local base_branch="$1"
  local count

  # Verify the base branch exists before comparing
  if ! branch_exists "$base_branch"; then
    return 1
  fi

  count=$(git rev-list --count "${base_branch}..HEAD" 2>/dev/null || echo 0)
  [[ "$count" -gt 0 ]]
}
