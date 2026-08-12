# dotfiles/justfile — machine setup recipes
# Run a single step:  just <recipe>
# Full fresh setup:   just setup

set shell := ["bash", "-euo", "pipefail", "-c"]

DOTFILES := justfile_directory()

# List available recipes
default:
    @just --list

# Full machine setup (all steps in order)
setup: packages snaps fex zoom symlinks tmux-plugins mise-install mise-tools desktop docker gnome llama box64 hf shell bash-completion git-config
    @echo ""
    @echo "=== Setup complete ==="
    @echo "Run: source ~/.bashrc"

# ── System ──────────────────────────────────────────────────────────────────

# Install apt system packages
packages:
    #!/usr/bin/env bash
    set -euo pipefail
    pkgs=(
        build-essential cmake pkg-config bash-completion
        git curl wget unzip jq snapd
        tmux xclip
        ripgrep fd-find
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
        libncursesw5-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev tk-dev
        libncurses5-dev autoconf m4 libwxgtk3.2-dev
        libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev
        unixodbc-dev xsltproc fop fzf
    )
    to_install=()
    for pkg in "${pkgs[@]}"; do
        dpkg -s "$pkg" &>/dev/null || to_install+=("$pkg")
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
        echo "Installing: ${to_install[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${to_install[@]}"
    fi
    echo "packages ok"

# Install snap packages (nvim, chromium, slack)
snaps:
    #!/usr/bin/env bash
    set -euo pipefail
    snap list nvim    &>/dev/null || sudo snap install nvim --classic
    snap list chromium &>/dev/null || sudo snap install chromium
    arch="$(dpkg --print-architecture)"
    if [[ "$arch" != "arm64" ]]; then
        snap list slack &>/dev/null || sudo snap install slack
    fi
    echo "snaps ok"

# FEX-Emu x86/x86-64 emulation (ARM64 only)
fex:
    #!/usr/bin/env bash
    set -euo pipefail
    arch="$(dpkg --print-architecture)"
    [[ "$arch" != "arm64" ]] && { echo "Not arm64 — skipping FEX-Emu"; exit 0; }
    if dpkg -s fex-emu-armv8.0 &>/dev/null || dpkg -s fex-emu-armv8.2 &>/dev/null || dpkg -s fex-emu-armv8.4 &>/dev/null; then
        echo "FEX-Emu already installed"; exit 0
    fi
    if ! apt-cache show fex-emu-armv8.2 &>/dev/null 2>&1; then
        sudo add-apt-repository -y ppa:fex-emu/fex
        sudo apt-get update -qq
    fi
    variant="armv8.0"
    grep -q 'flagm'   /proc/cpuinfo 2>/dev/null && variant="armv8.4" || true
    grep -q 'asimdhp' /proc/cpuinfo 2>/dev/null && [[ "$variant" == "armv8.0" ]] && variant="armv8.2" || true
    sudo apt-get install -y -qq "fex-emu-${variant}" fex-emu-binfmt64
    echo "FEX-Emu ok (${variant})"

# Install Zoom from ~/Downloads/zoom_amd64.deb
zoom:
    #!/usr/bin/env bash
    set -euo pipefail
    deb="$HOME/Downloads/zoom_amd64.deb"
    if dpkg -s zoom &>/dev/null; then
        sudo apt-mark hold zoom &>/dev/null || true
        echo "Zoom already installed"
    elif [[ -f "$deb" ]]; then
        sudo dpkg -i --force-all "$deb"
        sudo apt-mark hold zoom
        echo "Zoom installed"
    else
        echo "WARNING: $deb not found — download from zoom.us and re-run"
    fi
    if [[ ! -x "$HOME/.local/bin/zoom" ]] || ! grep -q 'ZoomLauncher' "$HOME/.local/bin/zoom" 2>/dev/null; then
        mkdir -p "$HOME/.local/bin"
        printf '%s\n' \
            '#!/bin/bash' \
            'export LD_LIBRARY_PATH="/opt/zoom/Qt/lib:/opt/zoom${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"' \
            'exec /opt/zoom/ZoomLauncher "$@"' \
            > "$HOME/.local/bin/zoom"
        chmod +x "$HOME/.local/bin/zoom"
    fi
    echo "zoom wrapper ok"

