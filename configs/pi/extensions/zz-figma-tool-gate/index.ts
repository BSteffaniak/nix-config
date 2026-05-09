import type {
    ExtensionAPI,
    ExtensionContext,
} from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "figma-tool-gate";
const FIGMA_MCP_STATUS_KEY = "figma-mcp";
const FIGMA_TOOL_PREFIX = "figma_";
const STARTUP_GATE_INTERVAL_MS = 250;
const STARTUP_GATE_MAX_TICKS = 20;

function isFigmaToolName(name: string): boolean {
    return name.startsWith(FIGMA_TOOL_PREFIX);
}

function isFigmaHintMessage(message: unknown): boolean {
    const maybeMessage = message as
        | { customType?: unknown; content?: unknown }
        | undefined;

    return (
        maybeMessage?.customType === "figma-mcp-hint" ||
        (typeof maybeMessage?.content === "string" &&
            maybeMessage.content.includes("Figma desktop MCP is available"))
    );
}

export default function figmaToolGate(pi: ExtensionAPI) {
    let enabled = false;
    let startupGateTimer: ReturnType<typeof setInterval> | undefined;

    function figmaToolNames(): string[] {
        return pi
            .getAllTools()
            .map((tool) => tool.name)
            .filter(isFigmaToolName);
    }

    function setFigmaToolsActive(active: boolean): void {
        const nextActiveTools = new Set(pi.getActiveTools());

        for (const toolName of figmaToolNames()) {
            if (active) {
                nextActiveTools.add(toolName);
            } else {
                nextActiveTools.delete(toolName);
            }
        }

        pi.setActiveTools([...nextActiveTools]);
    }

    function updateStatus(ctx?: ExtensionContext): void {
        ctx?.ui.setStatus(FIGMA_MCP_STATUS_KEY, "");
        ctx?.ui.setStatus(STATUS_KEY, enabled ? "figma" : "");
    }

    function enforceGate(ctx?: ExtensionContext): void {
        setFigmaToolsActive(enabled);
        updateStatus(ctx);
    }

    function stopStartupGate(): void {
        if (!startupGateTimer) return;
        clearInterval(startupGateTimer);
        startupGateTimer = undefined;
    }

    function startStartupGate(ctx: ExtensionContext): void {
        stopStartupGate();

        let ticks = 0;
        startupGateTimer = setInterval(() => {
            ticks += 1;
            enforceGate(ctx);

            if (ticks >= STARTUP_GATE_MAX_TICKS) {
                stopStartupGate();
            }
        }, STARTUP_GATE_INTERVAL_MS);
    }

    function enableFigma(ctx: ExtensionContext): void {
        enabled = true;
        enforceGate(ctx);
        ctx.ui.notify(
            `Figma tools enabled (${figmaToolNames().length} discovered). Use /figma-off when done.`,
            "info",
        );
    }

    function disableFigma(ctx?: ExtensionContext): void {
        enabled = false;
        enforceGate(ctx);
        ctx?.ui.notify("Figma tools disabled", "info");
    }

    pi.on("session_start", async (_event, ctx) => {
        enabled = false;
        enforceGate(ctx);
        startStartupGate(ctx);
    });

    pi.on("input", async (_event, ctx) => {
        enforceGate(ctx);
    });

    pi.on("before_agent_start", async (event, ctx) => {
        enforceGate(ctx);

        if (enabled) return;

        return {
            systemPrompt: `${event.systemPrompt}\n\n## Figma Tool Gate\n\nFigma MCP tools are disabled by default. Do not use, plan around, or mention Figma tools unless the user explicitly runs /figma-on first. For non-Figma tasks, ignore any ambient Figma availability hints.`,
        };
    });

    pi.on("context", async (event) => {
        if (enabled) return;

        return {
            messages: event.messages.filter(
                (message) => !isFigmaHintMessage(message),
            ),
        };
    });

    pi.on("tool_call", async (event) => {
        if (!isFigmaToolName(event.toolName) || enabled) return;

        return {
            block: true,
            reason: "Figma tools are disabled. Ask the user to run /figma-on if this task really needs Figma MCP access.",
        };
    });

    pi.registerCommand("figma-on", {
        description: "Enable Figma MCP tools for this session",
        handler: async (_args, ctx) => {
            enableFigma(ctx);
        },
    });

    pi.registerCommand("figma-off", {
        description: "Disable Figma MCP tools",
        handler: async (_args, ctx) => {
            disableFigma(ctx);
        },
    });

    pi.registerCommand("figma-status", {
        description: "Show whether Figma MCP tools are enabled",
        handler: async (_args, ctx) => {
            const discovered = figmaToolNames();
            ctx.ui.notify(
                `Figma tools are ${enabled ? "enabled" : "disabled"}. ${discovered.length} discovered: ${discovered.join(", ") || "none"}`,
                enabled ? "info" : "warning",
            );
        },
    });

    pi.on("session_shutdown", async () => {
        stopStartupGate();
    });
}
