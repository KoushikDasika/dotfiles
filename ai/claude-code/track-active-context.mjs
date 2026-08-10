#!/usr/bin/env node
// track-active-context.mjs
// Maintains a per-session append-only event log of the active skill + running subagents,
// so statusline.ps1 can display "what's running right now".
//
// Wired in ~/.claude/settings.json on four hook events:
//   UserPromptSubmit  -> compact the log + clear the previous turn's skill (quiescent point)
//   PreToolUse(Skill) -> record the invoked skill for the current turn
//   SubagentStart     -> mark a subagent as running
//   SubagentStop      -> mark a subagent as finished
//
// State file: ~/.claude/cache/active-context-<session_id>.jsonl (no-BOM UTF-8, Node default).
// Robust by design: never throws, always exits 0, so it can never break a hook chain.

import { readFileSync, writeFileSync, appendFileSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

// Generic default (~/.claude/cache), so this bundle needs no gbrain install.
// statusline.ps1's $CacheRoot MUST match this. A gbrain user can switch both to
// ['.gbrain', 'cache'] to co-locate with the cost-cache pipeline.
const CACHE_DIR = join(homedir(), '.claude', 'cache');

function readStdin() {
  // Stream-based read: readFileSync(0) throws EAGAIN on a Windows pipe.
  return new Promise((resolve) => {
    let data = '';
    try {
      process.stdin.setEncoding('utf8');
      process.stdin.on('data', (c) => { data += c; });
      process.stdin.on('end', () => resolve(data));
      process.stdin.on('error', () => resolve(data));
    } catch { resolve(''); }
  });
}

function nowSec() {
  return Math.floor(Date.now() / 1000);
}

function logPath(sid) {
  return join(CACHE_DIR, `active-context-${sid}.jsonl`);
}

// Reduce existing events to the set of subagents that started but have not yet stopped.
function runningAgents(file) {
  const running = new Map(); // id -> {ev, ts, id, name}
  if (!existsSync(file)) return running;
  let text = '';
  try { text = readFileSync(file, 'utf8'); } catch { return running; }
  for (const line of text.split('\n')) {
    const s = line.trim();
    if (!s) continue;
    let e;
    try { e = JSON.parse(s); } catch { continue; }
    if (e.ev === 'agent_start' && e.id) running.set(e.id, e);
    else if (e.ev === 'agent_stop' && e.id) running.delete(e.id);
  }
  return running;
}

async function main() {
  let d = {};
  // Strip a leading UTF-8 BOM / whitespace (PowerShell pipes prepend a BOM).
  const raw = ((await readStdin()) || '').replace(/^﻿/, '').trim();
  try { d = JSON.parse(raw || '{}'); } catch { d = {}; }

  const event = d.hook_event_name || d.hookEventName || '';
  const sid = d.session_id || d.sessionId || '';
  if (!sid) return; // nothing to key on

  try { if (!existsSync(CACHE_DIR)) mkdirSync(CACHE_DIR, { recursive: true }); } catch { return; }
  const file = logPath(sid);
  const ts = nowSec();

  if (event === 'UserPromptSubmit') {
    // New turn: quiescent point. Rewrite the file with a fresh turn marker plus any
    // subagents that are somehow still running, which also prunes unbounded growth.
    const still = [...runningAgents(file).values()];
    const lines = [JSON.stringify({ ev: 'turn', ts })];
    for (const a of still) lines.push(JSON.stringify(a));
    try { writeFileSync(file, lines.join('\n') + '\n', 'utf8'); } catch {}
    return;
  }

  if (event === 'PreToolUse') {
    const tool = d.tool_name || d.toolName || '';
    if (tool !== 'Skill') return; // matcher should already scope this, but be safe
    const ti = d.tool_input || d.toolInput || {};
    const name = ti.skill || ti.name || '';
    if (!name) return;
    try { appendFileSync(file, JSON.stringify({ ev: 'skill', ts, name }) + '\n', 'utf8'); } catch {}
    return;
  }

  if (event === 'SubagentStart') {
    const id = d.agent_id || d.agentId || d.subagent_id || '';
    const name = d.agent_type || d.agentType || d.subagent_type || d.agent_name || 'agent';
    if (!id) return;
    try { appendFileSync(file, JSON.stringify({ ev: 'agent_start', ts, id, name }) + '\n', 'utf8'); } catch {}
    return;
  }

  if (event === 'SubagentStop') {
    const id = d.agent_id || d.agentId || d.subagent_id || '';
    if (!id) return;
    try { appendFileSync(file, JSON.stringify({ ev: 'agent_stop', ts, id }) + '\n', 'utf8'); } catch {}
    return;
  }
}

main().catch(() => {}).finally(() => process.exit(0));
