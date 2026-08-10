// phx-hooks.js — opencode plugin shim for oliver-kriska/elixir-phoenix hooks + credo
// Maps 21 Claude hook entries from hooks.json to opencode plugin API.
// Also fires "just lint" (credo) after Elixir file edits when justfile exists.

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { join, extname } from "node:path";
import os from "node:os";

const PHX_PLUGIN_ROOT =
  os.homedir() +
  "/.claude/plugins/cache/oliver-kriska/elixir-phoenix/3.0.0";
const SCRIPTS = PHX_PLUGIN_ROOT + "/hooks/scripts";

const ELIXIR_EXTS = new Set([".ex", ".exs", ".heex", ".eex", ".leex"]);

function isElixirFile(filePath) {
  return ELIXIR_EXTS.has(extname(filePath));
}

// Run a phx hook script, reconstructing the stdin contract it expects.
// Returns { exitCode, stdout, stderr }.
function runScript(scriptPath, opts = {}) {
  const { filePath, command, projectDir, timeoutMs = 30000 } = opts;
  return new Promise((resolve) => {
    const toolInput = {};
    if (filePath) toolInput.file_path = filePath;
    if (command) toolInput.command = command;
    const stdinData = JSON.stringify({ tool_input: toolInput });

    const env = {
      ...process.env,
      CLAUDE_PLUGIN_ROOT: PHX_PLUGIN_ROOT,
      CLAUDE_PROJECT_DIR: projectDir || process.cwd(),
    };

    const proc = spawn("bash", [scriptPath], {
      env,
      stdio: ["pipe", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (d) => { stdout += d.toString(); });
    proc.stderr.on("data", (d) => { stderr += d.toString(); });
    proc.stdin.write(stdinData);
    proc.stdin.end();

    const timer = setTimeout(() => {
      proc.kill("SIGTERM");
      resolve({ exitCode: -1, stdout, stderr: stderr + "\n[timeout]" });
    }, timeoutMs);

    proc.on("close", (code) => {
      clearTimeout(timer);
      resolve({ exitCode: code ?? 0, stdout, stderr });
    });
    proc.on("error", (err) => {
      clearTimeout(timer);
      resolve({ exitCode: -1, stdout, stderr: err.message });
    });
  });
}

// Run "just lint" when justfile exists in project root.
function runCredoLint(projectDir) {
  return new Promise((resolve) => {
    if (!existsSync(join(projectDir, "justfile"))) {
      resolve({ exitCode: 0, stdout: "", stderr: "" });
      return;
    }
    const proc = spawn("just", ["lint"], {
      cwd: projectDir,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (d) => { stdout += d.toString(); });
    proc.stderr.on("data", (d) => { stderr += d.toString(); });
    const timer = setTimeout(() => { proc.kill(); resolve({ exitCode: -1, stdout, stderr }); }, 120000);
    proc.on("close", (code) => { clearTimeout(timer); resolve({ exitCode: code ?? 0, stdout, stderr }); });
    proc.on("error", (err) => { clearTimeout(timer); resolve({ exitCode: -1, stdout: "", stderr: err.message }); });
  });
}

let sessionInitDone = false;

export const PhxHooksPlugin = async (pluginInput) => {
  const getDir = () => pluginInput.directory || process.cwd();

  return {
    // PostToolUse Edit/Write on Elixir files + SessionStart (first event)
    event: async ({ event }) => {
      // SessionStart: run setup scripts once
      if (!sessionInitDone && event.type === "session.created") {
        sessionInitDone = true;
        runScript(SCRIPTS + "/setup-dirs.sh", { projectDir: getDir() }).catch(() => {});
        runScript(SCRIPTS + "/detect-tidewave.sh", { projectDir: getDir(), timeoutMs: 30000 }).catch(() => {});
        runScript(SCRIPTS + "/detect-ash.sh", { projectDir: getDir(), timeoutMs: 3000 }).catch(() => {});
      }

      if (event.type !== "file.edited") return;

      const filePath = event.properties?.file || "";
      if (!filePath) return;

      const projectDir = getDir();

      if (isElixirFile(filePath)) {
        // format-elixir.sh
        runScript(SCRIPTS + "/format-elixir.sh", { filePath, projectDir, timeoutMs: 30000 }).catch(() => {});

        // iron-law-verifier.sh (advisory)
        runScript(SCRIPTS + "/iron-law-verifier.sh", { filePath, projectDir, timeoutMs: 15000 }).catch(() => {});

        // debug-statement-warning.sh (only .ex files, not .exs)
        if (extname(filePath) === ".ex") {
          runScript(SCRIPTS + "/debug-statement-warning.sh", { filePath, projectDir, timeoutMs: 15000 }).catch(() => {});
        }

        // credo: just lint when justfile exists
        runCredoLint(projectDir).catch(() => {});
      }

      // security-reminder.sh for any Elixir/template file
      if (ELIXIR_EXTS.has(extname(filePath))) {
        runScript(SCRIPTS + "/security-reminder.sh", { filePath, projectDir, timeoutMs: 15000 }).catch(() => {});
      }
    },

    "tool.execute.before": async (input, output) => {
      const { tool } = input;
      const projectDir = getDir();

      // PreToolUse Edit/Write: freeze-gate (blocking)
      if (tool === "edit" || tool === "write") {
        const filePath = output.args?.file_path || output.args?.path || "";
        const result = await runScript(SCRIPTS + "/freeze-gate.sh", {
          filePath,
          projectDir,
          timeoutMs: 5000,
        });
        if (result.exitCode !== 0) {
          throw new Error(
            "Freeze gate: edits blocked. " + (result.stderr || result.stdout).trim()
          );
        }
      }

      // PreToolUse Bash: dangerous ops (advisory) + deps audit (blocking)
      if (tool === "bash") {
        const command = output.args?.command || "";

        // block-dangerous-ops (advisory — match Claude's || exit 0 semantics)
        runScript(SCRIPTS + "/block-dangerous-ops.sh", {
          command,
          projectDir,
          timeoutMs: 10000,
        })
          .then((r) => {
            if (r.exitCode !== 0 && (r.stderr || r.stdout).trim()) {
              console.error(
                "[phx-hooks] dangerous-ops warning: " +
                  (r.stderr || r.stdout).trim()
              );
            }
          })
          .catch(() => {});

        // deps-audit-gate (blocking on mix deps.*)
        if (/mix deps/.test(command)) {
          const result = await runScript(SCRIPTS + "/deps-audit-gate.sh", {
            command,
            projectDir,
            timeoutMs: 5000,
          });
          if (result.exitCode !== 0) {
            throw new Error(
              "Deps audit gate: " + (result.stderr || result.stdout).trim()
            );
          }
        }
      }
    },

    "tool.execute.after": async (input, output) => {
      const { tool, args } = input;
      if (tool !== "bash") return;

      const command = args?.command || "";
      const exitCode = output.metadata?.exitCode ?? 0;

      // PostToolUseFailure Bash on mix commands: elixir-failure-hints + error-critic (advisory)
      if (exitCode !== 0 && /mix/.test(command)) {
        const projectDir = getDir();
        runScript(SCRIPTS + "/elixir-failure-hints.sh", {
          command,
          projectDir,
          timeoutMs: 15000,
        })
          .then((r) => {
            if ((r.stdout || r.stderr).trim()) {
              output.output = (output.output || "") + "\n" + (r.stdout || r.stderr).trim();
            }
          })
          .catch(() => {});

        runScript(SCRIPTS + "/error-critic.sh", {
          command,
          projectDir,
          timeoutMs: 15000,
        })
          .then((r) => {
            if ((r.stdout || r.stderr).trim()) {
              output.output = (output.output || "") + "\n" + (r.stdout || r.stderr).trim();
            }
          })
          .catch(() => {});
      }
    },

    // UserPromptSubmit equivalent: route-intent (advisory)
    "chat.message": async (_input, _output) => {
      const projectDir = getDir();
      runScript(SCRIPTS + "/route-intent.sh", {
        projectDir,
        timeoutMs: 10000,
      }).catch(() => {});
    },

    // PreCompact / PostCompact
    "experimental.session.compacting": async (_input, output) => {
      const projectDir = getDir();
      const pre = await runScript(SCRIPTS + "/precompact-rules.sh", {
        projectDir,
        timeoutMs: 15000,
      }).catch(() => ({ stdout: "", stderr: "" }));

      if ((pre.stdout || pre.stderr).trim()) {
        output.context = output.context || [];
        output.context.push((pre.stdout || pre.stderr).trim());
      }

      // postcompact-verify runs after — fire async
      runScript(SCRIPTS + "/postcompact-verify.sh", {
        projectDir,
        timeoutMs: 15000,
      }).catch(() => {});
    },
  };
};

export default PhxHooksPlugin;
