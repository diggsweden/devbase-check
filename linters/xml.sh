#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

find_xml_files() {
  find . -type f -name "*.xml" -not -path "./.git/*" -not -path "./target/*" -not -path "./.idea/*" -not -path "./node_modules/*" 2>/dev/null
}

main() {
  print_header "XML LINTING (XMLLINT)"

  local files
  files=$(find_xml_files)

  if [[ -z "$files" ]]; then
    print_info "No XML files found to check"
    return 0
  fi

  if ! command -v xmllint >/dev/null 2>&1; then
    print_warning "xmllint not found in PATH - skipping XML linting"
    echo "  Install: Ubuntu/Debian: sudo apt install libxml2-utils"
    echo "           Fedora/RHEL:   sudo dnf install libxml2"
    echo "           macOS:         brew install libxml2"
    return 0
  fi

  local failed=0
  local count=0
  while IFS= read -r file; do
    ((count++))
    if ! xmllint --noout "$file" 2>&1; then
      print_error "Invalid XML: $file"
      failed=1
    fi
  done <<<"$files"

  if [[ $failed -eq 0 ]]; then
    print_success "XML linting passed ($count files)"
    return 0
  else
    print_error "XML linting failed"
    return 1
  fi
}

main
