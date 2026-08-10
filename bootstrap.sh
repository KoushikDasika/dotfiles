#!/usr/bin/env bash
set -euo pipefail
# Minimal bootstrap: install mise + just prerequisites, then delegate to justfile.
# Usage:
#   ./bootstrap.sh          # full setup (just setup)
#   ./bootstrap.sh symlinks # run one step
#   ./bootstrap.sh --list   # list available steps

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install mise if missing
if ! command -v mise &>/dev/null && [[ ! -x "$HOME/.local/bin/mise" ]]; then
    echo "Installing mise..."
    curl https://mise.run | sh
fi

export PATH="$HOME/.local/bin:$PATH"
eval "$("$HOME/.local/bin/mise" activate bash)" 2>/dev/null || true

# Install just via mise if missing
if ! command -v just &>/dev/null; then
    echo "Installing just via mise..."
    mise install just
    eval "$("$HOME/.local/bin/mise" activate bash)" 2>/dev/null || true
fi

# Delegate to the justfile
cd "$DOTFILES_DIR"
if [[ $# -eq 0 ]]; then
    exec just setup
else
    exec just "$@"
fi
