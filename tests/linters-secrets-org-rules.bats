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
  export LINTERS_DIR="${DEVTOOLS_ROOT}/linters"
  export ORG_OVERLAY="${LINTERS_DIR}/config/org-rules.toml"
  export DEVBASE_CHECK_MARKERS=1

  # These tests exercise the real gitleaks binary against the org-rules
  # overlay. Skip cleanly where gitleaks is not installed.
  command -v gitleaks >/dev/null 2>&1 || skip "gitleaks not installed"

  cd "$TEST_DIR"
  init_isolated_git_repo
}

teardown() {
  common_teardown
}

# --- Overlay regex correctness (org-internal-hosts) -------------------------

@test "org-rules: detects an internal https host" {
  printf 'url = "https://wallet-keycloak-apps.internal.example/idp"\n' >host.txt

  run gitleaks detect --no-git --source=. --config "$ORG_OVERLAY" --no-banner --verbose

  assert_failure
  assert_output --partial "org-internal-hosts"
}

@test "org-rules: detects http and nested-subdomain internal hosts" {
  printf 'a = "http://foo.internal.example"\n' >a.txt
  printf 'b = "https://a.b.c.internal.example/auth?x=1"\n' >b.txt

  run gitleaks detect --no-git --source=. --config "$ORG_OVERLAY" --no-banner --verbose

  assert_failure
  assert_output --partial "org-internal-hosts"
}

@test "org-rules: ignores host without a scheme" {
  printf 'x = "internal.example/idp"\n' >x.txt

  run gitleaks detect --no-git --source=. --config "$ORG_OVERLAY" --no-banner

  assert_success
}

@test "org-rules: ignores a different, non-matching domain" {
  printf 'x = "https://foo.other.example.com/idp"\n' >x.txt

  run gitleaks detect --no-git --source=. --config "$ORG_OVERLAY" --no-banner

  assert_success
}

# --- secrets.sh flag wiring (DEVBASE_CHECK_ORG_RULES) ------------------------

@test "secrets.sh: org rules OFF by default - internal host is not flagged" {
  echo 'idp = "https://wallet.internal.example/idp"' >app.conf
  git add app.conf
  git commit -q -m "add config"

  run --separate-stderr "$LINTERS_DIR/secrets.sh"

  assert_success
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "secrets.sh: DEVBASE_CHECK_ORG_RULES=1 flags an internal host" {
  echo 'idp = "https://wallet.internal.example/idp"' >app.conf
  git add app.conf
  git commit -q -m "add config"

  DEVBASE_CHECK_ORG_RULES=1 run --separate-stderr "$LINTERS_DIR/secrets.sh"

  assert_failure
  assert_output --partial "Org rules enabled"
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

# Repo config that extends the defaults and allowlists a fixtures path.
write_repo_config_with_allowlist() {
  cat >.gitleaks.toml <<'EOF'
[extend]
useDefault = true
[[allowlists]]
paths = ['''^fixtures/''']
EOF
}

@test "secrets.sh: org rules respect the repo's local allowlist (allowlisted host ignored)" {
  write_repo_config_with_allowlist
  mkdir -p fixtures
  echo 'idp = "https://wallet.internal.example/idp"' >fixtures/sample.conf
  git add .gitleaks.toml fixtures/sample.conf
  git commit -q -m "add allowlisted fixture"

  DEVBASE_CHECK_ORG_RULES=1 run --separate-stderr "$LINTERS_DIR/secrets.sh"

  # The org rule matched, but the repo's allowlist (preserved through the
  # merge) suppresses it -> scan passes.
  assert_success
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "secrets.sh: org rules still catch hosts outside the allowlist" {
  write_repo_config_with_allowlist
  mkdir -p fixtures
  echo 'idp = "https://portal.internal.example/idp"' >app.conf
  git add .gitleaks.toml app.conf
  git commit -q -m "add non-allowlisted config"

  DEVBASE_CHECK_ORG_RULES=1 run --separate-stderr "$LINTERS_DIR/secrets.sh"

  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}
