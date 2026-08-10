#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Constants & Utilities
# ============================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_REPO="git@github.com:KoushikDasika/dotfiles.git"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

ARCH="$(dpkg --print-architecture)"

log_section() { echo -e "\n${BOLD}=== $1 ===${RESET}"; }
log_info()    { echo -e "  ${YELLOW}→${RESET} $1"; }
log_ok()      { echo -e "  ${GREEN}✓${RESET} $1"; }
log_warn()    { echo -e "  ${YELLOW}⚠${RESET} $1"; }
log_err()     { echo -e "  ${RED}✗${RESET} $1"; }

is_pkg_installed() { dpkg -s "$1" &>/dev/null; }
is_snap_installed() { snap list "$1" &>/dev/null 2>&1; }
is_cmd() { command -v "$1" &>/dev/null; }

safe_symlink() {
    local src="$1" target="$2"
    if [[ -L "$target" ]]; then
        local current
        current="$(readlink -f "$target")"
        if [[ "$current" == "$(readlink -f "$src")" ]]; then
            log_ok "Already linked: $target"
            return 0
        fi
        log_warn "Relinking $target (was -> $current)"
        rm "$target"
    elif [[ -e "$target" ]]; then
        local backup="${target}.bak.$(date +%s)"
        log_warn "Backing up $target -> $backup"
        mv "$target" "$backup"
    fi
    mkdir -p "$(dirname "$target")"
    ln -sf "$src" "$target"
    log_ok "Linked: $target -> $src"
}

add_to_bashrc_if_missing() {
    local line="$1" label="$2"
    if grep -qF "$line" "$HOME/.bashrc" 2>/dev/null; then
        log_ok "$label already in .bashrc"
    else
        echo "$line" >> "$HOME/.bashrc"
        log_ok "Added $label to .bashrc"
    fi
}

# ============================================================
# 1. System Packages
# ============================================================

install_system_packages() {
    log_section "System Packages"
    local packages=(
        build-essential cmake pkg-config
        git curl wget unzip jq snapd
        tmux xclip
        ripgrep fd-find
        # Python build deps
        libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
        libncursesw5-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev tk-dev
        # Erlang build deps
        libncurses5-dev autoconf m4 libwxgtk3.2-dev
        libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev
        unixodbc-dev xsltproc fop
    )
    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! is_pkg_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "Installing: ${to_install[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${to_install[@]}"
        log_ok "System packages installed"
    else
        log_ok "All system packages already installed"
    fi
}

# ============================================================
# 2. Snap Packages
# ============================================================

install_snap_packages() {
    log_section "Snap Packages"

    if ! is_snap_installed nvim; then
        sudo snap install nvim --classic
        log_ok "neovim installed"
    else
        log_ok "neovim already installed"
    fi

    if ! is_snap_installed chromium; then
        sudo snap install chromium
        log_ok "chromium installed"
    else
        log_ok "chromium already installed"
    fi

    if [[ "$ARCH" == "arm64" ]]; then
        log_warn "Slack snap has no arm64 build — skipping (use web app or download from slack.com)"
    elif ! is_snap_installed slack; then
        sudo snap install slack
        log_ok "slack installed"
    else
        log_ok "slack already installed"
    fi
}

# ============================================================
# 2.5 FEX-Emu (x86/x86-64 emulation on ARM64)
# ============================================================

install_fex_emu() {
    log_section "FEX-Emu (x86/x86-64 emulation)"

    [[ "$ARCH" != "arm64" ]] && { log_info "Not arm64 — skipping FEX-Emu"; return; }

    if is_pkg_installed fex-emu-armv8.0 || is_pkg_installed fex-emu-armv8.2 || \
       is_pkg_installed fex-emu-armv8.4; then
        log_ok "FEX-Emu already installed"
        return
    fi

    log_info "Adding FEX-Emu PPA..."
    if ! apt-cache show fex-emu-armv8.2 &>/dev/null 2>&1; then
        sudo add-apt-repository -y ppa:fex-emu/fex
        sudo apt-get update -qq
    fi

    # Pick variant from CPU features; flagm = ARMv8.4, asimdhp = ARMv8.2
    local variant="armv8.0"
    grep -q 'flagm'   /proc/cpuinfo 2>/dev/null && variant="armv8.4" || true
    grep -q 'asimdhp' /proc/cpuinfo 2>/dev/null && [[ "$variant" == "armv8.0" ]] && variant="armv8.2" || true

    sudo apt-get install -y -qq "fex-emu-${variant}" fex-emu-binfmt64
    log_ok "FEX-Emu installed (${variant} + binfmt64)"
}

