# devbase-justkit

<!--
SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government

SPDX-License-Identifier: CC0-1.0
-->

[![Tag](https://img.shields.io/github/v/tag/diggsweden/devbase-justkit?style=for-the-badge&color=green)](https://github.com/diggsweden/devbase-justkit/tags)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![REUSE](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.reuse.software%2Fstatus%2Fgithub.com%2Fdiggsweden%2Fdevbase-justkit&query=status&style=for-the-badge&label=REUSE&color=lightblue)](https://api.reuse.software/info/github.com/diggsweden/devbase-justkit)

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/diggsweden/devbase-justkit/badge?style=for-the-badge)](https://scorecard.dev/viewer/?uri=github.com/diggsweden/devbase-justkit)

Reusable linting for [Just](https://github.com/casey/just) task runner. Install once, use across multiple projects.

## What it does

- Runs linters (shellcheck, yamlfmt, gitleaks, etc.) with one command
- Skips what you don't need - no XML files? No XML linting
- Add language-specific linters (Java, Node/TypeScript) on top
- Centralized linting - update once, affects all projects
- No copy-paste of linter scripts and configs between projects

## Requirements

- [Just](https://github.com/casey/just) - task runner
- [mise](https://mise.jdx.dev/) - tool version manager
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

That's it.

### Updates

Run `just setup-devtools` again to check for updates:

- **Interactive**: Prompts "Update available: vX.Y.Z. Update? [y/N]"
- **CI/non-interactive**: Auto-updates to latest tag

## How it works

You get base linters for free. Add language-specific linters if needed.
Disable base linters you dont want.

![lint-base composition](assets/lintbase.png)

- **`lint-base`** - General inters that work on most project (YAML, shell, secrets, etc.)
- **`lint-all`** - Uses `lint-base`, override to add Java/Node/Python linters
- **Individual recipes** - Run them seperatly, example `just lint-yaml` or `just lint-shell`.

### Base Linters

Run on every project. Skip automatically if no relevant files found:

| Recipe | Tool | Checks | Skips when |
|--------|------|--------|------------|
| `lint-commits` | conform | Commit message format | On default branch or no new commits |
| `lint-secrets` | gitleaks | Secrets/credentials | Never (scans commits) |
| `lint-yaml` | yamlfmt | YAML formatting | No .yml/.yaml files |
| `lint-markdown` | rumdl | Markdown style | No .md files |
| `lint-shell` | shellcheck | Shell script bugs | No .sh/.bash files |
| `lint-shell-fmt` | shfmt | Shell formatting | No .sh/.bash files |
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

Add language-specific recipes to your justfile. The `verify.sh` script (called by `just verify`) **automatically detects** recipes with these names and includes them in the summary:

- Java: `lint-java-checkstyle`, `lint-java-pmd`, `lint-java-spotbugs`
- Node: `lint-node-eslint`, `lint-node-format`, `lint-node-ts-types`

No need to override `lint-all` - just define the recipes and they're picked up automatically.

### Java/Maven Project

```just
java_lint := devtools_dir + "/linters/java"

# Run all Java linters together (convenience command)
[group('lint')]
lint-java:
    @{{java_lint}}/lint.sh

# Individual Java linters (auto-detected by verify.sh)
[group('lint')]
lint-java-checkstyle:
    @{{java_lint}}/checkstyle.sh

[group('lint')]
lint-java-pmd:
    @{{java_lint}}/pmd.sh

[group('lint')]
lint-java-spotbugs:
    @{{java_lint}}/spotbugs.sh

[group('lint')]
lint-java-fmt:
    @{{java_lint}}/format.sh check

[group('fix')]
lint-java-fmt-fix:
    @{{java_lint}}/format.sh fix
```

When you run `just verify`, the verify script automatically detects `lint-java-checkstyle`, `lint-java-pmd`, and `lint-java-spotbugs` recipes and includes them in the summary table. You can also run `just lint-java` to execute all Java linters together.

See [`examples/java-justfile`](examples/java-justfile) for a complete example.

### Node/TypeScript Project

```just
node_lint := devtools_dir + "/linters/node"

# Run all Node linters together (convenience command)
[group('lint')]
lint-node:
    @{{node_lint}}/lint.sh

# Individual Node linters (auto-detected by verify.sh)
[group('lint')]
lint-node-eslint:
    @{{node_lint}}/eslint.sh

[group('lint')]
lint-node-format:
    @{{node_lint}}/format.sh check

[group('lint')]
lint-node-ts-types:
    @{{node_lint}}/types.sh

[group('fix')]
lint-node-format-fix:
    @{{node_lint}}/format.sh fix
```

When you run `just verify`, the verify script automatically detects `lint-node-*` recipes and includes them in the summary table. You can also run `just lint-node` to execute all Node linters together.

See [`examples/node-justfile`](examples/node-justfile) for a complete example.

### Go Project

```just
# Go linter (add to verify.sh detection if needed)
[group('lint')]
lint-go:
    go vet ./...
    golangci-lint run
```

### Rust Project

```just
# Rust linters (add to verify.sh detection if needed)
[group('lint')]
lint-rust:
    cargo fmt --check
    cargo clippy -- -D warnings
```

> **Note:** Go and Rust linters are not auto-detected by `verify.sh` yet. You can add detection in `scripts/verify.sh` following the Java/Node pattern, or run them separately with `just lint-go` / `just lint-rust`.

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

# Node linters
lint-node-eslint:
    @{{node_lint}}/eslint.sh
```

All defined `lint-*` recipes are automatically detected and included in the summary.

## Customizing and Skipping Linters

You can override any linter recipe in your project's justfile to customize behavior or skip checks.

### Disable or Skip a Linter

Two options to disable a linter:

**Option 1: Hide completely** - empty recipe (no output), linter won't appear in summary:

```just
[group('lint')]
lint-license:
```

**Option 2: Show as skipped** - output message containing "Skip", shown as skipped in summary:

```just
[group('lint')]
lint-license:
    @echo "Skipping license check - not required for this project"
```

**Result in summary:**

```text
# Option 1: not shown at all
# Option 2:
License                reuse         -  skipped
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

### Override Default Linter Configs

Linters use sensible defaults (e.g., excluding `target/`, `node_modules/`, `generated-sources/`). Override by adding config files to your project:

| Linter | Project config file | Default exclusions |
|--------|--------------------|--------------------|
| yamlfmt | `.yamlfmt` | `target/`, `node_modules/`, `generated-sources/`, `dist/`, `build/` |
| spotbugs | `development/spotbugs-exclude.xml` or `.spotbugs-exclude.xml` | `*generated-sources*` |
| gitleaks | `.gitleaks.toml` | none |
| rumdl | `.rumdl.toml` | `CHANGELOG.md` |

Example `.yamlfmt`:

```yaml
exclude:
  - target/
  - my-custom-dir/
formatter:
  type: basic
  retain_line_breaks_single: true
```

Example `development/spotbugs-exclude.xml`:

```xml
<FindBugsFilter>
    <Match><Package name="~com\.example\.generated.*"/></Match>
</FindBugsFilter>
```

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
│   ├── config/
│   │   └── .yamlfmt           # Default yamlfmt config
│   ├── java/
│   │   ├── config/
│   │   │   └── spotbugs-exclude.xml  # Default spotbugs exclusions
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
