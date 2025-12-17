#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Common utilities shared by all summary modules
#
# This file provides:
# - CI environment detection
# - Summary module loading

SUMMARY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect which CI environment we're running in
# Returns: github, gitlab, codeberg, or console
detect_ci_environment() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    echo "github"
  elif [[ -n "${CI_JOB_URL:-}" ]]; then
    echo "gitlab"
  elif [[ -n "${GITEA_ACTIONS:-}" ]]; then
    echo "codeberg"
  else
    echo "console"
  fi
}

# Load the appropriate summary module based on CI environment
# Falls back to console if no matching module exists
load_summary_module() {
  local ci_env="${1:-}"

  if [[ -z "$ci_env" ]]; then
    ci_env=$(detect_ci_environment)
  fi

  local module_path="${SUMMARY_DIR}/${ci_env}.sh"

  if [[ -f "$module_path" ]]; then
    # shellcheck source=/dev/null
    source "$module_path"
  else
    # Fallback to console
    # shellcheck source=console.sh
    source "${SUMMARY_DIR}/console.sh"
  fi
}
