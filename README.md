# dotfiles

Personal machine configuration for Ubuntu (x86-64 and ARM64). Current primary machine: DGX Spark (GB10, 121GB unified memory, arm64).

## Structure

```
dotfiles/
├── ai/                        # AI coding tools
│   ├── claude-code/           # Claude Code global config + skills
│   ├── opencode/              # opencode config, agents, plugins, skills
│   ├── beads/                 # beads (bd) task tracker config
│   ├── bdui/                  # beads-ui (npm, no config files)
│   ├── mempalace/             # mempalace memory config
│   └── sparkrun-recipes/      # local sparkrun YAML recipes (4 models)
├── dev/                       # Development environment
│   ├── nvim/                  # Neovim config (LazyVim)
│   ├── tmux.conf              # tmux config (+ TPM plugins)
│   ├── mise/                  # mise tool versions
│   └── just/                  # global justfile + hardware-gated modules
├── server/                    # DGX Spark server setup
│   ├── PLAN.md                # server build plan
│   ├── llama.service          # llama.cpp systemd unit (Qwen3.8-27B, :8080)
│   ├── server.just            # server management recipes (`mod? server`)
│   └── tailscale/             # declarative Tailscale serve configs
├── justfile                   # setup recipes
├── bootstrap.sh               # prerequisite installer (mise + just), then calls justfile
└── gnome-settings.dconf       # GNOME settings export
```

## Bootstrap

Fresh machine:

```bash
git clone git@github.com:KoushikDasika/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles
./bootstrap.sh
```

`bootstrap.sh` installs `mise` and `just`, then runs `just setup`. All setup logic lives in the `justfile`.

## Setup recipes (root justfile)

```bash
just --list          # show all recipes
just setup           # full chain, in order:
                     #   packages snaps fex zoom symlinks tmux-plugins
                     #   mise-install mise-tools desktop docker gnome
                     #   llama box64 hf shell bash-completion git-config
```

| Recipe | What it does |
|---|---|
| `packages` | apt base (build tools, git, tmux, ripgrep, fzf, dev libs) |
| `snaps` | nvim, chromium, slack (slack on x86 only) |
| `fex` | FEX-Emu x86/x86-64 emulation (ARM64 only) |
| `zoom` | Zoom from `~/Downloads/zoom_amd64.deb` + `~/.local/bin/zoom` wrapper |
| `symlinks` | all dotfile symlinks (below); hardware-gates just modules |
| `opencode-skills-update` | snapshot Claude plugin skill caches into `ai/opencode/skills` |
| `tmux-plugins` | TPM + plugin install |
| `mise-install` | mise itself |
| `mise-tools` | `mise install` from `dev/mise/config.toml` |
| `desktop` | Chrome, Sublime Text, Beekeeper Studio (x86-only apps skipped on arm64) |
| `docker` | Docker CE + user into docker group |
| `gnome` | ubuntu-desktop, tweaks, Nerd Fonts, Dash to Dock, dconf settings |
| `llama` | clone + build llama.cpp (CUDA if `nvidia-smi` present) |
| `box64` | box64 x86-64 emulator (ARM64 only) |
| `hf` | Hugging Face CLI via `uv tool install` |
| `shell` | `.bashrc` additions (mise activation, aliases, PATH) |
| `bash-completion` | bash completions for mise, just, bd, rtk |
| `git-config` | `~/.gitconfig` (name, email, gpg ssh, aliases) |
| `tailscale` | install Tailscale (official .deb) |
| `ts-up [hostname]` | join tailnet with `--ssh` (honors `TS_AUTH_KEY` env) |
| `ts-serve` | apply `server/tailscale/llamacpp.json` as `svc:llamacpp` |
| `tailscale-client` | install + join, no serve (client machines) |
| `tailscale-server` | install + join + apply serve config (server machines) |

Tailscale recipes are not in the `setup` chain — `ts-up` is interactive (auth link) on first use.

## Symlinks

`just symlinks` creates these links (existing files are backed up):

