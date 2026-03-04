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
}

teardown() {
  common_teardown
}

@test "yaml.sh check succeeds when yamlfmt passes" {
  cat > test.yaml << 'EOF'
key: value
EOF
  # yamlfmt may be called with -conf flag, use stub_repeated for flexibility
  stub_repeated yamlfmt "true"
  
  run --separate-stderr "$LINTERS_DIR/yaml.sh" check
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "passed"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "yaml.sh check fails when yamlfmt finds issues" {
  cat > test.yaml << 'EOF'
key: value
EOF
  stub_repeated yamlfmt "exit 1"
  
  run --separate-stderr "$LINTERS_DIR/yaml.sh" check
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
  [[ "$stderr" == *"failed"* ]] || [[ "$output" == *"failed"* ]]
}

@test "yaml.sh fix formats files" {
  cat > test.yaml << 'EOF'
key: value
EOF
  stub_repeated yamlfmt "true"
  
  run --separate-stderr "$LINTERS_DIR/yaml.sh" fix
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "formatted"
}

@test "yaml.sh rejects unknown action" {
  cat > test.yaml << 'EOF'
key: value
EOF
  stub_repeated yamlfmt "true"
  
  run --separate-stderr "$LINTERS_DIR/yaml.sh" invalid
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
  [[ "$stderr" == *"Unknown action"* ]] || [[ "$output" == *"Unknown action"* ]]
}

@test "yaml.sh uses project config for all supported local config variants" {
  cat > test.yaml << 'EOF'
key: value
EOF

  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/yamlfmt" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "$*" > "${TEST_DIR}/yamlfmt.args"
exit 0
EOF
  chmod +x "${TEST_DIR}/bin/yamlfmt"
  export PATH="${TEST_DIR}/bin:${PATH}"

  local configs=(
    ".yamlfmt"
    ".yamlfmt.yml"
    ".yamlfmt.yaml"
    "yamlfmt.yml"
    "yamlfmt.yaml"
  )

  for cfg in "${configs[@]}"; do
    rm -f .yamlfmt .yamlfmt.yml .yamlfmt.yaml yamlfmt.yml yamlfmt.yaml
    : > "${TEST_DIR}/yamlfmt.args"
    touch "$cfg"

    run --separate-stderr "$LINTERS_DIR/yaml.sh" check

    [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "cfg:${cfg} o:'${output}' e:'${stderr}'"
    assert_success
    args=$(<"${TEST_DIR}/yamlfmt.args")
    [[ "$args" != *"-conf"* ]]
  done
}

@test "yaml.sh uses default config when no local config exists" {
  cat > test.yaml << 'EOF'
key: value
EOF

  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/yamlfmt" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "$*" > "${TEST_DIR}/yamlfmt.args"
exit 0
EOF
  chmod +x "${TEST_DIR}/bin/yamlfmt"
  export PATH="${TEST_DIR}/bin:${PATH}"

  rm -f .yamlfmt .yamlfmt.yml .yamlfmt.yaml yamlfmt.yml yamlfmt.yaml

  run --separate-stderr "$LINTERS_DIR/yaml.sh" check

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  args=$(<"${TEST_DIR}/yamlfmt.args")
  [[ "$args" == *"-conf"* ]]
  [[ "$args" == *"/linters/config/.yamlfmt"* ]]
}
