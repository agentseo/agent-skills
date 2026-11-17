import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";

// OMP adapter for two shared hook scripts in ~/skills/hooks (Claude uses the same scripts
// from ~/.claude/settings.json):
//   validate-edit  after an edit/write tool: syntax check of touched .json/.py/.php/.yml files;
//                  a broken file is reported to the agent on its next turn.
//   commit-stamp   before a bash `git commit`: logs whether the message carries `Verified:`;
//                  in COMMIT_STAMP_MODE=enforce it blocks (exit 1) — two blocks per session max.
// Tool argument names differ between harness versions, so paths are taken from any string
// argument that looks like a file path; non-matching strings are ignored by the script.
const BIN = `${process.env.HOME}/.local/bin`;
const TIMEOUT_MS = 10_000;
const EDIT_TOOLS = new Set(["edit", "write", "multiedit", "multi_edit", "patch"]);
const PATH_RE = /\.(json|py|php|module|inc|install|theme|ya?ml)$/i;

function candidatePaths(args: unknown): string[] {
	const out = new Set<string>();
	const walk = (v: unknown, depth: number) => {
		if (depth > 3 || v == null) return;
		if (typeof v === "string") {
			if (v.length < 1024 && !v.includes("\n") && PATH_RE.test(v)) out.add(v);
		} else if (Array.isArray(v)) v.forEach((x) => walk(x, depth + 1));
		else if (typeof v === "object") Object.values(v as Record<string, unknown>).forEach((x) => walk(x, depth + 1));
	};
	walk(args, 0);
	return [...out];
}

export default function verifyHooks(pi: HookAPI): void {
	pi.on("tool_execution_end", async (event, ctx) => {
		const name = String(event?.toolName ?? "").toLowerCase();
		if (!EDIT_TOOLS.has(name)) return;
		const paths = candidatePaths(event?.args);
		if (paths.length === 0) return;
		try {
			const r = await pi.exec(`${BIN}/validate-edit`, paths, { cwd: ctx?.cwd ?? pi.cwd, timeout: TIMEOUT_MS });
			const text = `${r.stdout ?? ""}${r.stderr ?? ""}`.trim();
			if (r.code === 0 || !text) return;
			pi.sendMessage({ customType: "verify.validate-edit", content: text }, { deliverAs: "nextTurn" });
		} catch (error) {
			pi.logger?.warn?.(`validate-edit: failed: ${String(error)}`);
		}
	});

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		const command = String((event.input as Record<string, unknown>)?.command ?? "");
		if (!/\bgit\b[\s\S]*\bcommit\b/.test(command)) return;
		try {
			const r = await pi.exec(`${BIN}/commit-stamp`, ["--cmd", command], { cwd: ctx?.cwd ?? pi.cwd, timeout: TIMEOUT_MS });
			if (r.code === 1) return { block: true, reason: (r.stderr ?? "").trim() || "commit without Verified:" };
		} catch (error) {
			pi.logger?.warn?.(`commit-stamp: failed: ${String(error)}`);
		}
	});
}
