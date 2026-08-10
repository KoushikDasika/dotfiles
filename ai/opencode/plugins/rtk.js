// rtk.js — opencode plugin that rewrites bash commands through RTK (Rust Token Killer)
// Mirrors the Claude Code PreToolUse hook that runs: rtk hook claude
// Saves 60-90% on token output for dev operations (git, mix, etc.)

export const RtkPlugin = async (_pluginInput) => ({
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "bash") return;

    const cmd = (output.args?.command || "").trimStart();

    // Skip: already rtk-prefixed
    if (cmd.startsWith("rtk ") || cmd === "rtk") return;

    // Skip: interactive shell prefix (!)
    if (cmd.startsWith("!")) return;

    // Skip: empty
    if (!cmd) return;

    // Skip: rtk meta commands called directly
    if (/^rtk\b/.test(cmd)) return;

    // Skip: commands that don't benefit from filtering
    // (cd changes, env-only lines, pure variable assignments)
    if (/^(cd|export|source|\.)\s/.test(cmd)) return;
    if (/^[A-Z_]+=/.test(cmd) && !/&&|\|/.test(cmd)) return;

    output.args = { ...output.args, command: "rtk " + cmd };
  },
});

export default RtkPlugin;