# ============================================================
# 3. Dotfiles Clone
# ============================================================

setup_dotfiles_clone() {
    log_section "Dotfiles Clone"
    if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
        mkdir -p "$(dirname "$DOTFILES_DIR")"
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
        log_ok "Dotfiles cloned to $DOTFILES_DIR"
    else
        log_ok "Dotfiles already present at $DOTFILES_DIR"
    fi
}

# ============================================================
# 4. Symlinks
# ============================================================

setup_symlinks() {
    log_section "Symlinks"
    mkdir -p "$HOME/.config"
    safe_symlink "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf"
    safe_symlink "$DOTFILES_DIR/nvim"      "$HOME/.config/nvim"
}

# ============================================================
# 5. Tmux Plugin Manager
# ============================================================

setup_tmux() {
    log_section "Tmux Plugin Manager"
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [[ ! -d "$tpm_dir" ]]; then
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
        log_ok "TPM cloned"
    else
        log_ok "TPM already present"
    fi

    if [[ -x "$tpm_dir/bin/install_plugins" ]]; then
        "$tpm_dir/bin/install_plugins" > /dev/null 2>&1 || true
        log_ok "Tmux plugins installed"
    fi
}

# ============================================================
# 6. Mise Setup
# ============================================================

setup_mise() {
    log_section "Mise"
    if ! is_cmd mise; then
        log_info "Installing mise..."
        curl https://mise.run | sh
        log_ok "mise installed"
    else
        log_ok "mise already installed ($(mise --version))"
    fi

    add_to_bashrc_if_missing 'eval "$(~/.local/bin/mise activate bash)"' "Mise activation"

    # Activate in current shell for subsequent steps
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(mise activate bash)" 2>/dev/null || true
}

# ============================================================
# 7. Mise Tools
# ============================================================

install_mise_tools() {
    log_section "Mise Tools"
    local mise_config="$HOME/.config/mise/config.toml"
    mkdir -p "$(dirname "$mise_config")"

    cat > "$mise_config" << 'TOML'
[tools]
"aqua:dolthub/dolt" = "2.2.2"
"cargo:worktrunk" = "0.68.0"
doppler = "3.75.3"
elixir = "1.20.2-otp-29"
erlang = "29.0.3"
gum = "0.17.0"
helm = "4.1.3"
just = "1.52.0"
kubectl = "1.33.10"
minikube = "1.38.1"
node = "24.15.0"
"pipx:mempalace" = "3.6.0"
python = "3.12.13"
rust = "1.97.1"
stern = "1.32.0"
uv = "latest"
tilt = "0.37.0"
"github:rtk-ai/rtk" = "latest"
"github:gastownhall/beads" = "1.1.0"
yarn = "1.22.4"
TOML

    log_info "Installing mise tools (this may take a while)..."
    mise install --yes
    log_ok "Mise tools installed"
}

# ============================================================
# 8. Desktop Apps (apt repos)
# ============================================================

install_desktop_apps() {
    log_section "Desktop Apps (apt)"

    install_chrome
    install_sublime
    install_beekeeper
}

install_chrome() {
    if [[ "$ARCH" == "arm64" ]]; then
        log_warn "Google Chrome has no arm64 deb — skipping (Chromium snap is already installed)"
        return
    fi
    if is_pkg_installed google-chrome-stable; then
        log_ok "Google Chrome already installed"
        return
    fi
    log_info "Installing Google Chrome..."
    if [[ ! -f /usr/share/keyrings/google-chrome.gpg ]]; then
        curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
            | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
    fi
    sudo tee /etc/apt/sources.list.d/google-chrome.sources > /dev/null << 'EOF'
X-Repolib-Name: Google Chrome
Types: deb
URIs: https://dl.google.com/linux/chrome-stable/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/google-chrome.gpg
EOF
    sudo apt-get update -qq
    sudo apt-get install -y -qq google-chrome-stable
    log_ok "Google Chrome installed"
}

install_sublime() {
    if is_pkg_installed sublime-text; then
        log_ok "Sublime Text already installed"
        return
    fi
    log_info "Installing Sublime Text..."
    if [[ ! -f /etc/apt/keyrings/sublimehq-pub.asc ]]; then
        sudo install -d -m 0755 /etc/apt/keyrings
        curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg \
            | sudo tee /etc/apt/keyrings/sublimehq-pub.asc > /dev/null
    fi
    sudo tee /etc/apt/sources.list.d/sublime-text.sources > /dev/null << 'EOF'
Types: deb
URIs: https://download.sublimetext.com/
Suites: apt/stable/
Signed-By: /etc/apt/keyrings/sublimehq-pub.asc
EOF
    sudo apt-get update -qq
    sudo apt-get install -y -qq sublime-text
    log_ok "Sublime Text installed"
}