# ── Development Environment ──────────────────────────────────────────────────

# Set up all dotfile symlinks
symlinks:
    #!/usr/bin/env bash
    set -euo pipefail
    DOTFILES="{{DOTFILES}}"
    safe_symlink() {
        local src="$1" target="$2"
        if [[ -L "$target" ]]; then
            local cur; cur="$(readlink -f "$target")"
            [[ "$cur" == "$(readlink -f "$src")" ]] && { echo "  ok: $target"; return 0; }
            echo "  relink: $target"
            rm "$target"
        elif [[ -e "$target" ]]; then
            local bak="${target}.bak.$(date +%s)"
            echo "  backup: $target -> $bak"
            mv "$target" "$bak"
        fi
        mkdir -p "$(dirname "$target")"
        ln -sf "$src" "$target"
        echo "  linked: $target"
    }

    # Dev environment
    safe_symlink "$DOTFILES/dev/nvim"     "$HOME/.config/nvim"
    safe_symlink "$DOTFILES/dev/tmux.conf" "$HOME/.tmux.conf"

    # Mise
    safe_symlink "$DOTFILES/dev/mise/config.toml" "$HOME/.config/mise/config.toml"

    # Claude Code
    mkdir -p "$HOME/.claude"
    safe_symlink "$DOTFILES/ai/claude-code/CLAUDE.md"               "$HOME/.claude/CLAUDE.md"
    safe_symlink "$DOTFILES/ai/claude-code/RTK.md"                  "$HOME/.claude/RTK.md"
    safe_symlink "$DOTFILES/ai/claude-code/settings.json"           "$HOME/.claude/settings.json"
    safe_symlink "$DOTFILES/ai/claude-code/statusline.mjs"          "$HOME/.claude/statusline.mjs"
    safe_symlink "$DOTFILES/ai/claude-code/track-active-context.mjs" "$HOME/.claude/track-active-context.mjs"
    safe_symlink "$DOTFILES/ai/claude-code/skills"                  "$HOME/.claude/skills"

    # opencode
    mkdir -p "$HOME/.config/opencode"
    safe_symlink "$DOTFILES/ai/opencode/opencode.json"     "$HOME/.config/opencode/opencode.json"
    safe_symlink "$DOTFILES/ai/opencode/opencode-mem.jsonc" "$HOME/.config/opencode/opencode-mem.jsonc"
    safe_symlink "$DOTFILES/ai/opencode/AGENTS.md"         "$HOME/.config/opencode/AGENTS.md"
    safe_symlink "$DOTFILES/ai/opencode/caveman.md"        "$HOME/.config/opencode/caveman.md"
    safe_symlink "$DOTFILES/ai/opencode/RTK.md"            "$HOME/.config/opencode/RTK.md"
    safe_symlink "$DOTFILES/ai/opencode/agents"            "$HOME/.config/opencode/agents"
    safe_symlink "$DOTFILES/ai/opencode/plugins"           "$HOME/.config/opencode/plugins"

    # just global justfile — hardware-gated modules (mod? skips unlinked files)
    mkdir -p "$HOME/.config/just"
    safe_symlink "$DOTFILES/dev/just/justfile"   "$HOME/.config/just/justfile"
    safe_symlink "$DOTFILES/dev/just/.mise.toml" "$HOME/.config/just/.mise.toml"
    GPU="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)"
    if [[ "$GPU" == *GB10* ]]; then
        just_mods="atlas llama vllm qwen38"
    else
        just_mods="rtx5090"
    fi
    # drop module links from other hardware profiles
    for f in "$HOME/.config/just/"*.just; do
        [[ -L "$f" ]] || continue
        [[ "$(readlink "$f")" == "$DOTFILES/dev/just/"* ]] || continue
        name="$(basename "$f" .just)"
        [[ " $just_mods " == *" $name "* ]] || { echo "  unlink: $f"; rm "$f"; }
    done
    for m in $just_mods; do
        safe_symlink "$DOTFILES/dev/just/$m.just" "$HOME/.config/just/$m.just"
    done

    # beads
    mkdir -p "$HOME/.beads"
    safe_symlink "$DOTFILES/ai/beads/config.yaml" "$HOME/.beads/config.yaml"

    # mempalace
    mkdir -p "$HOME/.mempalace"
    safe_symlink "$DOTFILES/ai/mempalace/config.json" "$HOME/.mempalace/config.json"

    echo "symlinks ok"

