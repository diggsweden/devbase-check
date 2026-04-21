#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../utils/colors.sh"
source "${SCRIPT_DIR}/../../utils/mise-tool.sh"

maven_opts=(--batch-mode --no-transfer-progress --errors -Dstyle.color=always)

# Default exclude file from devbase-check (excludes generated-sources)
DEFAULT_EXCLUDE="${SCRIPT_DIR}/config/spotbugs-exclude.xml"

main() {
  print_header "JAVA SPOTBUGS"
  fail_if_mise_install_incomplete || return 1

  if [[ ! -f pom.xml ]]; then
    print_warning "No pom.xml found, skipping"
    emit_status "skip" "skipped"
    return 0
  fi

  if ! command -v mvn >/dev/null 2>&1; then
    print_error "mvn not found. Install with: mise install maven"
    emit_status "fail" "failed"
    return 1
  fi

  # Use project's exclude file if exists, otherwise use default
  local exclude_opt=()
  if [[ -f "development/spotbugs-exclude.xml" ]]; then
    exclude_opt=(-Dspotbugs.excludeFilterFile=development/spotbugs-exclude.xml)
  elif [[ -f ".spotbugs-exclude.xml" ]]; then
    exclude_opt=(-Dspotbugs.excludeFilterFile=.spotbugs-exclude.xml)
  elif [[ -f "${DEFAULT_EXCLUDE}" ]]; then
    exclude_opt=(-Dspotbugs.excludeFilterFile="${DEFAULT_EXCLUDE}")
  fi

  if mvn "${maven_opts[@]}" ${exclude_opt[@]+"${exclude_opt[@]}"} spotbugs:check; then
    print_success "SpotBugs passed"
    emit_status "pass" "ok"
    return 0
  else
    print_error "SpotBugs failed"
    emit_status "fail" "failed"
    return 1
  fi
}

main
