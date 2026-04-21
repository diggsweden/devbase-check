#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"
source "${SCRIPT_DIR}/../../utils/mise-tool.sh"

print_header "NODE LINTING (ALL)"

has_errors=false

# ESLint
if "${SCRIPT_DIR}/eslint.sh"; then
  print_success "ESLint passed"
else
  print_error "ESLint failed"
  has_errors=true
fi

# Prettier
if "${SCRIPT_DIR}/format.sh" check; then
  print_success "Prettier check passed"
else
  print_error "Prettier check failed"
  has_errors=true
fi

# Type checking
if "${SCRIPT_DIR}/types.sh"; then
  print_success "Type checking passed"
else
  print_error "Type checking failed"
  has_errors=true
fi

if [ "$has_errors" = true ]; then
  print_error "Node linting failed"
  emit_status "fail" "failed"
  exit 1
else
  print_success "All Node linting passed"
  emit_status "pass" "ok"
  exit 0
fi