# Install Tmux Plugin Manager + plugins
tmux-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    tpm_dir="$HOME/.tmux/plugins/tpm"
    if [[ ! -d "$tpm_dir" ]]; then
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
    fi
    if [[ -x "$tpm_dir/bin/install_plugins" ]]; then
        "$tpm_dir/bin/install_plugins" > /dev/null 2>&1 || true
    fi
    echo "tmux-plugins ok"

# Install mise version manager
mise-install:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v mise &>/dev/null && ! command -v ~/.local/bin/mise &>/dev/null; then
        curl https://mise.run | sh
    fi
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(mise activate bash)" 2>/dev/null || true
    mise --version
    echo "mise ok"

# Install all mise tools (reads from dev/mise/config.toml via symlink)
mise-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(mise activate bash)" 2>/dev/null || true
    echo "Installing mise tools (may take a while)..."
    mise install --yes
    echo "mise-tools ok"

# ── Desktop / Apps ──────────────────────────────────────────────────────────

# Install desktop apps (Chrome, Sublime Text, Beekeeper Studio)
desktop:
    #!/usr/bin/env bash
    set -euo pipefail
    arch="$(dpkg --print-architecture)"

    # Google Chrome (x86 only)
    if [[ "$arch" != "arm64" ]] && ! dpkg -s google-chrome-stable &>/dev/null; then
        if [[ ! -f /usr/share/keyrings/google-chrome.gpg ]]; then
            curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
                | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
        fi
        printf '%s\n' \
            'X-Repolib-Name: Google Chrome' \
            'Types: deb' \
            'URIs: https://dl.google.com/linux/chrome-stable/deb/' \
            'Suites: stable' \
            'Components: main' \
            'Architectures: amd64' \
            'Signed-By: /usr/share/keyrings/google-chrome.gpg' \
            | sudo tee /etc/apt/sources.list.d/google-chrome.sources > /dev/null
        sudo apt-get update -qq && sudo apt-get install -y -qq google-chrome-stable
    fi

    # Sublime Text
    if ! dpkg -s sublime-text &>/dev/null; then
        if [[ ! -f /etc/apt/keyrings/sublimehq-pub.asc ]]; then
            sudo install -d -m 0755 /etc/apt/keyrings
            curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg \
                | sudo tee /etc/apt/keyrings/sublimehq-pub.asc > /dev/null
        fi
        printf '%s\n' \
            'Types: deb' \
            'URIs: https://download.sublimetext.com/' \
            'Suites: apt/stable/' \
            'Signed-By: /etc/apt/keyrings/sublimehq-pub.asc' \
            | sudo tee /etc/apt/sources.list.d/sublime-text.sources > /dev/null
        sudo apt-get update -qq && sudo apt-get install -y -qq sublime-text
    fi

    # Beekeeper Studio (x86 only)
    if [[ "$arch" != "arm64" ]] && ! dpkg -s beekeeper-studio &>/dev/null; then
        if [[ ! -f /usr/share/keyrings/beekeeper.gpg ]]; then
            curl -fsSL https://deb.beekeeperstudio.io/beekeeper.key \
                | sudo gpg --dearmor -o /usr/share/keyrings/beekeeper.gpg
        fi
        printf '%s\n' \
            'Types: deb' \
            'URIs: https://deb.beekeeperstudio.io' \
            'Suites: stable' \
            'Components: main' \
            'Architectures: amd64' \
            'Signed-By: /usr/share/keyrings/beekeeper.gpg' \
            | sudo tee /etc/apt/sources.list.d/beekeeper-studio.sources > /dev/null
        sudo apt-get update -qq && sudo apt-get install -y -qq beekeeper-studio
    fi

    echo "desktop ok"

