# dotfiles

Personal machine configuration for Ubuntu (x86-64 and ARM64).

## Structure

```
dotfiles/
├── ai/                        # AI coding tools
│   ├── claude-code/           # Claude Code global config + skills
│   ├── opencode/              # opencode config, agents, plugins
│   ├── beads/                 # beads (bd) task tracker config
│   ├── bdui/                  # beads-ui (npm, no config files)
│   └── mempalace/             # mempalace memory config
├── dev/                       # Development environment
│   ├── nvim/                  # Neovim config (LazyVim)
│   ├── tmux.conf              # tmux config
│   ├── mise/                  # mise tool versions
│   └── just/                  # global justfile + vLLM mise task
├── justfile                   # Setup recipes (replaces bootstrap.sh)
├── bootstrap.sh               # Prerequisite installer (mise + just), then calls justfile
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

## Individual steps

```bash
just --list          # show all available recipes
just symlinks        # set up all symlinks only
just mise-tools      # install/update mise tools
just shell           # configure .bashrc
just bash-completion # set up completions for mise, just, bd
just gnome           # GNOME fonts + dash-to-dock + dconf settings
just llama           # build llama.cpp
just docker          # install Docker CE
```

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
| `ai/beads/config.yaml` | `~/.beads/config.yaml` |
| `ai/mempalace/config.json` | `~/.mempalace/config.json` |

## Mise tools

Defined in `dev/mise/config.toml`. Highlights:

- **Languages**: node 24.15, python 3.12.13, elixir 1.20.2-otp-29, erlang 29.0.3, rust 1.97.1
- **AI**: `pipx:mempalace`, `npm:beads-ui`
- **CLI**: `github:rtk-ai/rtk`, `github:gastownhall/beads`, just, kubectl, helm, minikube, tilt, doppler, gum, stern, uv, yarn
- **DB**: `aqua:dolthub/dolt`

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
- `agents/` — 26 Elixir/Phoenix specialized agents (ash, ecto, oban, liveview, security, etc.)
- `plugins/phx-hooks.js` — Elixir/Phoenix hook shim for opencode
- `plugins/rtk.js` — RTK bash rewriter plugin for opencode

### beads (`ai/beads/`)

Config for the `bd` issue tracker. No database files tracked — only `config.yaml` (preferences, not secrets).

### mempalace (`ai/mempalace/`)

`config.json` selects the SQLite backend. The 777MB database lives at `~/.mempalace/palace/` (not tracked).

## Dev section

### nvim (`dev/nvim/`)

LazyVim configuration. Plugins include: avante.lua, elixir-tools, formatting, snacks, neo-tree.

### tmux (`dev/tmux.conf`)

### Global justfile (`dev/just/justfile`)

`just -g` runs against this file from any directory. Recipes for local LLM servers:
- `just -g qwen` — Qwen3.6-35B-A3B MoE via llama.cpp (primary daily driver, 256K ctx)
- `just -g gemma` — Gemma-4-12B QAT + MTP speculative decode
- `just -g qwen-nvfp4-unsloth` — Qwen3.6-27B NVFP4 via vLLM

`dev/just/.mise.toml` defines a `setup` task that installs vLLM into a local venv.

## GNOME

`gnome-settings.dconf` is exported with `dconf dump /org/gnome/` and loaded by `just gnome`.
To update after changing settings: `dconf dump /org/gnome/ > gnome-settings.dconf`.
