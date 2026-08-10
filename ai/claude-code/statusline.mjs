#!/usr/bin/env node
// Claude Statusline v3 — two-line Nerd Font layout (Node.js port of statusline.ps1)
// Reads JSON from stdin, outputs two ANSI-coloured rows.
//
// Line 1  (identity):   folder   branch +staged ~modified   model   effort
// Line 2  (metrics):    ctx-bar %   $ cost   clock dur   5h:%  7d:%

import { readFileSync, writeFileSync, appendFileSync, existsSync, statSync } from 'node:fs';
import { join, basename, parse as parsePath } from 'node:path';
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';

// ── Config: where the event log + optional cost-cache files live ──────────────
// Generic by default (~/.claude/cache), so this bundle needs no external cost-pipeline install.
// track-active-context.mjs MUST point at the same directory.
const CacheRoot = join(homedir(), '.claude', 'cache');

function readStdin() {
  // Stream-based read, matching track-active-context.mjs's approach.
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

function coalesce(a, b) {
  return (a !== null && a !== undefined) ? a : b;
}

function num(v, fallback = 0) {
  const n = Number(coalesce(v, fallback));
  return Number.isFinite(n) ? n : fallback;
}

function str(v, fallback = '') {
  const s = coalesce(v, fallback);
  return s === null || s === undefined ? fallback : String(s);
}

async function main() {
  // Force UTF-8 stdout so block/Nerd Font chars survive the pipe.
  try { process.stdout.setDefaultEncoding('utf8'); } catch {}

  let payload = (await readStdin()) || '';
  payload = payload.replace(/^﻿/, '');

  let d = {};
  try { d = JSON.parse(payload || '{}'); } catch { d = {}; }

  // ── Parse fields ──────────────────────────────────────────────────────────
  const m = d.model;
  let model;
  if (typeof m === 'string') {
    model = m || 'Claude';
  } else if (m !== null && m !== undefined && typeof m === 'object') {
    model = m.display_name || m.id || 'Claude';
  } else {
    model = 'Claude';
  }

  const ctx_pct = Math.trunc(num(d.context_window?.used_percentage, 0));
  const ctx_used = num(d.context_window?.total_input_tokens, 0);
  const ctx_size = num(d.context_window?.context_window_size, 0);
  let cwd = d.workspace?.current_dir || d.cwd || '';
  const r5 = Math.trunc(num(d.rate_limits?.five_hour?.used_percentage, 0));
  const r7 = Math.trunc(num(d.rate_limits?.seven_day?.used_percentage, 0));
  const r5_resets = str(d.rate_limits?.five_hour?.resets_at, '');
  const r7_resets = str(d.rate_limits?.seven_day?.resets_at, '');
  const transcript = d.transcript_path || '';
  const cost_usd = num(d.cost?.total_cost_usd, 0);
  const dur_ms = num(d.cost?.total_duration_ms, 0);
  const effort = str(d.effort?.level, '');
  const thinking = Boolean(coalesce(d.thinking?.enabled, false));
  const agent_nm = str(d.agent?.name, '');
  const sid = str(d.session_id, '');

  // Per-turn token breakdown from current_usage (cache efficiency + queue logging)
  const cu = (d.context_window && d.context_window.current_usage) ? d.context_window.current_usage : {};
  const cu_in = num(cu.input_tokens, 0);
  const cu_out = num(cu.output_tokens, 0);
  const cu_cr = num(cu.cache_read_input_tokens, 0);
  const cu_cw = num(cu.cache_creation_input_tokens, 0);

  if (!cwd) cwd = process.cwd();

  // ── ANSI helpers ────────────────────────────────────────────────────────────
  const ESC = '\x1b';
  const reset = `${ESC}[0m`;
  const bold = `${ESC}[1m`;
  const dim = `${ESC}[2m`;
  const red = `${ESC}[31m`;
  const green = `${ESC}[32m`;
  const yellow = `${ESC}[33m`;
  const blue = `${ESC}[34m`;
  const white = `${ESC}[97m`;
  const magenta = `${ESC}[35m`;
  const cyan = `${ESC}[36m`;
  const grey = `${ESC}[38;5;245m`;

  // Nerd Font icons — requires a Nerd Font (e.g. JetBrains Mono Nerd Font)
  const icn_folder = String.fromCodePoint(0xF07C);   // nf-fa-folder_open
  const icn_branch = String.fromCodePoint(0xE0A0);   // nf-pl-branch
  const icn_bolt = String.fromCodePoint(0xF0E7);     // nf-fa-bolt (effort indicator)
  const icn_think = String.fromCodePoint(0xF0EB);    // nf-fa-lightbulb_o (extended thinking)
  const icn_agent = String.fromCodePoint(0xF2BE);    // nf-fa-user_circle (named agent / running subagents)
  const icn_robot = String.fromCodePoint(0xF06A9);   // nf-md-robot (above BMP; fromCodePoint handles it natively)
  const icn_skill = String.fromCodePoint(0xF013);    // nf-fa-cog (active skill)
  const icn_sep = String.fromCodePoint(0xE0B1);      // nf-pl-right_soft_divider (thin chevron)
  const icn_clock = String.fromCodePoint(0xF017);    // nf-fa-clock_o

  function getRateColor(pct) {
    if (pct >= 80) return red;
    if (pct >= 50) return yellow;
    return green;
  }

  // ── Daily and monthly totals (optional). Populated only if an external cost ──
  // pipeline writes these files into CacheRoot; absent on a plain install. ──────
  let daily_cost_usd = 0.0;
  let cache_age_min = 999;
  try {
    const dailyCacheFile = join(CacheRoot, 'anthropic-cost-today.txt');
    if (existsSync(dailyCacheFile)) {
      const fi = statSync(dailyCacheFile);
      daily_cost_usd = parseFloat(readFileSync(dailyCacheFile, 'utf8').trim());
      if (!Number.isFinite(daily_cost_usd)) daily_cost_usd = 0.0;
      cache_age_min = Math.trunc((Date.now() - fi.mtime.getTime()) / 60000);
    }
  } catch {}

  // ── 12-block 256-color cost gradient bar (green → red) against $100/mo budget ─
  const monthly_budget = 1000.0;
  let mtd_cost = 0.0;
  try {
    const qFile = join(CacheRoot, 'cost-log-queue.jsonl');
    if (existsSync(qFile)) {
      const nowMonth = new Date().toISOString().slice(0, 7); // yyyy-MM
      const lines = readFileSync(qFile, 'utf8').split('\n');
      for (const line of lines) {
        if (!line) continue;
        try {
          const e = JSON.parse(line);
          if (typeof e.ts === 'string' && e.ts.startsWith(nowMonth) && typeof e.c === 'number') {
            mtd_cost += e.c;
          }
        } catch {}
      }
    }
  } catch {}
  const bar_basis = mtd_cost > 0 ? mtd_cost : daily_cost_usd;
  const bar_pct = Math.min(100, Math.round((bar_basis / monthly_budget) * 100));
  const bar_filled = Math.min(12, Math.floor((bar_basis / monthly_budget) * 12));
  const bar_empty = 12 - bar_filled;
  const grad_colors = [46, 82, 118, 154, 190, 226, 220, 214, 208, 202, 196, 160];
  let bar = '';
  for (let i = 0; i < bar_filled; i++) {
    const c = grad_colors[i];
    bar += `${ESC}[38;5;${c}m█`;
  }
  if (bar_empty > 0) bar += `${reset}${dim}` + '░'.repeat(bar_empty);
  // % color: map bar_pct (0-100) continuously across the full gradient spectrum (green at 0%)
  const pct_grad_idx = Math.min(11, Math.floor((bar_pct / 100.0) * 12));
  const pct_c = grad_colors[pct_grad_idx];
  bar += `${reset} ${ESC}[38;5;${pct_c}m${bar_pct}%`;
  bar += reset;
  // Bar color for MTD/budget label matches the last filled gradient step
  const bar_color = bar_filled > 0 ? `${ESC}[38;5;${grad_colors[bar_filled - 1]}m` : dim;

  // ── Git branch + dirty indicators ──────────────────────────────────────────
  let git_part = '';
  if (cwd && existsSync(cwd)) {
    try {
      let branch = '';
      try {
        branch = execFileSync('git', ['-C', cwd, 'symbolic-ref', '--short', 'HEAD'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
      } catch { branch = ''; }
      if (!branch) {
        try {
          branch = execFileSync('git', ['-C', cwd, 'rev-parse', '--short', 'HEAD'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
        } catch { branch = ''; }
      }
      if (branch) {
        let porcelain = '';
        try {
          porcelain = execFileSync('git', ['-C', cwd, 'status', '--porcelain'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
        } catch { porcelain = ''; }
        const lines = porcelain ? porcelain.split('\n') : [];
        const n_staged = lines.filter((l) => /^[MADRC]/.test(l)).length;
        const n_mod = lines.filter((l) => /^ [MD]/.test(l)).length;
        let dirty = '';
        if (n_staged > 0) dirty += ` ${green}+${n_staged}${reset}`;
        if (n_mod > 0) dirty += ` ${yellow}~${n_mod}${reset}`;
        git_part = `${white}${icn_branch} ${branch}${reset}${dirty}`;
      }
    } catch {}
  }

  // ── Duration — prefer payload ms, fall back to transcript ctime ─────────────
  let dur_str = '';
  let dur_src = 0;
  if (dur_ms > 0) {
    dur_src = Math.trunc(dur_ms / 1000);
  } else if (transcript && existsSync(transcript)) {
    try {
      const bt = statSync(transcript).birthtime;
      dur_src = Math.trunc((Date.now() - bt.getTime()) / 1000);
    } catch { dur_src = 0; }
  }
  if (dur_src > 0) {
    const hrs = Math.floor(dur_src / 3600);
    const mins = Math.floor((dur_src % 3600) / 60);
    dur_str = hrs > 0 ? `${hrs}h${String(mins).padStart(2, '0')}m` : `${mins}m`;
  }

  // ── Cost ──────────────────────────────────────────────────────────────────
  const cost_str = cost_usd > 0 ? '$' + cost_usd.toFixed(2) : '';
  const daily_str = daily_cost_usd > 0 ? '$' + daily_cost_usd.toFixed(2) : '';

  // ── Folder ────────────────────────────────────────────────────────────────
  const folder = basename(cwd);

  // ── Cache efficiency (per-turn, from current_usage) ──────────────────────
  let cr_pct_str = '';
  const cu_total = cu_in + cu_cr + cu_cw;
  if (cu_total > 0) {
    const cr_rate = Math.round((cu_cr / cu_total) * 100);
    const cr_color = cr_rate >= 50 ? green : (cr_rate >= 20 ? yellow : dim);
    cr_pct_str = `${cr_color}CR:${cr_rate}%${reset}`;
  }

  // ── Write rate-cache.json ───────────────────────────────────────────────────
  const cacheDir = join(homedir(), '.claude');
  if (existsSync(cacheDir)) {
    try {
      const ts = Math.floor(Date.now() / 1000);
      const rateCache = {
        r5,
        r7,
        r5_resets_at: r5_resets,
        r7_resets_at: r7_resets,
        context_pct: ctx_pct,
        cost_usd,
        model,
        cwd,
        ts,
      };
      writeFileSync(join(cacheDir, 'rate-cache.json'), JSON.stringify(rateCache), 'utf8');
    } catch {}
  }

  // ── Queue per-turn usage (optional). Harmless if nothing drains it; consumed ──
  // by an external cost pipeline when present. ────────────────────────────────
  if (cu_in > 0 || cu_out > 0) {
    try {
      const sess_id = transcript ? parsePath(transcript).name : 'unknown';
      const turn_cost = Math.round(((cu_in * 3.0 + cu_out * 15.0 + cu_cw * 3.75 + cu_cr * 0.03) / 1000000) * 1e6) / 1e6;
      const qEntry = JSON.stringify({
        ts: new Date().toISOString(),
        sid: sess_id,
        mdl: model,
        i: Math.trunc(cu_in),
        o: Math.trunc(cu_out),
        cr: Math.trunc(cu_cr),
        cw: Math.trunc(cu_cw),
        c: turn_cost,
      });
      const qFile = join(CacheRoot, 'cost-log-queue.jsonl');
      appendFileSync(qFile, qEntry + '\n', 'utf8');
    } catch {}
  }

  // ── Active skill + running subagents (from track-active-context.mjs event log) ──
  let active_skill = '';
  let active_agents = [];
  if (sid) {
    try {
      const ctxFile = join(CacheRoot, `active-context-${sid}.jsonl`);
      if (existsSync(ctxFile)) {
        let turn_ts = 0;
        let skill_ts = 0;
        const running = new Map(); // id -> { name, ts }
        const now_ts = Math.floor(Date.now() / 1000);
        const text = readFileSync(ctxFile, 'utf8');
        for (const rawLine of text.split('\n')) {
          const line = rawLine.trim();
          if (!line) continue;
          let e;
          try { e = JSON.parse(line); } catch { continue; }
          switch (e.ev) {
            case 'turn':
              turn_ts = Math.trunc(Number(e.ts) || 0);
              break;
            case 'skill':
              active_skill = String(e.name || '');
              skill_ts = Math.trunc(Number(e.ts) || 0);
              break;
            case 'agent_start':
              if (e.id) running.set(String(e.id), { name: String(e.name || ''), ts: Math.trunc(Number(e.ts) || 0) });
              break;
            case 'agent_stop':
              if (e.id && running.has(String(e.id))) running.delete(String(e.id));
              break;
          }
        }
        // Current-turn semantics: drop the skill if it predates the latest turn marker
        if (skill_ts < turn_ts) active_skill = '';
        // Running agents, newest first. Two guards:
        //   1. Current-turn reconcile: a real subagent starts DURING the assistant
        //      turn, so its agent_start ts is >= the latest turn marker. An agent_start
        //      older than that marker never got a matching agent_stop (rejected/failed
        //      launch) -> treat as gone. Mirrors the skill reconcile above.
        //   2. 30-min orphan TTL as a backstop when no turn marker exists yet.
        active_agents = [...running.entries()]
          .filter(([, v]) => v.ts >= turn_ts && (now_ts - v.ts) < 1800)
          .sort((a, b) => b[1].ts - a[1].ts)
          .map(([, v]) => v.name);
      }
    } catch { active_skill = ''; active_agents = []; }
  }

  // ── Context window string ─────────────────────────────────────────────────
  let ctx_str = '';
  if (ctx_size > 0) {
    const used_k = ctx_used >= 1000 ? (ctx_used / 1000).toFixed(1) + 'k' : String(ctx_used);
    const size_k = ctx_size >= 1000 ? Math.round(ctx_size / 1000) + 'k' : String(ctx_size);
    const ctx_color = ctx_pct >= 80 ? red : (ctx_pct >= 50 ? yellow : green);
    ctx_str = `${dim}ctx:${reset} ${used_k}/${size_k} ${ctx_color}${ctx_pct}%${reset}`;
  } else if (ctx_pct > 0) {
    const ctx_color = ctx_pct >= 80 ? red : (ctx_pct >= 50 ? yellow : green);
    ctx_str = `${dim}ctx:${reset} ${ctx_color}${ctx_pct}%${reset}`;
  }

  // ── Thin separator ──────────────────────────────────────────────────────────
  const sep = ` ${dim}${icn_sep}${reset} `;

  // ── Line 1: identity ─────────────────────────────────────────────────────────
  let l1 = `${bold}${cyan}${icn_folder} ${folder}${reset}`;
  if (git_part) l1 += `${sep}${git_part}`;
  l1 += `${sep}${magenta}${model}${reset}`;
  if (agent_nm) l1 += ` ${dim}${icn_agent} ${agent_nm}${reset}`;
  if (active_skill) l1 += ` ${dim}${icn_skill}${reset} ${cyan}/${active_skill}${reset}`;
  if (effort) {
    let effort_color;
    switch (effort) {
      case 'xhigh': effort_color = red; break;
      case 'high': effort_color = red; break;
      case 'medium': effort_color = yellow; break;
      default: effort_color = dim;
    }
    l1 += ` ${yellow}${icn_bolt}${reset} ${effort_color}${effort}${reset}`;
  }
  if (thinking) l1 += ` ${yellow}${icn_think}${reset}`;
  if (cr_pct_str) l1 += `${sep}${cr_pct_str}`;

  // ── Line 2: metrics ───────────────────────────────────────────────────────────
  let l2 = bar;
  if (ctx_str) l2 += `${sep}${ctx_str}`;
  if (cost_str || daily_str) {
    const sess_part = cost_str ? `${yellow}${cost_str} ses.${reset}` : `${dim}-- ses.${reset}`;
    l2 += `${sep}${sess_part}`;
    if (daily_str) {
      const stale_pfx = cache_age_min > 30 ? `${red}~${reset}` : (cache_age_min > 18 ? `${dim}~${reset}` : '');
      l2 += ` ${dim}/${reset} ${stale_pfx}${yellow}${daily_str} day${reset}`;
    }
  }
  if (bar_basis > 0) {
    const mtd_label = '$' + bar_basis.toFixed(2);
    const budget_label = '$' + monthly_budget.toFixed(0);
    l2 += `${sep}${bar_color}${mtd_label} total${reset}${dim} / ${budget_label}/mo.${reset}`;
  }
  if (dur_str) l2 += `${sep}${blue}${icn_clock} ${dur_str}${reset}`;
  const c5 = getRateColor(r5);
  const c7 = getRateColor(r7);
  if (r5 > 0) l2 += `${sep}${c5}5h:${r5}%${reset}`;
  if (r7 > 0) l2 += `${sep}${c7}7d:${r7}%${reset}`;

  // ── Active subagent — appended to the metrics line as a "double section" ──────
  if (active_agents.length > 0) {
    const show = active_agents.length > 3 ? active_agents.slice(0, 3) : active_agents;
    let names = show.join(', ');
    if (active_agents.length > 3) names += ` +${active_agents.length - 3}`;
    const label = active_agents.length > 1 ? 'Agents' : 'Agent';
    l2 += `${sep}${white}${icn_robot} ${label}:${reset} ${grey}${names}${reset}`;
  }

  process.stdout.write(l1 + '\n');
  process.stdout.write(l2 + '\n');
}

main().catch(() => {}).finally(() => process.exit(0));
