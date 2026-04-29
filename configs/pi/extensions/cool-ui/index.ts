import type {
    ExtensionAPI,
    ExtensionContext,
    Theme,
    WorkingIndicatorOptions,
} from "@mariozechner/pi-coding-agent";
import { VERSION } from "@mariozechner/pi-coding-agent";
import { truncateToWidth } from "@mariozechner/pi-tui";

function modelLabel(ctx: ExtensionContext): string {
    return ctx.model
        ? `${ctx.model.provider}/${ctx.model.id}`
        : "model pending";
}

function graphiteIndicator(ctx: ExtensionContext): WorkingIndicatorOptions {
    const theme = ctx.ui.theme;
    return {
        frames: [
            theme.fg("dim", "·"),
            theme.fg("muted", "·"),
            theme.fg("accent", "○"),
            theme.fg("muted", "·"),
        ],
        intervalMs: 180,
    };
}

function headerLine(
    theme: Theme,
    cwd: string,
    mode: string,
    model: string,
): string {
    const project = cwd.split("/").filter(Boolean).at(-1) ?? cwd;
    const mark = theme.fg("accent", "π");
    const sep = theme.fg("dim", " · ");
    return [
        mark,
        theme.fg("text", project),
        theme.fg("muted", mode),
        theme.fg("dim", model),
        theme.fg("dim", `v${VERSION}`),
    ].join(sep);
}

function applyGraphite(
    ctx: ExtensionContext,
    state: string,
    turnCount: number,
): void {
    if (!ctx.hasUI) return;

    const model = modelLabel(ctx);
    const mode = state.includes("plan")
        ? "plan"
        : state.includes("build")
          ? "build"
          : "work";
    const theme = ctx.ui.theme;

    ctx.ui.setWorkingIndicator(graphiteIndicator(ctx));
    ctx.ui.setWorkingMessage(`${theme.fg("muted", "thinking")}`);
    ctx.ui.setStatus(
        "graphite-ui",
        [
            theme.fg("accent", "pi"),
            theme.fg("dim", state),
            turnCount > 0 ? theme.fg("dim", `turn ${turnCount}`) : undefined,
        ]
            .filter(Boolean)
            .join(theme.fg("dim", " · ")),
    );

    ctx.ui.setHeader((_tui, headerTheme) => ({
        render(width: number): string[] {
            return [
                truncateToWidth(
                    headerLine(headerTheme, ctx.cwd, mode, model),
                    width,
                    "",
                ),
            ];
        },
        invalidate() {},
    }));
}

export default function (pi: ExtensionAPI) {
    let enabled = true;
    let turnCount = 0;
    let lastState = "idle";

    pi.on("session_start", async (_event, ctx) => {
        enabled = true;
        lastState = "idle";
        applyGraphite(ctx, lastState, turnCount);
    });

    pi.on("model_select", async (_event, ctx) => {
        if (enabled) applyGraphite(ctx, lastState, turnCount);
    });

    pi.on("turn_start", async (_event, ctx) => {
        turnCount++;
        lastState = "thinking";
        if (enabled) applyGraphite(ctx, lastState, turnCount);
    });

    pi.on("tool_execution_start", async (event, ctx) => {
        lastState = `tool ${event.toolName}`;
        if (enabled) applyGraphite(ctx, lastState, turnCount);
    });

    pi.on("turn_end", async (_event, ctx) => {
        lastState = "idle";
        if (enabled) applyGraphite(ctx, lastState, turnCount);
    });

    pi.registerCommand("graphite-ui", {
        description:
            "Use the understated Graphite Pi header, spinner, and status line.",
        handler: async (_args, ctx) => {
            enabled = true;
            applyGraphite(ctx, lastState, turnCount);
            ctx.ui.notify("Graphite UI enabled", "info");
        },
    });

    pi.registerCommand("plain-ui", {
        description:
            "Restore Pi's built-in header, spinner, working text, and footer status.",
        handler: async (_args, ctx) => {
            enabled = false;
            ctx.ui.setHeader(undefined);
            ctx.ui.setWorkingIndicator();
            ctx.ui.setWorkingMessage();
            ctx.ui.setStatus("graphite-ui", undefined);
            ctx.ui.notify("Plain UI restored", "info");
        },
    });

    pi.registerCommand("cool-ui", {
        description: "Alias for /graphite-ui.",
        handler: async (_args, ctx) => {
            enabled = true;
            applyGraphite(ctx, lastState, turnCount);
            ctx.ui.notify("Graphite UI enabled", "info");
        },
    });

    pi.registerCommand("boring-ui", {
        description: "Alias for /plain-ui.",
        handler: async (_args, ctx) => {
            enabled = false;
            ctx.ui.setHeader(undefined);
            ctx.ui.setWorkingIndicator();
            ctx.ui.setWorkingMessage();
            ctx.ui.setStatus("graphite-ui", undefined);
            ctx.ui.notify("Plain UI restored", "info");
        },
    });
}
