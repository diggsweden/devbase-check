# Development Guide

## Prerequisites - Linux

1. Install [mise](https://mise.jdx.dev/) (manages linting tools):

   ```bash
   curl https://mise.run | sh
   ```

2. Activate mise in your shell:

   ```bash
   # For bash - add to ~/.bashrc
   eval "$(mise activate bash)"

   # For zsh - add to ~/.zshrc
   eval "$(mise activate zsh)"

   # For fish - add to ~/.config/fish/config.fish
   mise activate fish | source
   ```

   Then restart your terminal.

3. Install pipx (needed for `pipx:reuse` license linting):

   ```bash
   # Debian/Ubuntu
   sudo apt install pipx
   ```

   Linters verify each tool comes from mise. If mise has a tool pinned but
   not installed, `just verify` fails fast with a single actionable message
   (run `mise install`) instead of letting each linter fail separately.

   Opt-outs, in order of preference:

   - `just verify --ignore-missing-linters` — run anyway; linters whose
     tool isn't installed are skipped, the rest run normally. Same as
     setting `DEVBASE_CHECK_IGNORE_MISSING_LINTERS=1`.
   - `DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS=1` — skip the mise-pin check and
     fall back to whatever tool is on PATH, with a visible warning.
     Intended for locked-down environments where `mise install` can't
     complete.

4. Install project tools:

   ```bash
   just install
   ```

5. Run quality checks:

   ```bash
   just verify
   ```

## Prerequisites - macOS

1. Install [mise](https://mise.jdx.dev/) (manages linting tools):

   ```bash
   brew install mise
   ```

2. Activate mise in your shell:

   ```bash
   # For zsh - add to ~/.zshrc
   eval "$(mise activate zsh)"

   # For bash - add to ~/.bashrc
   eval "$(mise activate bash)"

   # For fish - add to ~/.config/fish/config.fish
   mise activate fish | source
   ```

   Then restart your terminal.

3. Install newer bash than macOS default:

   ```bash
   brew install bash
   ```

4. Install pipx (needed for `pipx:reuse` license linting):

   ```bash
   brew install pipx
   ```

5. Install project tools:

   ```bash
   just install
   ```

6. Run quality checks:

   ```bash
   just verify
   ```

## Running Tests

```bash
just test
```

## Available Commands

Run `just` to see all available commands.
