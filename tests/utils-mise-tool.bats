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
  cd "$TEST_DIR"
  export PATH_SAVED="$PATH"
  mkdir -p "${TEST_DIR}/bin"
  export PATH="${TEST_DIR}/bin:/usr/bin:/bin"
  # Stop git/mise from walking out of the sandbox and picking up host state.
  export GIT_CEILING_DIRECTORIES="$TEST_DIR"
  unset MISE_TRUSTED_CONFIG_PATHS MISE_DATA_DIR \
    MISE_CONFIG_DIR MISE_CACHE_DIR 2>/dev/null || true
}

teardown() {
  export PATH="$PATH_SAVED"
  common_teardown
}

# Create a mise stub. First arg is the JSON object for `mise ls --missing --json`.
# Second arg (optional) is the newline-separated pin names for plain `mise ls --missing`.
stub_mise() {
  local json="${1-{\}}"
  local plain="${2-}"
  cat >"${TEST_DIR}/bin/mise" <<EOF
#!/usr/bin/env bash
case "\$1 \$2 \$3" in
  "ls --missing --json") printf '%s' '${json}'; exit 0 ;;
  "ls --missing ")       printf '%s' '${plain}'; exit 0 ;;
esac
exit 0
EOF
  chmod +x "${TEST_DIR}/bin/mise"
}

# --- mise_has_missing_pins ------------------------------------------------

@test "mise_has_missing_pins returns 0 when mise reports any missing" {
  stub_mise '{"pipx:reuse":[{"version":"1.0"}]}'

  run bash -c "
    source '${BATS_TEST_DIRNAME}/../utils/mise-tool.sh'
    mise_has_missing_pins
    echo rc=\$?
  "
  assert_output --partial "rc=0"
}

@test "mise_has_missing_pins returns non-zero when mise reports none" {
  stub_mise '{}'

  run bash -c "
    source '${BATS_TEST_DIRNAME}/../utils/mise-tool.sh'
    mise_has_missing_pins
    echo rc=\$?
  "
  refute_output --partial "rc=0"
}

@test "mise_has_missing_pins returns non-zero when mise is not installed" {
  # No mise stub, mise not on PATH.
  run bash -c "
    source '${BATS_TEST_DIRNAME}/../utils/mise-tool.sh'
    mise_has_missing_pins
    echo rc=\$?
  "
  refute_output --partial "rc=0"
}

# --- fail_if_mise_install_incomplete --------------------------------------

@test "fail_if_mise_install_incomplete: succeeds when mise has no missing pins" {
  stub_mise '{}'

  run bash -c "
    export DEVBASE_CHECK_MARKERS=1
    source '${BATS_TEST_DIRNAME}/../utils/colors.sh'
    source '${BATS_TEST_DIRNAME}/../utils/mise-tool.sh'
    fail_if_mise_install_incomplete
    echo rc=\$?
  "
  assert_output --partial "rc=0"
  refute_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "fail_if_mise_install_incomplete: fails loudly with a fail marker when pins are missing" {
  # This is the bug the whole mechanism exists to catch: mise install silently
  # incomplete (pipx:reuse matches the real .mise.toml pin key).
  stub_mise '{"pipx:reuse":[{"version":"1.0"}]}' 'pipx:reuse'

  run bash -c "
    export DEVBASE_CHECK_MARKERS=1
    source '${BATS_TEST_DIRNAME}/../utils/colors.sh'
    source '${BATS_TEST_DIRNAME}/../utils/mise-tool.sh'
    fail_if_mise_install_incomplete
    echo rc=\$?
  "
  assert_output --partial "mise install is incomplete"
  assert_output --partial "- pipx:reuse"
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
  assert_output --partial "rc=1"
}

@test "DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS=1 silences the incomplete-install check" {
  stub_mise '{"pipx:reuse":[{"version":"1.0"}]}'

  run bash -c "
    export DEVBASE_CHECK_MARKERS=1
    export DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS=1
    source '${BATS_TEST_DIRNAME}/../utils/colors.sh'
    source '${BATS_TEST_DIRNAME}/../utils/mise-tool.sh'
    fail_if_mise_install_incomplete
    echo rc=\$?
  "
  assert_output --partial "rc=0"
  refute_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "fail_if_mise_install_incomplete: succeeds when mise is not installed" {
  # No mise stub. Caller isn't using mise at all.
  run bash -c "
    source '${BATS_TEST_DIRNAME}/../utils/colors.sh'
    source '${BATS_TEST_DIRNAME}/../utils/mise-tool.sh'
    fail_if_mise_install_incomplete
    echo rc=\$?
  "
  assert_output --partial "rc=0"
}

# --- mise_tool_path -------------------------------------------------------

@test "mise_tool_path returns the mise-resolved path when mise knows the tool" {
  # Stub mise to claim it knows reuse.
  cat >"${TEST_DIR}/bin/mise" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "which reuse") echo "${TEST_DIR}/mise-managed/reuse"; exit 0 ;;
esac
exit 1
EOF
  chmod +x "${TEST_DIR}/bin/mise"

  run bash -c "
    source '${BATS_TEST_DIRNAME}/../utils/mise-tool.sh'
    mise_tool_path reuse
  "
  assert_output --partial "${TEST_DIR}/mise-managed/reuse"
}

@test "mise_tool_path is empty when mise doesn't know the tool" {
  stub_mise '{}'

  run bash -c "
    source '${BATS_TEST_DIRNAME}/../utils/mise-tool.sh'
    mise_tool_path unknown-tool
  "
  refute_output --regexp '.+'
}