| Dotfiles path | Target |
|---|---|
| `dev/nvim` | `~/.config/nvim` |
| `dev/tmux.conf` | `~/.tmux.conf` |
| `dev/mise/config.toml` | `~/.config/mise/config.toml` |
| `dev/just/justfile` | `~/.config/just/justfile` |
| `dev/just/.mise.toml` | `~/.config/just/.mise.toml` |
| `ai/claude-code/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `ai/claude-code/RTK.md` | `~/.claude/RTK.md` |
| `ai/claude-code/settings.json` | `~/.claude/settings.json` |
| `ai/claude-code/statusline.mjs` | `~/.claude/statusline.mjs` |
| `ai/claude-code/track-active-context.mjs` | `~/.claude/track-active-context.mjs` |
| `ai/claude-code/skills` | `~/.claude/skills` |
| `ai/opencode/opencode.json` | `~/.config/opencode/opencode.json` |
| `ai/opencode/opencode-mem.jsonc` | `~/.config/opencode/opencode-mem.jsonc` |
| `ai/opencode/AGENTS.md` | `~/.config/opencode/AGENTS.md` |
| `ai/opencode/caveman.md` | `~/.config/opencode/caveman.md` |
| `ai/opencode/RTK.md` | `~/.config/opencode/RTK.md` |
| `ai/opencode/agents` | `~/.config/opencode/agents` |
| `ai/opencode/plugins` | `~/.config/opencode/plugins` |
| `ai/opencode/skills` | `~/.config/opencode/skills` |
| `ai/beads/config.yaml` | `~/.beads/config.yaml` |
| `ai/mempalace/config.json` | `~/.mempalace/config.json` |

Hardware-gated (GB10 / DGX Spark only, detected via `nvidia-smi`):

| Dotfiles path | Target |
|---|---|
| `dev/just/atlas.just` | `~/.config/just/atlas.just` |
| `dev/just/sparkrun.just` | `~/.config/just/sparkrun.just` |
| `dev/just/llama.just` | `~/.config/just/llama.just` |
| `dev/just/vllm.just` | `~/.config/just/vllm.just` |
| `dev/just/qwen38.just` | `~/.config/just/qwen38.just` |
| `server/server.just` | `~/.config/just/server.just` |
| `server/llama.service` | `/etc/systemd/system/llama.service` |

Non-GB10 machines get `dev/just/rtx5090.just` → `~/.config/just/rtx5090.just` instead. `mod?` in the global justfile silently skips unlinked modules, so one global justfile serves both hardware profiles.

## Global justfile (`dev/just/justfile`)

`just -g` runs from anywhere against this file. Top-level recipes:

| Recipe | What it does |
|---|---|
| `up` | daily driver → `atlas a3b` |
| `down` | `sparkrun stop --all --hosts localhost` |
| `status` | `sparkrun status --hosts localhost` |
| `bench model` | `llama-bench` any local gguf |
| `headless` | `set-default` + `isolate` `multi-user.target` (GUI off now + on reboot) |
| `gui` | `set-default` + `isolate` `graphical.target` (GUI on now + on reboot) |

`headless`/`gui` run `sudo systemctl set-default <target>` (persists across reboot) plus `isolate` (applies immediately). sshd, tailscaled, and `llama.service` all live in `multi-user.target` and keep running headless. Run `headless` from tmux or SSH — a GUI terminal dies with the display.

### Hardware-gated modules

| Module | Recipes | Notes |
|---|---|---|
| `atlas` | `a3b`, `a3b-nvfp4`, `dense`, `dense-nvfp4` | sparkrun `@atlas` registry recipes (GB10) |
| `sparkrun` | `a3b`, `dense27b`, `a3b-nospec`, `qwen-35-122b`, `download-dflash` | local YAMLs from `ai/sparkrun-recipes/` (GB10) |
| `llama` | `a3b-q8`, `a3b-bf16`, `dense-q8`, `dense-bf16`, `bench-a3b`, `bench-dense` | llama.cpp, GB10-tuned (256K ctx, MTP) |
| `vllm` | `dense-nvfp4-unsloth`, `dense-nvfp4-nvidia`, `qwen3-8` | vLLM in `~/.config/just/.venv` (GB10) |
| `qwen38` | `find`, `find-recipes`, `serve`, `dense-bf16` | Qwen3.8-27B landing pad (GB10) |
| `server` | `server-enable`, `server-status`, `server-logs`, `server-restart` | systemd services (GB10) |
| `rtx5090` | `gemma*`, `qwen*` (15 recipes), `qwen38-nvfp4` | legacy 24GB RTX 5090 laptop |

## Server (DGX Spark)

### llama.cpp systemd unit

`server/llama.service` runs Qwen3.8-27B UD-Q4_K_XL on `0.0.0.0:8080` (200K ctx, MTP, q8_0 KV cache), `WantedBy=multi-user.target` — starts at boot in GUI and headless modes alike.

```bash
just -g server server-enable   # daemon-reload + enable --now llama
just -g server server-status
just -g server server-logs llama
```

### Tailscale (`svc:llamacpp`)

Tailscale serves the llama.cpp API over the tailnet as a declarative service:

- Hostname: `llamacpp.tail5e55e1.ts.net`
- Endpoints: `tcp:443` and `tcp:8080` → `http://localhost:8080` (llama.cpp)
- Config: `server/tailscale/llamacpp.json` (exactly what `tailscale serve get-config --service=svc:llamacpp` returns)

