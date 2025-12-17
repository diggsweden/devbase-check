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
  export DEVBASE_DIR="${DEVTOOLS_ROOT}"
  cd "$TEST_DIR"
  init_git_repo
}

teardown() {
  common_teardown
}

@test "verify.sh runs base linters" {
  cat > justfile << 'EOF'
# SPDX-FileCopyrightText: 2025 Test
# SPDX-License-Identifier: MIT
default:
    @echo "test"
EOF
  
  run "$SCRIPT_DIR/verify.sh"
  
  assert_output --partial "Commits"
  assert_output --partial "YAML"
  assert_output --partial "Markdown"
  assert_output --partial "Shell"
  assert_output --partial "License"
}

@test "verify.sh shows summary table" {
  cat > justfile << 'EOF'
# SPDX-FileCopyrightText: 2025 Test
# SPDX-License-Identifier: MIT
default:
    @echo "test"
EOF
  
  run "$SCRIPT_DIR/verify.sh"
  
  assert_output --partial "Check"
  assert_output --partial "Tool"
  assert_output --partial "Total:"
}

@test "verify.sh shows pass/fail counts in summary" {
  cat > justfile << 'EOF'
# SPDX-FileCopyrightText: 2025 Test
# SPDX-License-Identifier: MIT
default:
    @echo "test"
EOF
  
  run "$SCRIPT_DIR/verify.sh"
  
  assert_output --regexp "[0-9]+ passed"
}

# =============================================================================
# CI Environment Detection Tests
# =============================================================================

@test "detect_ci_environment returns github when GITHUB_STEP_SUMMARY set" {
  source "${DEVTOOLS_ROOT}/summary/common.sh"
  
  export GITHUB_STEP_SUMMARY="/tmp/test-summary.md"
  unset CI_JOB_URL
  unset GITEA_ACTIONS
  
  run detect_ci_environment
  assert_output "github"
}

@test "detect_ci_environment returns gitlab when CI_JOB_URL set" {
  source "${DEVTOOLS_ROOT}/summary/common.sh"
  
  unset GITHUB_STEP_SUMMARY
  export CI_JOB_URL="https://gitlab.com/job/123"
  unset GITEA_ACTIONS
  
  run detect_ci_environment
  assert_output "gitlab"
}

@test "detect_ci_environment returns codeberg when GITEA_ACTIONS set" {
  source "${DEVTOOLS_ROOT}/summary/common.sh"
  
  unset GITHUB_STEP_SUMMARY
  unset CI_JOB_URL
  export GITEA_ACTIONS="true"
  
  run detect_ci_environment
  assert_output "codeberg"
}

@test "detect_ci_environment returns console when no CI env vars set" {
  source "${DEVTOOLS_ROOT}/summary/common.sh"
  
  unset GITHUB_STEP_SUMMARY
  unset CI_JOB_URL
  unset GITEA_ACTIONS
  
  run detect_ci_environment
  assert_output "console"
}

@test "load_summary_module loads github module when detected" {
  source "${DEVTOOLS_ROOT}/summary/common.sh"
  
  export GITHUB_STEP_SUMMARY="${TEST_DIR}/summary.md"
  
  load_summary_module
  
  # Verify github module functions are available
  declare -f summary_init | grep -q "_GH_"
}

@test "load_summary_module loads console module as fallback" {
  source "${DEVTOOLS_ROOT}/summary/common.sh"
  
  unset GITHUB_STEP_SUMMARY
  unset CI_JOB_URL
  unset GITEA_ACTIONS
  
  load_summary_module
  
  # Verify console module functions are available
  declare -f summary_init | grep -q "_CONSOLE_"
}

@test "verify.sh generates GitHub summary when GITHUB_STEP_SUMMARY set" {
  export GITHUB_STEP_SUMMARY="${TEST_DIR}/github-summary.md"
  
  cat > justfile << 'EOF'
# SPDX-FileCopyrightText: 2025 Test
# SPDX-License-Identifier: MIT
default:
    @echo "test"
EOF
  
  run "$SCRIPT_DIR/verify.sh"
  
  # Should create summary file
  assert_file_exists "$GITHUB_STEP_SUMMARY"
  
  # Summary should contain markdown table
  run cat "$GITHUB_STEP_SUMMARY"
  assert_output --partial "Linting Results"
  assert_output --partial "| Linter | Tool | Status | Details |"
}
