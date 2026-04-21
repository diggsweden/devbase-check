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

   Linters verify each tool comes from mise. If mise has the tool pinned but
   not installed, the linter fails with an actionable message (run
   `mise install`). In locked-down environments where you can't fix the
   install, set `DEVBASE_CHECK_ALLOW_SYSTEM_TOOLS=1` to fall back to a system
   tool with a visible warning.

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
