#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"

setup() {
  source "${BATS_TEST_DIRNAME}/../utils/colors.sh"
}

@test "print_success outputs to stdout with checkmark" {
  run --separate-stderr print_success "test message"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "test message"
  assert_output --partial "✓"
  assert [ -z "$stderr" ]
}

@test "print_error outputs to stderr with cross" {
  run --separate-stderr print_error "error message"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  [[ "$stderr" == *"error message"* ]]
  [[ "$stderr" == *"✗"* ]]
}

@test "print_warning outputs to stderr with warning symbol" {
  run --separate-stderr print_warning "warning message"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  [[ "$stderr" == *"warning message"* ]]
  [[ "$stderr" == *"!"* ]]
}

@test "print_info outputs to stdout with info symbol" {
  run --separate-stderr print_info "info message"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "info message"
  assert_output --partial "ⓘ"
}

@test "print_header outputs formatted header" {
  run --separate-stderr print_header "TEST HEADER"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "TEST HEADER"
  assert_output --partial "***"
}

@test "just_header outputs title" {
  run --separate-stderr just_header "My Title"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "My Title"
}

@test "just_header outputs title and command when both provided" {
  run --separate-stderr just_header "My Title" "my-command --arg"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "My Title"
  assert_output --partial "my-command --arg"
}

@test "just_success outputs message with checkmark" {
  run --separate-stderr just_success "completed task"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "completed task"
  assert_output --partial "✓"
}

@test "just_error outputs message with cross" {
  run --separate-stderr just_error "failed task"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "failed task"
  assert_output --partial "✗"
}

@test "just_warn outputs message with warning symbol" {
  run --separate-stderr just_warn "warning task"
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "warning task"
  assert_output --partial "!"
}

@test "color variables are exported" {
  assert [ -n "$RED" ]
  assert [ -n "$GREEN" ]
  assert [ -n "$YELLOW" ]
  assert [ -n "$NC" ]
}

@test "symbol variables are exported" {
  assert [ "$CHECK" = "✓" ]
  assert [ "$CROSS" = "✗" ]
  assert [ "$WARN" = "!" ]
  assert [ "$INFO" = "ⓘ" ]
  assert [ "$ARROW" = "→" ]
}
