# devbase-justkit

<!--
SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government

SPDX-License-Identifier: CC0-1.0
-->

[![Tag](https://img.shields.io/github/v/tag/diggsweden/devbase-justkit?style=for-the-badge&color=green)](https://github.com/diggsweden/devbase-justkit/tags)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![REUSE](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.reuse.software%2Fstatus%2Fgithub.com%2Fdiggsweden%2Fdevbase-justkit&query=status&style=for-the-badge&label=REUSE&color=lightblue)](https://api.reuse.software/info/github.com/diggsweden/devbase-justkit)

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/diggsweden/devbase-justkit/badge?style=for-the-badge)](https://scorecard.dev/viewer/?uri=github.com/diggsweden/devbase-justkit)

Reusable linting scripts for [Just](https://github.com/casey/just) task runner. Install once to `~/.local/share/devbase-justkit`, use across multiple projects.

## What it does

- Runs 10+ linters (shellcheck, yamlfmt, gitleaks, etc.) with one command
- Skip what you don't need - no XML files? No XML linting
- Add language-specific linters (Java, Node/TypeScript) on top
- Centralized linting - update once, affects all projects
- No copy-paste of linter scripts and configs between projects

## Requirements

- [Just](https://github.com/casey/just) - task runner (install: `cargo install just` or see [Just installation](https://github.com/casey/just#installation))
- [mise](https://mise.jdx.dev/) - tool version manager (install: `curl https://mise.run | sh` or see [mise installation](https://mise.jdx.dev/getting-started.html))
- Git

## Quick Start

1. **Copy an example justfile** to your project:
   - [`examples/base-justfile`](examples/base-justfile) - Scripts/configs/docs only
   - [`examples/java-justfile`](examples/java-justfile) - Java/Maven project
   - [`examples/node-justfile`](examples/node-justfile) - Node/TypeScript project

2. **Run setup**:

   ```bash
   just setup-devtools  # Downloads to ~/.local/share/devbase-justkit
   just lint-all        # Runs all linters
   ```

That's it. The justfile calls scripts from `~/.local/share/devbase-justkit`.

### Updates

Run `just setup-devtools` again to check for updates:

- **Interactive**: Prompts "Update available: v1.2.3. Update? [y/N]"
- **CI/non-interactive**: Auto-updates to latest tag

## How it works

You get base linters for free. Add language-specific linters if needed.

![lint-base composition](assets/lintbase.png)

- **`lint-base`** - 10 linters that work on any project (YAML, shell, secrets, etc.)
- **`lint-all`** - Uses `lint-base`, override to add Java/Node/Python linters
- **Individual recipes** - Run `just lint-yaml` or `just lint-shell` separately

### Base Linters

Run on every project. Skip automatically if no relevant files found:

| Recipe | Tool | Checks | Skips when |
|--------|------|--------|------------|
| `lint-commits` | conform | Commit message format | No commits to check |
| `lint-secrets` | gitleaks | Secrets/credentials | Never (scans all) |
| `lint-yaml` | yamlfmt | YAML formatting | Never (scans all) |
| `lint-markdown` | rumdl | Markdown style | Never (scans all) |
| `lint-shell` | shellcheck | Shell script bugs | No .sh files |
| `lint-shell-fmt` | shfmt | Shell formatting | No .sh files |
| `lint-actions` | actionlint | GitHub Actions syntax | No .github/workflows/ |
| `lint-license` | reuse | License compliance | Never (scans all) |
| `lint-container` | hadolint | Dockerfile best practices | No Containerfile/Dockerfile |
| `lint-xml` | xmllint | XML syntax/formatting | No .xml files |

### Language-Specific Linters

#### Java

| Recipe | Tool | Description |
|--------|------|-------------|
| `lint-java` | maven | Run all (checkstyle + pmd + spotbugs) |
| `lint-java-checkstyle` | checkstyle | Style checks |
| `lint-java-pmd` | pmd | Static analysis |
| `lint-java-spotbugs` | spotbugs | Bug detection |
| `lint-java-fmt` | formatter | Check formatting |
| `lint-java-fmt-fix` | formatter | Fix formatting |
| `test-java` | maven | Run tests (mvn verify) |

#### Node/TypeScript

| Recipe | Tool | Description |
|--------|------|-------------|
| `lint-node` | npm | Run all (eslint + prettier + types) |
| `lint-node-eslint` | eslint | Code quality checks (JS/TS) |
| `lint-node-format` | prettier | Code formatting check |
| `lint-node-format-fix` | prettier | Fix code formatting |
| `lint-node-ts-types` | tsc | TypeScript type checking |

## Add language-specific linters

Override `lint-all` in your justfile to add Java, Node, Python, etc.:

### Java/Maven Project

```just
java_lint := devtools_dir + "/linters/java"

# Run all linters with summary (automatically detects Java linters)
lint-all: _ensure-devtools
    @{{devtools_dir}}/scripts/verify.sh

# Run all Java linters together (convenience command)
lint-java:
    @{{java_lint}}/lint.sh

# Individual Java linters (auto-detected by verify.sh)
lint-java-checkstyle:
    @{{java_lint}}/checkstyle.sh

lint-java-pmd:
    @{{java_lint}}/pmd.sh

lint-java-spotbugs:
    @{{java_lint}}/spotbugs.sh
```

When you run `just lint-all` or `just verify`, the verify script automatically detects `lint-java-checkstyle`, `lint-java-pmd`, and `lint-java-spotbugs` recipes and runs them individually with a summary table. You can also run `just lint-java` to execute all Java linters together.

See [`examples/java-justfile`](examples/java-justfile) for a complete example.

### Node/TypeScript Project

```just
node_lint := devtools_dir + "/linters/node"

# Run all linters with summary (automatically detects Node linters)
lint-all: _ensure-devtools
    @{{devtools_dir}}/scripts/verify.sh

# Run all Node linters together (convenience command)
lint-node:
    @{{node_lint}}/lint.sh

# Individual Node linters (auto-detected by verify.sh)
lint-node-eslint:
    @{{node_lint}}/eslint.sh

lint-node-format:
    @{{node_lint}}/format.sh check

lint-node-ts-types:
    @{{node_lint}}/types.sh
```

When you run `just lint-all` or `just verify`, the verify script automatically detects `lint-node-*` recipes and runs them individually with a summary table. You can also run `just lint-node` to execute all Node linters together.

See [`examples/node-justfile`](examples/node-justfile) for a complete example.

### Python Project

```just
# Extend base linters with Python linters
lint-all: _ensure-devtools lint-python
    #!/usr/bin/env bash
    source "{{colors}}"
    just --justfile {{devtools_dir}}/justfile lint-base
    just_success "All linting checks completed"

lint-python:
    #!/usr/bin/env bash
    source "{{colors}}"
    just_header "Python Linting" "ruff check"
    ruff check .
    ruff format --check .
    just_success "Python linting passed"
```

### Go Project

```just
# Extend base linters with Go linters
lint-all: _ensure-devtools lint-go
    #!/usr/bin/env bash
    source "{{colors}}"
    just --justfile {{devtools_dir}}/justfile lint-base
    just_success "All linting checks completed"

lint-go:
    #!/usr/bin/env bash
    source "{{colors}}"
    just_header "Go Linting" "golangci-lint run"
    go vet ./...
    golangci-lint run
    just_success "Go linting passed"
```

### Rust Project

```just
# Extend base linters with Rust linters
lint-all: _ensure-devtools lint-rust
    #!/usr/bin/env bash
    source "{{colors}}"
    just --justfile {{devtools_dir}}/justfile lint-base
    just_success "All linting checks completed"

lint-rust:
    #!/usr/bin/env bash
    source "{{colors}}"
    just_header "Rust Linting" "cargo clippy"
    cargo fmt --check
    cargo clippy -- -D warnings
    just_success "Rust linting passed"
```

### Minimal Project (base linters only)

```just
# Run all linters with summary (base linters only)
lint-all: _ensure-devtools
    @{{devtools_dir}}/scripts/verify.sh
```

### Multiple Languages

```just
# Define linters from multiple languages - verify.sh auto-detects them all
lint-all: _ensure-devtools
    @{{devtools_dir}}/scripts/verify.sh

# Java linters
lint-java-checkstyle:
    @{{java_lint}}/checkstyle.sh

# Python linters  
lint-python:
    ruff check .

# Node linters
lint-node-eslint:
    @{{node_lint}}/eslint.sh
```

All defined `lint-*` recipes are automatically detected and included in the summary.

## Customizing and Skipping Linters

You can override any linter recipe in your project's justfile to customize behavior or skip checks.

### Skip a Linter

To skip a linter completely, override the recipe and output a message containing "Skip" or "Skipping". The verify script will mark it as skipped (yellow `-`) in the summary:

```just
# Skip license compliance checks
lint-license:
    @echo "Skipping license check"

# Skip a Java linter
lint-java-checkstyle:
    @echo "Skipping Checkstyle"
```

**Result in summary:**

```text
License                reuse         -  skipped
Java Checkstyle        checkstyle    -  skipped
```

### Customize a Linter

Override a recipe to use custom configurations or different tools:

```just
# Use custom shellcheck config
lint-shell:
    @shellcheck --severity=warning --exclude=SC2034 **/*.sh

# Run checkstyle with custom rules
lint-java-checkstyle:
    @mvn checkstyle:check -Dcheckstyle.config.location=custom-checks.xml
```

### Conditional Linting

Skip linters conditionally based on environment or files:

```just
# Skip license check in development, run in CI
lint-license:
    #!/usr/bin/env bash
    if [[ "${CI:-}" == "true" ]]; then
        {{lint}}/license.sh
    else
        echo "Skipping license check in development"
    fi

# Skip spotbugs if no Java code changed
lint-java-spotbugs:
    #!/usr/bin/env bash
    if git diff --name-only main | grep -q "\.java$"; then
        {{java_lint}}/spotbugs.sh
    else
        echo "Skipping SpotBugs - no Java files changed"
    fi
```

**Note:** The justfile is the interface - `verify.sh` respects all recipe overrides. Changes take effect immediately without updating devbase-justkit.

## Utilities

Use `colors.sh` for consistent output in custom recipes:

```just
my-recipe:
    #!/usr/bin/env bash
    source "{{colors}}"
    just_header "My Task" "some command"
    just_run "Task description" some command arg1 arg2
    just_success "Task completed"
```

Available functions:

| Function | Description |
|----------|-------------|
| `just_header "Title" "cmd"` | Cyan header with dim command |
| `just_run "desc" cmd args...` | Run command, show output only on failure |
| `just_success "msg"` | Green ✓ message |
| `just_error "msg"` | Red ✗ message |
| `just_warn "msg"` | Yellow ! message |

## Configuration

### Custom Repository Location

Override the default repository URL via environment variable:

```bash
# Bash/Zsh - add to .bashrc or .zshrc
export DEVBASE_JUSTKIT_REPO="https://internal.git/org/devbase-justkit"
```

```fish
# Fish - add to config.fish
set -gx DEVBASE_JUSTKIT_REPO "https://internal.git/org/devbase-justkit"
```

The justfile picks this up automatically:

```just
devtools_repo := env("DEVBASE_JUSTKIT_REPO", "https://github.com/diggsweden/devbase-justkit")
```

## Directory Structure

```text
devbase-justkit/
├── linters/
│   ├── java/
│   │   ├── checkstyle.sh
│   │   ├── format.sh
│   │   ├── lint.sh
│   │   ├── pmd.sh
│   │   ├── spotbugs.sh
│   │   └── test.sh
│   ├── node/
│   │   ├── eslint.sh
│   │   ├── format.sh
│   │   ├── lint.sh
│   │   └── types.sh
│   ├── commits.sh
│   ├── container.sh
│   ├── github-actions.sh
│   ├── license.sh
│   ├── markdown.sh
│   ├── secrets.sh
│   ├── shell-fmt.sh
│   ├── shell.sh
│   ├── xml.sh
│   └── yaml.sh
├── scripts/
│   ├── check-tools.sh
│   ├── setup.sh
│   └── verify.sh
├── utils/
│   └── colors.sh
├── examples/
│   ├── base-justfile
│   ├── java-justfile
│   └── node-justfile
├── .mise.toml
├── justfile
└── README.md
```

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT). Documentation and configuration files are licensed under [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/).

See the SPDX headers in each file for details. This project is [REUSE](https://reuse.software/) compliant.
