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
  export LINTERS_DIR="${DEVTOOLS_ROOT}/linters"
  export DEVBASE_CHECK_MARKERS=1
  cd "$TEST_DIR"
  init_isolated_git_repo
}

teardown() {
  unstub gitleaks 2>/dev/null || true
  common_teardown
}

@test "secrets.sh runs gitleaks" {
  stub_repeated gitleaks "true"
  
  run --separate-stderr "$LINTERS_DIR/secrets.sh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "No secrets"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "secrets.sh fails when secrets detected" {
  stub_repeated gitleaks "exit 1"
  
  run --separate-stderr "$LINTERS_DIR/secrets.sh"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "secrets.sh scans committed, staged and unstaged changes" {
  stub_repeated gitleaks 'echo "gitleaks $*" >>"${TEST_DIR}/gitleaks.calls"'

  run --separate-stderr "$LINTERS_DIR/secrets.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  run cat "${TEST_DIR}/gitleaks.calls"
  assert_line --partial "gitleaks detect --source=."
  assert_line "gitleaks protect --source=. --staged --verbose --redact=50"
  assert_line "gitleaks protect --source=. --verbose --redact=50"
}

@test "secrets.sh fails when uncommitted changes contain secrets" {
  stub_repeated gitleaks '[[ "$1" == "protect" ]] && exit 1; exit 0'

  run --separate-stderr "$LINTERS_DIR/secrets.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "secrets.sh skips organisation rules when none are configured" {
  unset DEVBASE_ORG_RULES_DIR DEVBASE_ORG_RULES_REPO
  stub_repeated gitleaks 'echo "gitleaks $*" >>"${TEST_DIR}/gitleaks.calls"'

  run --separate-stderr "$LINTERS_DIR/secrets.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  run grep -c -- "--config=" "${TEST_DIR}/gitleaks.calls"
  assert_output "0"
}

@test "secrets.sh scans with organisation rules from DEVBASE_ORG_RULES_DIR" {
  mkdir -p "${TEST_DIR}/org-rules/gitleaks"
  touch "${TEST_DIR}/org-rules/gitleaks/rules.toml"
  export DEVBASE_ORG_RULES_DIR="${TEST_DIR}/org-rules"
  stub_repeated gitleaks 'echo "gitleaks $*" >>"${TEST_DIR}/gitleaks.calls"'

  run --separate-stderr "$LINTERS_DIR/secrets.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "Scanning with organisation rules"
  run grep -c -- "--config=${TEST_DIR}/org-rules/gitleaks/rules.toml" "${TEST_DIR}/gitleaks.calls"
  assert_output "3"
}

@test "secrets.sh fails when organisation rules detect secrets" {
  mkdir -p "${TEST_DIR}/org-rules/gitleaks"
  touch "${TEST_DIR}/org-rules/gitleaks/rules.toml"
  export DEVBASE_ORG_RULES_DIR="${TEST_DIR}/org-rules"
  stub_repeated gitleaks '[[ "$*" == *--config=* ]] && exit 1; exit 0'

  run --separate-stderr "$LINTERS_DIR/secrets.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "secrets.sh fails when configured organisation rules are missing" {
  export DEVBASE_ORG_RULES_DIR="${TEST_DIR}/missing"
  stub_repeated gitleaks "true"

  run --separate-stderr "$LINTERS_DIR/secrets.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"Organisation rules not found"* ]]
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "secrets.sh clones organisation rules from DEVBASE_ORG_RULES_REPO" {
  local repo="${TEST_DIR}/org-rules-repo"
  git init --quiet "$repo"
  mkdir -p "${repo}/gitleaks"
  touch "${repo}/gitleaks/rules.toml"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false \
    commit --quiet -m "rules"
  export DEVBASE_ORG_RULES_REPO="file://${repo}"
  export XDG_DATA_HOME="${TEST_DIR}/data"
  stub_repeated gitleaks 'echo "gitleaks $*" >>"${TEST_DIR}/gitleaks.calls"'

  run --separate-stderr "$LINTERS_DIR/secrets.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_file_exists "${TEST_DIR}/data/devbase-check-org-rules/gitleaks/rules.toml"
  run grep -c -- "--config=${TEST_DIR}/data/devbase-check-org-rules/gitleaks/rules.toml" "${TEST_DIR}/gitleaks.calls"
  assert_output "3"
}

@test "secrets.sh fails when DEVBASE_ORG_RULES_REPO cannot be cloned" {
  export DEVBASE_ORG_RULES_REPO="file://${TEST_DIR}/no-such-repo"
  export XDG_DATA_HOME="${TEST_DIR}/data"
  stub_repeated gitleaks "true"

  run --separate-stderr "$LINTERS_DIR/secrets.sh"

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"Could not clone organisation rules"* ]]
}
