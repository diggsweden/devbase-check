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
  export JAVA_LINTERS="${DEVTOOLS_ROOT}/linters/java"
  export DEVBASE_CHECK_MARKERS=1
  cd "$TEST_DIR"
}

teardown() {
  unstub mvn 2>/dev/null || true
  common_teardown
}

@test "lint.sh skips when no pom.xml present" {
  run "$JAVA_LINTERS/lint.sh"
  
  assert_success
  assert_output --partial "No pom.xml"
}

@test "lint.sh runs mvn when pom.xml exists" {
  cat > pom.xml << 'EOF'
<project>
  <modelVersion>4.0.0</modelVersion>
</project>
EOF
  stub_repeated mvn "true"
  
  run "$JAVA_LINTERS/lint.sh"
  
  assert_success
}

@test "checkstyle.sh skips when no pom.xml present" {
  run "$JAVA_LINTERS/checkstyle.sh"
  
  assert_success
  assert_output --partial "No pom.xml"
}

@test "checkstyle.sh runs mvn checkstyle when pom.xml exists" {
  cat > pom.xml << 'EOF'
<project>
  <modelVersion>4.0.0</modelVersion>
</project>
EOF
  stub_repeated mvn "true"
  
  run "$JAVA_LINTERS/checkstyle.sh"
  
  assert_success
}

@test "pmd.sh skips when no pom.xml present" {
  run "$JAVA_LINTERS/pmd.sh"
  
  assert_success
  assert_output --partial "No pom.xml"
}

@test "spotbugs.sh skips when no pom.xml present" {
  run "$JAVA_LINTERS/spotbugs.sh"
  
  assert_success
  assert_output --partial "No pom.xml"
  assert_output --partial "DEVBASE_CHECK_STATUS=skip"
}

@test "spotbugs.sh reports pass marker when mvn succeeds" {
  cat > pom.xml << 'EOF'
<project>
  <modelVersion>4.0.0</modelVersion>
</project>
EOF
  stub_repeated mvn "true"

  run "$JAVA_LINTERS/spotbugs.sh"

  assert_success
  assert_output --partial "SpotBugs passed"
  assert_output --partial "DEVBASE_CHECK_STATUS=pass"
}

@test "spotbugs.sh reports fail marker when mvn fails" {
  cat > pom.xml << 'EOF'
<project>
  <modelVersion>4.0.0</modelVersion>
</project>
EOF
  stub_repeated mvn "exit 1"

  run --separate-stderr "$JAVA_LINTERS/spotbugs.sh"

  assert_failure
  [[ "$stderr" == *"SpotBugs failed"* ]] || [[ "$output" == *"SpotBugs failed"* ]]
  assert_output --partial "DEVBASE_CHECK_STATUS=fail"
}

@test "format.sh skips when no pom.xml present" {
  run "$JAVA_LINTERS/format.sh" check
  
  assert_success
  assert_output --partial "No pom.xml"
}

@test "test.sh skips when no pom.xml present" {
  run "$JAVA_LINTERS/test.sh"
  
  assert_success
  assert_output --partial "No pom.xml"
}