install_beekeeper() {
    if [[ "$ARCH" == "arm64" ]]; then
        log_warn "Beekeeper Studio has no arm64 deb — skipping (download manually from beekeeperstudio.io)"
        return
    fi
    if is_pkg_installed beekeeper-studio; then
        log_ok "Beekeeper Studio already installed"
        return
    fi
    log_info "Installing Beekeeper Studio..."
    if [[ ! -f /usr/share/keyrings/beekeeper.gpg ]]; then
        curl -fsSL https://deb.beekeeperstudio.io/beekeeper.key \
            | sudo gpg --dearmor -o /usr/share/keyrings/beekeeper.gpg
    fi
    sudo tee /etc/apt/sources.list.d/beekeeper-studio.sources > /dev/null << 'EOF'
Types: deb
URIs: https://deb.beekeeperstudio.io
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/beekeeper.gpg
EOF
    sudo apt-get update -qq
    sudo apt-get install -y -qq beekeeper-studio
    log_ok "Beekeeper Studio installed"
}

# ============================================================
# 9. Docker
# ============================================================

install_docker() {
    log_section "Docker"
    if is_pkg_installed docker-ce; then
        log_ok "Docker CE already installed"
    else
        log_info "Installing Docker CE..."
        sudo install -m 0755 -d /etc/apt/keyrings
        if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
            sudo chmod a+r /etc/apt/keyrings/docker.asc
        fi

        local codename
        codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
        # Docker may lag behind newest Ubuntu releases; fall back to noble
        if [[ -z "$codename" ]] || \
           ! curl -fsSL "https://download.docker.com/linux/ubuntu/dists/${codename}/Release" \
               --output /dev/null --silent --head --fail; then
            log_warn "Docker repo not available for $codename, using noble (Ubuntu 24.04)"
            codename="noble"
        fi

        sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null << EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
        sudo apt-get update -qq
        sudo apt-get install -y -qq \
            docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        log_ok "Docker CE installed"
    fi

    if ! groups "$USER" | grep -q '\bdocker\b'; then
        sudo usermod -aG docker "$USER"
        log_warn "Added $USER to docker group (log out/in to take effect)"
    else
        log_ok "User already in docker group"
    fi

}

# ============================================================
# 10. GNOME Desktop Environment
# ============================================================

setup_gnome() {
    log_section "GNOME Desktop"

    if ! is_pkg_installed ubuntu-desktop; then
        log_info "Installing full Ubuntu desktop (this will take a while)..."
        sudo apt-get install -y ubuntu-desktop
        log_ok "ubuntu-desktop installed"
    else
        log_ok "ubuntu-desktop already installed"
    fi

    local gnome_pkgs=(gnome-tweaks gnome-shell-extension-manager)
    local to_install=()
    for pkg in "${gnome_pkgs[@]}"; do
        is_pkg_installed "$pkg" || to_install+=("$pkg")
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
        sudo apt-get install -y -qq "${to_install[@]}"
    fi
    log_ok "GNOME tools installed"

    install_nerd_fonts
    restore_gnome_settings
}

install_nerd_fonts() {
    local fonts_dir="$HOME/.local/share/fonts"
    if ls "$fonts_dir"/Ubuntu*Nerd*.ttf &>/dev/null 2>&1; then
        log_ok "Ubuntu Nerd Fonts already installed"
        return
    fi
    log_info "Installing Ubuntu Nerd Fonts..."
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local version="3.5.0"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/Ubuntu.tar.xz" \
        -o "$tmp_dir/Ubuntu.tar.xz"
    mkdir -p "$fonts_dir"
    tar -xf "$tmp_dir/Ubuntu.tar.xz" -C "$fonts_dir"
    rm -rf "$tmp_dir"
    fc-cache -fv > /dev/null 2>&1
    log_ok "Ubuntu Nerd Fonts installed"
}

restore_gnome_settings() {
    local dconf_file="$DOTFILES_DIR/gnome-settings.dconf"
    if [[ -f "$dconf_file" ]]; then
        log_info "Restoring GNOME settings from $dconf_file..."
        dconf load /org/gnome/ < "$dconf_file"
        log_ok "GNOME settings restored"
    else
        log_info "Exporting current GNOME settings to $dconf_file..."
        dconf dump /org/gnome/ > "$dconf_file"
        log_ok "GNOME settings exported -- commit gnome-settings.dconf to dotfiles repo"
    fi
}

