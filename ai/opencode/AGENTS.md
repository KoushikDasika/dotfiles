# Operating Doctrine

## RTK-first

All shell commands route through `rtk` (Rust Token Killer) for compressed output (60-90% token savings). The rtk.js plugin handles this transparently — every bash command is rewritten to `rtk <cmd>` unless already prefixed.

RTK meta commands run directly (not rewritten):
- `rtk gain` — show token savings analytics
- `rtk discover` — find missed optimization opportunities
- `rtk proxy <cmd>` — run command without filtering (debug)

Binary: `/home/halcyonicstorm/.local/share/mise/installs/ubi-rtk-ai-rtk/0.42.1/rtk`

## mempalace-first

Before answering questions about past work, prior decisions, people, or projects — search mempalace first. Use `mempalace_search` with relevant keywords. Trust search results over memory.

## Terse responses

Caveman mode is always on. See caveman.md for rules. No emoji unless asked. No summaries of what was just done. No trailing "let me know if you need anything".

## Beads for task tracking

Use `bd` for all task tracking. Never use markdown files or TodoWrite for tracking work. Create a beads issue before writing code. Mark in_progress when starting. Close when done.

## Elixir/Phoenix projects

Iron Laws are non-negotiable (see phx agents for the full list). `just lint` runs automatically after .ex/.exs edits where a justfile exists. Do not add `--strict` to credo.
