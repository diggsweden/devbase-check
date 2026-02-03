# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# Quality checks and automation for devbase-check
# Run 'just' to see available commands

lint := "./linters"
colors := "./utils/colors.sh"

# Color variables
CYAN_BOLD := "\\033[1;36m"
GREEN := "\\033[1;32m"
BLUE := "\\033[1;34m"
MAGENTA := "\\033[1;35m"
NC := "\\033[0m"

# ==================================================================================== #
# DEFAULT - Show available recipes
# ==================================================================================== #

# Display available recipes
default:
    @printf "{{CYAN_BOLD}} DevBase Check{{NC}}\n"
    @printf "\n"
    @printf "Quick start: {{GREEN}}just verify{{NC}} | {{BLUE}}just lint-all{{NC}} | {{MAGENTA}}just lint-fix{{NC}}\n"
    @printf "\n"
    @just --list --unsorted

# ==================================================================================== #
# SETUP - Install development tools
# ==================================================================================== #

# ▪ Install development tools via mise
[group('setup')]
install:
    @mise install

# ==================================================================================== #
# VERIFY - Quality assurance
# ==================================================================================== #

# ▪ Run all linters with summary
[group('verify')]
verify:
    @./scripts/verify.sh

# ==================================================================================== #
# LINT - Code quality checks
# ==================================================================================== #

# ▪ Run all base linters (universal linters for any project)
[group('lint')]
lint-base:
    @./scripts/verify.sh

# ▪ Run all linters (default, uses lint-base)
[group('lint')]
lint-all: lint-base

# Validate version control
[group('lint')]
lint-version-control:
    @{{lint}}/version-control.sh

# Validate commit messages (conform)
[group('lint')]
lint-commits:
    @{{lint}}/commits.sh

# Scan for secrets (gitleaks)
[group('lint')]
lint-secrets:
    @{{lint}}/secrets.sh

# Lint YAML files (yamlfmt)
[group('lint')]
lint-yaml:
    @{{lint}}/yaml.sh check

# Lint markdown files (rumdl)
[group('lint')]
lint-markdown:
    @{{lint}}/markdown.sh check MD013

# Lint shell scripts (shellcheck)
[group('lint')]
lint-shell:
    @{{lint}}/shell.sh

# Check shell formatting (shfmt)
[group('lint')]
lint-shell-fmt:
    @{{lint}}/shell-fmt.sh check

# Lint GitHub Actions (actionlint)
[group('lint')]
lint-actions:
    @{{lint}}/github-actions.sh

# Check license compliance (reuse)
[group('lint')]
lint-license:
    @{{lint}}/license.sh

# Lint containers (hadolint)
[group('lint')]
lint-container:
    @{{lint}}/container.sh

# Lint XML files (xmllint)
[group('lint')]
lint-xml:
    @{{lint}}/xml.sh

# ==================================================================================== #
# LINT-FIX - Auto-fix linting violations
# ==================================================================================== #

# ▪ Fix all auto-fixable issues
[group('lint-fix')]
lint-fix: lint-yaml-fix lint-markdown-fix lint-shell-fmt-fix
    #!/usr/bin/env bash
    source "{{colors}}"
    just_success "All auto-fixes completed"

# Fix YAML formatting
[group('lint-fix')]
lint-yaml-fix:
    @{{lint}}/yaml.sh fix

# Fix markdown formatting
[group('lint-fix')]
lint-markdown-fix:
    @{{lint}}/markdown.sh fix MD013

# Fix shell formatting
[group('lint-fix')]
lint-shell-fmt-fix:
    @{{lint}}/shell-fmt.sh fix

# ==================================================================================== #
# TEST - Run tests
# ==================================================================================== #

# ▪ Run all tests
[group('test')]
test:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! command -v bats &>/dev/null; then
        printf "Error: bats not installed. Run 'just test-setup' first.\n" >&2
        exit 1
    fi
    [[ -d tests/libs ]] || ./tests/setup-bats-libs.sh
    bats tests/
    result=$?
    if [[ $result -le 1 ]]; then exit 0; else exit $result; fi

# Setup test dependencies (bats libraries)
[group('test')]
test-setup:
    @./tests/setup-bats-libs.sh

# Run tests with verbose output
[group('test')]
test-verbose:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! command -v bats &>/dev/null; then
        printf "Error: bats not installed. Run 'just test-setup' first.\n" >&2
        exit 1
    fi
    [[ -d tests/libs ]] || ./tests/setup-bats-libs.sh
    bats --verbose-run tests/
    result=$?
    if [[ $result -le 1 ]]; then exit 0; else exit $result; fi

# Run specific test file
[group('test')]
test-file file:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! command -v bats &>/dev/null; then
        printf "Error: bats not installed. Run 'just test-setup' first.\n" >&2
        exit 1
    fi
    [[ -d tests/libs ]] || ./tests/setup-bats-libs.sh
    bats "tests/{{file}}"
    result=$?
    if [[ $result -le 1 ]]; then exit 0; else exit $result; fi

# Run tests matching a filter
[group('test')]
test-filter filter:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! command -v bats &>/dev/null; then
        printf "Error: bats not installed. Run 'just test-setup' first.\n" >&2
        exit 1
    fi
    [[ -d tests/libs ]] || ./tests/setup-bats-libs.sh
    bats -f "{{filter}}" tests/
    result=$?
    if [[ $result -le 1 ]]; then exit 0; else exit $result; fi
