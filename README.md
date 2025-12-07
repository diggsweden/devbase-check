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

# Extend base linters with Java-specific ones
lint-all: _ensure-devtools lint-java
    #!/usr/bin/env bash
    source "{{colors}}"
    just --justfile {{devtools_dir}}/justfile lint-base
    just_success "All linting checks completed"

lint-java:
    @{{java_lint}}/lint.sh
```

See [`examples/java-justfile`](examples/java-justfile) for a complete example.

### Node/TypeScript Project

```just
node_lint := devtools_dir + "/linters/node"

# Extend base linters with Node linters
lint-all: _ensure-devtools lint-node
    #!/usr/bin/env bash
    source "{{colors}}"
    just --justfile {{devtools_dir}}/justfile lint-base
    just_success "All linting checks completed"

lint-node:
    @{{node_lint}}/lint.sh
```

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
# Run all linters (uses base linters only)
lint-all: _ensure-devtools
    @just --justfile {{devtools_dir}}/justfile lint-base
```

### Multiple Languages

```just
lint-all: _ensure-devtools lint-java lint-python lint-node
    #!/usr/bin/env bash
    source "{{colors}}"
    just --justfile {{devtools_dir}}/justfile lint-base
    just_success "All linting checks completed"
```

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
