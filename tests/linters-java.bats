#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-mock/stub.bash"

setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  export JAVA_LINTERS="${BATS_TEST_DIRNAME}/../linters/java"
  cd "$TEST_DIR"
}

teardown() {
  unstub mvn 2>/dev/null || true
  temp_del "$TEST_DIR"
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