```bash
just tailscale-server   # fresh machine: install + join + apply serve config
just ts-serve           # re-apply config only (idempotent)
```

Tailscale SSH (`--ssh`) is enabled on this node for tailnet-native SSH access.

## Headless operation

The machine boots to GNOME by default (`graphical.target`). To run it as a headless server:

```bash
just -g headless   # now + on next reboot: multi-user.target
just -g gui        # now + on next reboot: graphical.target
```

`set-default` persists the choice; `isolate` switches immediately without a reboot. Nothing LLM-related is lost: `llama.service`, `tailscaled`, and `sshd` (socket-activated) are all `multi-user.target` services.

## Mise tools

Defined in `dev/mise/config.toml`. Current pins:

- **Languages**: node 24.15.0, python 3.12.13, elixir 1.20.2-otp-29, erlang 29.0.3, rust 1.97.1
- **AI/agents**: `pipx:mempalace` 3.6.0, `npm:beads-ui` latest, opencode latest, fzf latest
- **CLI**: `github:gastownhall/beads` 1.1.2, `github:rtk-ai/rtk` latest, just 1.52.0, kubectl 1.33.10, helm 4.1.3, minikube 1.38.1, tilt 0.37.0, doppler 3.75.3, gum 0.17.0, stern 1.32.0, uv latest, yarn 1.22.4, `cargo:worktrunk` 0.68.0
- **DB**: `aqua:dolthub/dolt` 2.2.2

## AI section

### Claude Code (`ai/claude-code/`)

- `settings.json` — permissions, hooks (RTK rewriting, beads prime, statusline, caveman), enabled plugins
- `CLAUDE.md` / `RTK.md` — global instructions
- `statusline.mjs` — two-line Nerd Font status bar (model, context %, cost, rate limits)
- `track-active-context.mjs` — hook that tracks active skill + running subagents for statusline
- `skills/generate-interview/` — generate technical interview exercises from a codebase

### opencode (`ai/opencode/`)

- `opencode.json` — MCP (mempalace), skills path, plugins, local LLM providers (llama.cpp + vLLM)
- `AGENTS.md` — operating doctrine (RTK-first, mempalace-first, beads for tasks)
- `caveman.md` — caveman mode rules
- `agents/` — Elixir/Phoenix specialized agents (ash, ecto, oban, liveview, security, etc.)
- `plugins/phx-hooks.js` — Elixir/Phoenix hook shim for opencode
- `plugins/rtk.js` — RTK bash rewriter plugin for opencode
- `skills/` — synced from Claude plugin caches via `just opencode-skills-update`

### beads (`ai/beads/`)

Config for the `bd` issue tracker. No database files tracked — only `config.yaml` (preferences, not secrets). Per-repo databases live in `.beads/` (git-excluded via `bd init --stealth`).

### mempalace (`ai/mempalace/`)

`config.json` selects the SQLite backend. The 777MB database lives at `~/.mempalace/palace/` (not tracked).

### sparkrun recipes (`ai/sparkrun-recipes/`)

Local sparkrun YAMLs used by the `sparkrun` just module: `qwen-3.6-35B-A3B-FP8`, `qwen-3.6-35B-A3B-FP8-nospec`, `qwen-3.6-27B-FP8`, `qwen-3.5-122B-A10B-int4-fp8-hybrid`.

## Dev section

### nvim (`dev/nvim/`)

LazyVim configuration. Plugins include: avante.lua, elixir-tools, formatting, snacks, neo-tree.

### tmux (`dev/tmux.conf`)

tpm installed by `just tmux-plugins`; resurrect layout dirs live outside the repo (`tmux/resurrect/`, gitignored).

### Global justfile (`dev/just/`)

`just -g` runs against `justfile` from any directory (see table above). `dev/just/.mise.toml` defines a `setup` task that installs vLLM into a local venv.

## GNOME

`gnome-settings.dconf` is exported with `dconf dump /org/gnome/` and loaded by `just gnome`.
To update after changing settings: `dconf dump /org/gnome/ > gnome-settings.dconf`.
