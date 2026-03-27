#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2154,SC2164,SC2268
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
#
# Shared test helper functions for BATS tests
#
# This file follows the same patterns as devbase-core and reusable-ci test helpers
# to ensure consistent test isolation across all devbase projects.
#
# Shellcheck disabled:
#   SC2016 - Expressions don't expand in single quotes (intentional in mock scripts)
#   SC2154 - Variables like $output/$stderr are set by bats, not this script
#   SC2164 - cd without || exit is fine in test helpers (bats handles failures)
#   SC2268 - x-prefix in comparisons is a common bats pattern for empty checks

# =============================================================================
# Common Setup/Teardown Helpers
# =============================================================================

# Standard test setup - creates temp dir and sets DEVTOOLS_ROOT
# Usage: common_setup
common_setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  export DEVTOOLS_ROOT="${BATS_TEST_DIRNAME}/.."
}

# Standard test teardown - cleans up temp dir safely
# Usage: common_teardown
common_teardown() {
  safe_temp_del "$TEST_DIR"
}

# Setup with isolated HOME environment
# Usage: common_setup_isolated
common_setup_isolated() {
  common_setup
  setup_isolated_home
}

# =============================================================================
# Safe Temp Directory Cleanup
# =============================================================================

# Safely delete a temp directory, handling git's write-protected objects
# This wraps temp_del but makes files writable first to avoid interactive prompts
# SAFETY: Only deletes directories under /tmp or $BATS_TMPDIR
# Usage: safe_temp_del <path>
safe_temp_del() {
  local path="$1"
  [[ -z "$path" ]] && return 0
  [[ ! -d "$path" ]] && return 0

  # Resolve to absolute path
  local abs_path
  abs_path="$(cd "$path" 2>/dev/null && pwd)" || return 0

  # SAFETY: Only allow deletion in /tmp or BATS_TMPDIR
  local allowed_base="${BATS_TMPDIR:-/tmp}"
  if [[ "$abs_path" != /tmp/* && "$abs_path" != "$allowed_base"/* ]]; then
    echo "ERROR: safe_temp_del refuses to delete '$abs_path' - not in /tmp or BATS_TMPDIR" >&2
    return 1
  fi

  # Extra safety: refuse to delete if path is too short (e.g., /tmp itself)
  if [[ "${#abs_path}" -lt 10 ]]; then
    echo "ERROR: safe_temp_del refuses to delete '$abs_path' - path too short" >&2
    return 1
  fi

  # Make all files writable to avoid rm prompting on git objects
  chmod -R u+w "$abs_path" 2>/dev/null || true
  temp_del "$abs_path"
}

# =============================================================================
# Isolated Environment Setup
# =============================================================================

# Setup isolated HOME and XDG directories in TEST_DIR
# Usage: setup_isolated_home
# Sets: HOME, XDG_DATA_HOME, XDG_CONFIG_HOME
setup_isolated_home() {
  export HOME="${TEST_DIR}/home"
  export XDG_DATA_HOME="${HOME}/.local/share"
  export XDG_CONFIG_HOME="${HOME}/.config"
  mkdir -p "$HOME"
  mkdir -p "$XDG_DATA_HOME"
  mkdir -p "$XDG_CONFIG_HOME"
}

# =============================================================================
# Git Repository Setup Helpers
# =============================================================================

# Initialize a minimal git repository for testing
# Usage: init_git_repo
init_git_repo() {
  export GIT_CONFIG_NOSYSTEM=1
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test User"
  # Make git objects writable so safe_temp_del can clean up
  git config core.sharedRepository 0644
  echo "initial" >file.txt
  git add file.txt
  git commit -q -m "Initial commit"
}

# Initialize git repo with isolated HOME and config
# Usage: init_isolated_git_repo
init_isolated_git_repo() {
  setup_isolated_home
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="${HOME}/.gitconfig"
  init_git_repo
}

# Setup for tests that need isolated git repository
# Usage: common_setup_with_isolated_git
common_setup_with_isolated_git() {
  common_setup
  init_isolated_git_repo
}

# =============================================================================
# Debug Helpers
# =============================================================================

# Standard debug output for failed tests
# Usage: debug_output (call after 'run' command)
debug_output() {
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
}

# =============================================================================
# Mock Helpers
# =============================================================================

# Create repeated stub that always returns the same result
# Usage: stub_repeated <command> <behavior>
stub_repeated() {
  local cmd="$1"
  local behavior="$2"

  mkdir -p "${TEST_DIR}/bin"
  cat >"${TEST_DIR}/bin/${cmd}" <<SCRIPT
#!/usr/bin/env bash
${behavior}
SCRIPT
  chmod +x "${TEST_DIR}/bin/${cmd}"
  export PATH="${TEST_DIR}/bin:${PATH}"
}