# Install Docker CE
docker:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! dpkg -s docker-ce &>/dev/null; then
        sudo install -m 0755 -d /etc/apt/keyrings
        if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
            sudo chmod a+r /etc/apt/keyrings/docker.asc
        fi
        codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
        if [[ -z "$codename" ]] || \
           ! curl -fsSL "https://download.docker.com/linux/ubuntu/dists/${codename}/Release" \
               --output /dev/null --silent --head --fail; then
            codename="noble"
        fi
        printf '%s\n' \
            'Types: deb' \
            'URIs: https://download.docker.com/linux/ubuntu' \
            "Suites: ${codename}" \
            'Components: stable' \
            'Signed-By: /etc/apt/keyrings/docker.asc' \
            | sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
    fi
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        sudo usermod -aG docker "$USER"
        echo "  added $USER to docker group (log out/in to take effect)"
    fi
    echo "docker ok"

# Set up GNOME desktop (Nerd Fonts, Dash to Dock, dconf settings)
gnome:
    #!/usr/bin/env bash
    set -euo pipefail
    DOTFILES="{{DOTFILES}}"

    dpkg -s ubuntu-desktop &>/dev/null || sudo apt-get install -y ubuntu-desktop
    for pkg in gnome-tweaks gnome-shell-extension-manager; do
        dpkg -s "$pkg" &>/dev/null || sudo apt-get install -y -qq "$pkg"
    done

    # UbuntuMono Nerd Fonts
    fonts_dir="$HOME/.local/share/fonts"
    if ! ls "$fonts_dir"/UbuntuMonoNerdFont*.ttf &>/dev/null 2>&1; then
        tmp_dir="$(mktemp -d)"
        curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/UbuntuMono.tar.xz" \
            -o "$tmp_dir/UbuntuMono.tar.xz"
        mkdir -p "$fonts_dir"
        tar -xf "$tmp_dir/UbuntuMono.tar.xz" -C "$fonts_dir"
        rm -rf "$tmp_dir"
        fc-cache -fv > /dev/null 2>&1
    fi

    # Dash to Dock
    ext_id="dash-to-dock@micxgx.gmail.com"
    ext_dir="$HOME/.local/share/gnome-shell/extensions/$ext_id"
    repo_dir="$HOME/git/dash-to-dock"
    if [[ ! -d "$ext_dir" ]] || ! gnome-extensions list --user 2>/dev/null | grep -q "$ext_id"; then
        for dep in sassc libglib2.0-bin; do
            dpkg -s "$dep" &>/dev/null || sudo apt-get install -y -qq "$dep"
        done
        mkdir -p "$HOME/git"
        [[ -d "$repo_dir" ]] || git clone https://github.com/micheleg/dash-to-dock.git "$repo_dir"
        make -C "$repo_dir" install
        gnome-extensions enable "$ext_id" 2>/dev/null || true
    fi

    # dconf settings
    dconf_file="$DOTFILES/gnome-settings.dconf"
    if [[ -f "$dconf_file" ]]; then
        dconf load /org/gnome/ < "$dconf_file"
    else
        dconf dump /org/gnome/ > "$dconf_file"
        echo "  exported GNOME settings — commit gnome-settings.dconf"
    fi
    echo "gnome ok"

# ── AI / ML ─────────────────────────────────────────────────────────────────

# Build llama.cpp (CUDA if nvidia-smi detected); skips cmake build if binary already exists
llama:
    #!/usr/bin/env bash
    set -euo pipefail
    llama_dir="$HOME/git/llama.cpp"
    if [[ ! -d "$llama_dir" ]]; then
        mkdir -p "$HOME/git"
        git clone https://github.com/ggerganov/llama.cpp.git "$llama_dir"
    else
        git -C "$llama_dir" pull --ff-only || true
    fi
    bin="$llama_dir/build/bin/llama-server"
    if [[ -f "$bin" ]]; then
        echo "llama already built (delete $bin to rebuild)"
        exit 0
    fi
    cmake_flags=(-DCMAKE_BUILD_TYPE=Release)
    command -v nvidia-smi &>/dev/null && cmake_flags+=(-DGGML_CUDA=ON) && echo "  CUDA build"
    cmake -B "$llama_dir/build" -S "$llama_dir" "${cmake_flags[@]}"
    cmake --build "$llama_dir/build" --config Release -j "$(nproc)"
    echo "llama ok"

