import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";

// OMP adapter for ~/skills/hooks/beads-context — the same script feeds Claude
// (~/.claude/settings.json) and Codex (~/.codex/hooks.json), so all three
// harnesses get identical Beads context: project memories + ready work.
// The script prints nothing outside Beads projects and never fails.
const SCRIPT = `${process.env.HOME}/.local/bin/beads-context`;
const TIMEOUT_MS = 15_000;

async function inject(pi: HookAPI, cwd: string, reason: string): Promise<void> {
	try {
		const result = await pi.exec(SCRIPT, [], { cwd, timeout: TIMEOUT_MS });
		const text = (result.stdout ?? "").trim();
		if (result.code !== 0 || !text) return;
		pi.sendMessage(
			{ customType: "beads.context", content: `Beads context (${reason}).\n\n${text}` },
			{ deliverAs: "nextTurn" },
		);
	} catch (error) {
		pi.logger?.warn?.(`beads-context: failed: ${String(error)}`);
	}
}

export default function beadsContext(pi: HookAPI): void {
	// ctx.cwd, not pi.cwd: pi.cwd is fixed at load and goes stale after a session switch
	pi.on("session_start", async (_event, ctx) => {
		await inject(pi, ctx?.cwd ?? pi.cwd, "session start");
	});
	pi.on("session_compact", async (_event, ctx) => {
		await inject(pi, ctx?.cwd ?? pi.cwd, "after compaction");
	});
}
