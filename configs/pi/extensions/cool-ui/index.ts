import type {
    ExtensionAPI,
    ExtensionContext,
    Theme,
    WorkingIndicatorOptions,
} from "@mariozechner/pi-coding-agent";
import { CustomEditor, VERSION } from "@mariozechner/pi-coding-agent";
import { truncateToWidth } from "@mariozechner/pi-tui";

const RESET_FG = "\x1b[39m";
const NEON_FRAMES = ["◐", "◓", "◑", "◒"];
const NEON_COLORS = [
    "\x1b[38;2;0;229;255m",
    "\x1b[38;2;168;85;255m",
    "\x1b[38;2;255;61;242m",
    "\x1b[38;2;57;255;136m",
];

function rgb(text: string, color: string): string {
    return `${color}${text}${RESET_FG}`;
}

function neonIndicator(): WorkingIndicatorOptions {
    return {
        frames: NEON_FRAMES.map((frame, index) =>
            rgb(frame, NEON_COLORS[index % NEON_COLORS.length]!),
        ),
        intervalMs: 90,
    };
}

function headerLines(theme: Theme): string[] {
    const c = (text: string) => theme.fg("accent", text);
    const p = (text: string) => theme.fg("customMessageLabel", text);
    const d = (text: string) => theme.fg("dim", text);
    const m = (text: string) => theme.fg("muted", text);
    const g = (text: string) => theme.fg("success", text);

    return [
        "",
        `${p("╭")} ${c("π")}${p(" // ")}${theme.bold(c("NEON AGENT"))} ${p("━━━━━━━━━━━━━━━━━━━━╮")}`,
        `${p("│")} ${d("wired for velocity")} ${p("·")} ${g("plan/build aware")} ${p("·")} ${m(`v${VERSION}`)} ${p("│")}`,
        `${p("╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯")}`,
    ];
}

function applyChrome(ctx: ExtensionContext, status = "ready"): void {
    if (!ctx.hasUI) return;

    const theme = ctx.ui.theme;
    ctx.ui.setWorkingIndicator(neonIndicator());
    ctx.ui.setWorkingMessage(
        `${theme.fg("accent", "π")} ${theme.fg("muted", "bending spacetime...")}`,
    );
    ctx.ui.setStatus(
        "cool-ui",
        `${theme.fg("accent", "π neon")} ${theme.fg("dim", "|")} ${theme.fg("muted", status)}`,
    );
    ctx.ui.setHeader((_tui, headerTheme) => ({
        render(width: number): string[] {
            return headerLines(headerTheme).map((line) =>
                truncateToWidth(line, width, ""),
            );
        },
        invalidate() {},
    }));
}

const SHINE_COLORS = [
    [0, 229, 255],
    [77, 163, 255],
    [168, 85, 255],
    [255, 61, 242],
    [57, 255, 136],
] as const;

function shine(text: string, frame: number): string {
    return (
        [...text]
            .map((char, index) => {
                const [r, g, b] =
                    SHINE_COLORS[(index + frame) % SHINE_COLORS.length]!;
                return `\x1b[38;2;${r};${g};${b}m${char}`;
            })
            .join("") + "\x1b[0m"
    );
}

class NeonEditor extends CustomEditor {
    private frame = 0;
    private timer?: ReturnType<typeof setInterval>;

    private hasNeonText(): boolean {
        return /\b(ultrathink|xhigh|neon|ship it)\b/i.test(this.getText());
    }

    private start(): void {
        if (this.timer) return;
        this.timer = setInterval(() => {
            this.frame++;
            this.tui.requestRender();
        }, 80);
    }

    private stop(): void {
        if (!this.timer) return;
        clearInterval(this.timer);
        this.timer = undefined;
    }

    handleInput(data: string): void {
        super.handleInput(data);
        if (this.hasNeonText()) this.start();
        else this.stop();
    }

    render(width: number): string[] {
        return super
            .render(width)
            .map((line) =>
                line.replace(/\b(ultrathink|xhigh|neon|ship it)\b/gi, (match) =>
                    shine(match, this.frame),
                ),
            );
    }
}

export default function (pi: ExtensionAPI) {
    let turnCount = 0;
    let currentModel = "model pending";
    let enabled = true;

    function applyEditor(ctx: ExtensionContext): void {
        if (!ctx.hasUI) return;
        ctx.ui.setEditorComponent(
            (tui, theme, keybindings) =>
                new NeonEditor(tui, theme, keybindings),
        );
    }

    pi.on("session_start", async (_event, ctx) => {
        enabled = true;
        currentModel = ctx.model
            ? `${ctx.model.provider}/${ctx.model.id}`
            : currentModel;
        applyChrome(ctx, `${currentModel} · ready`);
        applyEditor(ctx);
    });

    pi.on("model_select", async (event, ctx) => {
        currentModel = `${event.model.provider}/${event.model.id}`;
        if (enabled) applyChrome(ctx, `${currentModel} · ready`);
    });

    pi.on("turn_start", async (_event, ctx) => {
        turnCount++;
        if (enabled) applyChrome(ctx, `${currentModel} · turn ${turnCount}`);
    });

    pi.on("turn_end", async (_event, ctx) => {
        if (enabled)
            applyChrome(ctx, `${currentModel} · turn ${turnCount} complete`);
    });

    pi.registerCommand("cool-ui", {
        description:
            "Reapply the neon Pi header, spinner, editor glow, and footer status.",
        handler: async (_args, ctx) => {
            enabled = true;
            applyChrome(ctx, `${currentModel} · ready`);
            applyEditor(ctx);
            ctx.ui.notify("Neon UI reapplied", "info");
        },
    });

    pi.registerCommand("boring-ui", {
        description:
            "Restore Pi's built-in header, spinner, working text, and editor.",
        handler: async (_args, ctx) => {
            enabled = false;
            ctx.ui.setHeader(undefined);
            ctx.ui.setWorkingIndicator();
            ctx.ui.setWorkingMessage();
            ctx.ui.setStatus("cool-ui", undefined);
            ctx.ui.setEditorComponent(undefined);
            ctx.ui.notify("Back to boring mode", "info");
        },
    });
}