# Build box64 x86-64 emulator (ARM64 only)
box64:
    #!/usr/bin/env bash
    set -euo pipefail
    arch="$(dpkg --print-architecture)"
    [[ "$arch" != "arm64" ]] && { echo "Not arm64 — skipping box64"; exit 0; }
    command -v box64 &>/dev/null && { echo "box64 already installed"; exit 0; }
    for dep in cmake python3; do
        dpkg -s "$dep" &>/dev/null || sudo apt-get install -y -qq "$dep"
    done
    box64_dir="$HOME/git/box64"
    [[ -d "$box64_dir" ]] || git clone https://github.com/ptitSeb/box64.git "$box64_dir"
    git -C "$box64_dir" pull --ff-only || true
    cmake -B "$box64_dir/build" -S "$box64_dir" -D ARM_DYNAREC=ON -D CMAKE_BUILD_TYPE=RelWithDebInfo
    cmake --build "$box64_dir/build" -j "$(nproc)"
    sudo cmake --install "$box64_dir/build"
    sudo systemctl restart systemd-binfmt || true
    echo "box64 ok"

# Install Hugging Face CLI via uv
hf:
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(mise activate bash)" 2>/dev/null || true
    command -v hf &>/dev/null && { echo "hf already installed"; exit 0; }
    uv_bin="$(mise which uv 2>/dev/null || echo "")"
    if [[ -n "$uv_bin" ]]; then
        "$uv_bin" tool install huggingface-hub
    elif command -v uv &>/dev/null; then
        uv tool install huggingface-hub
    else
        echo "ERROR: uv not found — run mise-tools first"
        exit 1
    fi
    echo "hf ok"

# ── Shell ────────────────────────────────────────────────────────────────────

# Configure .bashrc
shell:
    #!/usr/bin/env bash
    set -euo pipefail
    add_line() {
        local line="$1"
        grep -qF "$line" "$HOME/.bashrc" 2>/dev/null || echo "$line" >> "$HOME/.bashrc"
    }
    add_line 'eval "$(~/.local/bin/mise activate bash)"'
    add_line 'alias vim="nvim"'
    add_line 'export GIT_EDITOR="nvim"'
    add_line 'export PATH="$HOME/git/llama.cpp/build/bin:$PATH"'
    add_line 'export PATH="$HOME/.local/bin:$PATH"'
    echo "shell ok"

# Set up bash completions (mise, just, bd)
bash-completion:
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(mise activate bash)" 2>/dev/null || true

    comp_dir="$HOME/.local/share/bash-completion/completions"
    mkdir -p "$comp_dir"

    # mise
    if command -v mise &>/dev/null; then
        mise completion bash > "$comp_dir/mise" 2>/dev/null || true
    fi

    # just
    if command -v just &>/dev/null; then
        just --completions bash > "$comp_dir/just" 2>/dev/null || true
    fi

    # bd (beads)
    if command -v bd &>/dev/null; then
        bd completion bash > "$comp_dir/bd" 2>/dev/null || true
    fi

    # rtk
    if command -v rtk &>/dev/null; then
        rtk completion bash > "$comp_dir/rtk" 2>/dev/null || true
    fi

    # Source completions from .bashrc
    add_line() {
        local line="$1"
        grep -qF "$line" "$HOME/.bashrc" 2>/dev/null || echo "$line" >> "$HOME/.bashrc"
    }
    add_line '# bash-completion'
    add_line '[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion'
    add_line '[[ -d "$HOME/.local/share/bash-completion/completions" ]] && for f in "$HOME/.local/share/bash-completion/completions"/*; do [[ -r "$f" ]] && . "$f"; done'

    echo "bash-completion ok"

# Verify/create ~/.gitconfig
git-config:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -f "$HOME/.gitconfig" ]]; then
        git config --global user.name "Koushik Dasika"
        git config --global user.email "koushikdasika@gmail.com"
        git config --global init.defaultBranch main
        git config --global gpg.format ssh
        git config --global commit.gpgsign true
        git config --global alias.lg \
            "log --graph --pretty=tformat:'%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --decorate=full"
        git config --global alias.co checkout
        git config --global alias.br branch
        echo "git config created"
    else
        name="$(git config --global user.name 2>/dev/null || echo '')"
        email="$(git config --global user.email 2>/dev/null || echo '')"
        [[ -n "$name" ]]  && echo "  user.name  = $name"  || echo "  WARNING: user.name not set"
        [[ -n "$email" ]] && echo "  user.email = $email" || echo "  WARNING: user.email not set"
    fi
    echo "git-config ok"
