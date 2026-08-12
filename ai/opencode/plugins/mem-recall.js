// mem-recall.js — opencode plugin: inject MemPalace + beads context
// at session start (first user message) and into every compaction summary.
//
// Sources:
//   mempalace wake-up   — L0+L1 palace context (~600-900 tokens)
//   bd ready            — claimable beads issues (no active blockers)
//   bd list --status in_progress — work already claimed
//
// All commands are advisory: missing CLI, timeout, or non-zero exit → skipped.

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const CMD_TIMEOUT_MS = 10000;
const MAX_SECTION_CHARS = 4000;

function run(cmd, args, cwd) {
  return new Promise((resolve) => {
    let proc;
    try {
      proc = spawn(cmd, args, { cwd, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
    } catch {
      resolve("");
      return;
    }
    let stdout = "";
    proc.stdout.on("data", (d) => { stdout += d.toString(); });
    const timer = setTimeout(() => { proc.kill("SIGTERM"); resolve(""); }, CMD_TIMEOUT_MS);
    proc.on("close", (code) => {
      clearTimeout(timer);
      resolve(code === 0 ? stdout.trim() : "");
    });
    proc.on("error", () => { clearTimeout(timer); resolve(""); });
  });
}

function clip(text) {
  return text.length > MAX_SECTION_CHARS
    ? text.slice(0, MAX_SECTION_CHARS) + "\n[...truncated]"
    : text;
}

async function gather(projectDir) {
  const [wakeup, ready, inProgress] = await Promise.all([
    run("mempalace", ["wake-up"], projectDir),
    run("bd", ["ready"], projectDir),
    run("bd", ["list", "--status", "in_progress"], projectDir),
  ]);

  const sections = [];
  if (wakeup) sections.push("## MemPalace wake-up\n" + clip(wakeup));
  if (ready) sections.push("## Beads: ready work\n" + clip(ready));
  if (inProgress) sections.push("## Beads: in progress\n" + clip(inProgress));
  if (!sections.length) return "";

  return (
    "<memory-recall>\n" +
    "Recalled context from MemPalace and beads (advisory, may be stale):\n\n" +
    sections.join("\n\n") +
    "\n</memory-recall>"
  );
}

export const MemRecallPlugin = async (pluginInput) => {
  const getDir = () => pluginInput.directory || process.cwd();
  // sessions already injected this process; cleared when that session compacts
  const injected = new Set();

  return {
    // session start: prepend recall to the first user message of each session
    "chat.message": async (_input, output) => {
      const sessionID =
        output?.message?.sessionID || output?.message?.session_id || "global";
      if (injected.has(sessionID)) return;
      injected.add(sessionID);

      const ctx = await gather(getDir());
      if (!ctx || !Array.isArray(output?.parts)) return;
      output.parts.push({ type: "text", text: ctx, synthetic: true });
    },

    // compaction: feed recall into the summary so it survives the squeeze
    "experimental.session.compacting": async (_input, output) => {
      const ctx = await gather(getDir());
      if (!ctx) return;
      output.context = output.context || [];
      output.context.push(ctx);
    },

    // after compaction completes, re-arm session-start injection so the next
    // user message also gets fresh recall
    event: async ({ event }) => {
      if (event.type === "session.compacted") {
        const sessionID = event.properties?.sessionID || event.properties?.session_id;
        if (sessionID) injected.delete(sessionID);
        else injected.clear();
      }
    },
  };
};

export default MemRecallPlugin;
