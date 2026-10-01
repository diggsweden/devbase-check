#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  cd "$TEST_DIR"
  setup_isolated_home
  export VERIFY="${DEVTOOLS_ROOT}/scripts/verify.sh"
  local recipe
  for recipe in version-control commits secrets yaml markdown shell shell-fmt actions license container xml; do
    printf 'lint-%s:\n    @printf "DEVBASE_CHECK_STATUS=pass\\n"\n' "$recipe"
  done >justfile
}

teardown() {
  common_teardown
}

@test "verify.sh runs both extension option forms alongside base checks" {
  run "$VERIFY" --extension='Foo|foo-tool|printf "DEVBASE_CHECK_STATUS=pass\n"' \
    -e='Bar|bar-tool|printf "DEVBASE_CHECK_STATUS=pass\n"'

  assert_success
  assert_output --partial "Commits"
  assert_output --partial "Foo"
  assert_output --partial "foo-tool"
  assert_output --partial "Bar"
  assert_output --partial "13 passed"
}

@test "verify.sh continues after a failed extension and reports it in GitHub summary" {
  export GITHUB_STEP_SUMMARY="$TEST_DIR/summary.md"
  run "$VERIFY" -e='Broken|tool|exit 1' -e='Later|tool|printf "completed\n"'

  assert_failure
  assert_output --partial "completed"
  run cat "$GITHUB_STEP_SUMMARY"
  assert_output --partial '| Broken | tool | Fail |'
  assert_output --partial '| Later | tool | Pass |'
  assert_output --partial '**Pass:** 12 | **Fail:** 1'
}

@test "verify.sh rejects malformed extensions before running any checks" {
  local extension
  for extension in '' 'Name' 'Name|tool' '|tool|true' 'Name||true' 'Name|tool|' ' |tool|true' $'Name|tool|true\nfalse'; do
    run "$VERIFY" "--extension=$extension" '-e=Sentinel|tool|touch ran'
    assert_failure 2
    assert_output --partial "invalid extension"
    assert_file_not_exists "$TEST_DIR/ran"
  done
}

@test "verify.sh rejects duplicate base and custom check names" {
  run "$VERIFY" '-e=Secrets|tool|touch ran'
  assert_failure 2
  assert_output --partial "duplicate check name: Secrets"
  assert_file_not_exists "$TEST_DIR/ran"

  run "$VERIFY" '-e=Custom|tool|touch ran' '-e=Custom|tool|true'
  assert_failure 2
  assert_output --partial "duplicate check name: Custom"
  assert_file_not_exists "$TEST_DIR/ran"
}

@test "verify.sh rejects extension names that collide with auto-detected checks" {
  printf 'lint-rust-clippy:\n    @true\n' >>justfile
  run "$VERIFY" '-e=Rust Clippy|tool|touch ran'
  assert_failure 2
  assert_output --partial "duplicate check name: Rust Clippy"
  assert_file_not_exists "$TEST_DIR/ran"
}

@test "verify.sh preserves pipes inside an extension command" {
  run "$VERIFY" '-e=Pipeline|shell|printf "pipeline works\n" | tr a-z A-Z'
  assert_success
  assert_output --partial "PIPELINE WORKS"
  assert_output --partial "12 passed"
}

@test "verify.sh does not let a pass marker hide an extension failure" {
  run "$VERIFY" '-e=Broken|tool|printf "DEVBASE_CHECK_STATUS=pass\n"; exit 1'
  assert_failure
  assert_output --partial "1 failed"
}

@test "verify.sh includes successful silent extensions in the summary" {
  export GITHUB_STEP_SUMMARY="$TEST_DIR/summary.md"
  run "$VERIFY" '-e=Quiet|tool|true'
  assert_success
  run cat "$GITHUB_STEP_SUMMARY"
  assert_output --partial '| Quiet | tool | Pass |'
  assert_output --partial '**Pass:** 12'
}

@test "just verification recipes preserve multiple quoted extension arguments" {
  cp "$DEVTOOLS_ROOT/justfile" justfile
  mkdir scripts
  cat >scripts/verify.sh <<'EOF'
#!/usr/bin/env bash
printf '<%s>\n' "$@"
EOF
  chmod +x scripts/verify.sh

  local recipe
  for recipe in verify lint-base lint-all; do
    run just "$recipe" '--extension=One|tool|printf "hello world"' '-e=Two|tool|true'
    assert_success
    assert_output $'<--extension=One|tool|printf "hello world">\n<-e=Two|tool|true>'
  done
}
