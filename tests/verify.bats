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
  init_isolated_git_repo
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

@test "verify.sh honors explicit pass marker even when output contains Skipping" {
  cat > justfile << 'EOF'
lint-version-control:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-commits:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-secrets:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-yaml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-markdown:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell-fmt:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-actions:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-license:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-container:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-xml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-java-spotbugs:
    @printf "[INFO] Skipping com.github.spotbugs:spotbugs-maven-plugin report goal\n"
    @printf "DEVBASE_CHECK_STATUS=pass\n"
EOF

  run "$SCRIPT_DIR/verify.sh"

  assert_success
  assert_output --partial "Java SpotBugs"
  refute_output --partial "1 skipped"
}

@test "verify.sh runs all linters even when early ones fail" {
  cat > justfile << 'EOF'
lint-version-control:
    @printf "DEVBASE_CHECK_STATUS=fail\n"
    @printf "DEVBASE_CHECK_DETAILS=dirty tree\n"
lint-commits:
    @printf "DEVBASE_CHECK_STATUS=fail\n"
    @printf "DEVBASE_CHECK_DETAILS=bad format\n"
lint-secrets:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-yaml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-markdown:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell-fmt:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-actions:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-license:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-container:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-xml:
    @printf "DEVBASE_CHECK_STATUS=fail\n"
    @printf "DEVBASE_CHECK_DETAILS=invalid xml\n"
EOF

  run "$SCRIPT_DIR/verify.sh"

  assert_failure
  # All three failures must appear — proves linters after early failures still ran
  assert_output --partial "Working Tree"
  assert_output --partial "Commits"
  assert_output --partial "XML"
  assert_output --partial "3 failed"
}

@test "verify.sh reports correct pass count alongside failures" {
  cat > justfile << 'EOF'
lint-version-control:
    @printf "DEVBASE_CHECK_STATUS=fail\n"
lint-commits:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-secrets:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-yaml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-markdown:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell-fmt:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-actions:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-license:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-container:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-xml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
EOF

  run "$SCRIPT_DIR/verify.sh"

  assert_failure
  assert_output --partial "1 failed"
  assert_output --partial "10 passed"
}

@test "verify.sh fails when explicit fail marker is reported" {
  cat > justfile << 'EOF'
lint-version-control:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-commits:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-secrets:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-yaml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-markdown:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell-fmt:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-actions:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-license:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-container:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-xml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-node-eslint:
    @printf "DEVBASE_CHECK_STATUS=fail\n"
    @printf "DEVBASE_CHECK_DETAILS=failed\n"
EOF

  run "$SCRIPT_DIR/verify.sh"

  assert_failure
  assert_output --partial "Node ESLint"
  assert_output --partial "1 failed"
}

# =============================================================================
# Preflight: incomplete mise install
# =============================================================================

# Stub `mise` on PATH so the preflight thinks a pinned tool is missing.
# `mise ls --missing --json` returns a non-empty object; `mise ls --missing`
# lists the pin names. Everything else is a no-op.
_stub_mise_missing_pipx_reuse() {
  mkdir -p "${TEST_DIR}/bin"
  cat >"${TEST_DIR}/bin/mise" <<'EOF'
#!/usr/bin/env bash
case "$1 $2 $3" in
  "ls --missing --json") printf '%s' '{"pipx:reuse":[{"version":"6.2.0"}]}'; exit 0 ;;
  "ls --missing ")       printf 'pipx:reuse\n'; exit 0 ;;
esac
case "$1 $2" in
  "ls --missing")        printf 'pipx:reuse\n'; exit 0 ;;
esac
exit 0
EOF
  chmod +x "${TEST_DIR}/bin/mise"
  export PATH="${TEST_DIR}/bin:${PATH}"
}

@test "verify.sh fails fast with one message when a mise pin is missing" {
  cat > justfile << 'EOF'
default:
    @echo "test"
EOF
  _stub_mise_missing_pipx_reuse

  run "$SCRIPT_DIR/verify.sh"

  assert_failure
  assert_output --partial "mise install is incomplete"
  assert_output --partial "pipx:reuse"
  assert_output --partial "--ignore-missing-linters"
  # Cascade guard: the per-linter guard should NOT have run, so we don't see
  # the error more than once (once from the preflight itself).
  run bash -c "grep -c 'mise install is incomplete' <<<\"$output\""
  assert_output "1"
}

@test "verify.sh --ignore-missing-linters: affected linter shows skipped in summary" {
  # Recipe calls the real guard so we exercise the end-to-end flow:
  # preflight → IGNORE_MISSING_LINTERS=1 in env → guard emits skip marker →
  # verify.sh parses marker → summary prints it as skipped with details.
  local colors_path="${BATS_TEST_DIRNAME}/../utils/colors.sh"
  local mise_tool_path="${BATS_TEST_DIRNAME}/../utils/mise-tool.sh"

  cat > justfile <<EOF
default:
    @echo "test"
lint-version-control:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-commits:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-secrets:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-yaml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-markdown:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell-fmt:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-actions:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-license:
    #!/usr/bin/env bash
    source '${colors_path}'
    source '${mise_tool_path}'
    fail_if_mise_install_incomplete reuse
lint-container:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-xml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
EOF
  _stub_mise_missing_pipx_reuse

  run "$SCRIPT_DIR/verify.sh" --ignore-missing-linters

  assert_success
  assert_output --partial "License"
  assert_output --partial "mise pin missing"
  assert_output --partial "skipped"
}

@test "verify.sh --ignore-missing-linters warns once and proceeds" {
  cat > justfile << 'EOF'
default:
    @echo "test"
lint-version-control:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-commits:
    @printf "DEVBASE_CHECK_STATUS=skip\n"
    @printf "DEVBASE_CHECK_DETAILS=not in PATH\n"
lint-secrets:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-yaml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-markdown:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-shell-fmt:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-actions:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-license:
    @printf "DEVBASE_CHECK_STATUS=skip\n"
    @printf "DEVBASE_CHECK_DETAILS=not in PATH\n"
lint-container:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
lint-xml:
    @printf "DEVBASE_CHECK_STATUS=pass\n"
EOF
  _stub_mise_missing_pipx_reuse

  run "$SCRIPT_DIR/verify.sh" --ignore-missing-linters

  assert_success
  assert_output --partial "affected linters will be skipped"
  assert_output --partial "pipx:reuse"
  # Preflight message appears once, not once per linter.
  run bash -c "grep -c 'affected linters will be skipped' <<<\"$output\""
  assert_output "1"
}