# ============================================================
# 11. llama.cpp
# ============================================================

build_llama_cpp() {
    log_section "llama.cpp"
    local llama_dir="$HOME/git/llama.cpp"

    if [[ ! -d "$llama_dir" ]]; then
        mkdir -p "$HOME/git"
        git clone https://github.com/ggerganov/llama.cpp.git "$llama_dir"
        log_ok "llama.cpp cloned"
    else
        log_info "Updating llama.cpp..."
        git -C "$llama_dir" pull --ff-only || true
    fi

    local cmake_flags=(-DCMAKE_BUILD_TYPE=Release)
    if is_cmd nvidia-smi; then
        cmake_flags+=(-DGGML_CUDA=ON)
        log_info "NVIDIA GPU detected -- building with CUDA"
    fi

    cmake -B "$llama_dir/build" -S "$llama_dir" "${cmake_flags[@]}"
    cmake --build "$llama_dir/build" --config Release -j "$(nproc)"
    log_ok "llama.cpp built"
}

# ============================================================
# 12. Hugging Face CLI
# ============================================================

install_hf_cli() {
    log_section "Hugging Face CLI"
    if is_cmd hf; then
        log_ok "HF CLI already installed"
        return
    fi
    log_info "Installing huggingface-hub via uv..."
    # uv is installed via mise in step 7; ensure it's on PATH
    local uv_bin
    uv_bin="$(mise which uv 2>/dev/null || echo "")"
    if [[ -n "$uv_bin" ]]; then
        "$uv_bin" tool install huggingface-hub
    elif is_cmd uv; then
        uv tool install huggingface-hub
    else
        log_err "uv not found -- install mise tools first"
        return 1
    fi
    log_ok "HF CLI installed"
}

# ============================================================
# 13. Shell Config
# ============================================================

setup_shell() {
    log_section "Shell Config (.bashrc)"

    add_to_bashrc_if_missing 'eval "$(~/.local/bin/mise activate bash)"' "Mise activation"
    add_to_bashrc_if_missing 'alias vim="nvim"'                           "nvim alias"
    add_to_bashrc_if_missing 'export GIT_EDITOR="nvim"'                  "GIT_EDITOR"
    add_to_bashrc_if_missing 'export PATH="$HOME/git/llama.cpp/build/bin:$PATH"' "llama.cpp PATH"
    add_to_bashrc_if_missing 'export PATH="$HOME/.local/bin:$PATH"'      ".local/bin PATH"
}

# ============================================================
# 14. Git Config Verification
# ============================================================

verify_git_config() {
    log_section "Git Config"
    local gitconfig="$HOME/.gitconfig"
    if [[ ! -f "$gitconfig" ]]; then
        log_warn "No ~/.gitconfig found -- creating minimal config"
        git config --global user.name "Koushik Dasika"
        git config --global user.email "koushikdasika@gmail.com"
        git config --global init.defaultBranch main
        git config --global gpg.format ssh
        git config --global commit.gpgsign true
        git config --global alias.lg \
            "log --graph --pretty=tformat:'%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --decorate=full"
        git config --global alias.co checkout
        git config --global alias.br branch
        log_ok "Git config created"
    else
        local name email
        name="$(git config --global user.name 2>/dev/null || echo '')"
        email="$(git config --global user.email 2>/dev/null || echo '')"
        [[ -n "$name" ]]  && log_ok "user.name  = $name"  || log_warn "user.name not set"
        [[ -n "$email" ]] && log_ok "user.email = $email" || log_warn "user.email not set"
    fi
}

# ============================================================
# main
# ============================================================

main() {
    echo ""
    echo -e "${BOLD}=========================================="
    echo "  Dotfiles Bootstrap"
    echo "  $(date)"
    echo -e "==========================================${RESET}"
    echo ""

    install_system_packages
    install_snap_packages
    install_fex_emu
    setup_dotfiles_clone
    setup_symlinks
    setup_tmux
    setup_mise
    install_mise_tools
    install_desktop_apps
    install_docker
    setup_gnome
    build_llama_cpp
    install_hf_cli
    setup_shell
    verify_git_config

    echo ""
    echo -e "${BOLD}=== Bootstrap Complete ===${RESET}"
    echo "  Run 'source ~/.bashrc' or log out/in for all changes to take effect."
    echo "  If gnome-settings.dconf was exported, commit it to the dotfiles repo."
    echo ""
}

main "$@"
