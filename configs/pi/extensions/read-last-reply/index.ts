import { spawn, type ChildProcess } from "node:child_process";
import { accessSync, constants } from "node:fs";
import { delimiter, join } from "node:path";
import type {
    ExtensionAPI,
    ExtensionContext,
} from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "read-last-reply";
const STATE_TYPE = "read-last-reply-state";
const DEFAULT_MAX_CHARS = 6000;

let currentSpeech: ChildProcess | undefined;
let currentSpeechId = 0;
let autoRead = false;

type TextBlock = {
    type?: unknown;
    text?: unknown;
};

type MessageLike = {
    role?: unknown;
    content?: unknown;
};

type SessionEntryLike = {
    type?: unknown;
    customType?: unknown;
    data?: unknown;
    message?: MessageLike;
};

type SpeechBackend = {
    name: string;
    command: string;
    args: (text: string) => string[];
};

function executableInPath(name: string): string | undefined {
    const path = process.env.PATH ?? "";
    for (const dir of path.split(delimiter)) {
        if (!dir) continue;
        const candidate = join(dir, name);
        try {
            accessSync(candidate, constants.X_OK);
            return candidate;
        } catch {
            // Keep searching.
        }
    }
    return undefined;
}

function executableAt(path: string): string | undefined {
    try {
        accessSync(path, constants.X_OK);
        return path;
    } catch {
        return undefined;
    }
}

function getRate(defaultRate: string): string {
    return process.env.PI_READ_REPLY_RATE ?? defaultRate;
}

function speechArgument(text: string): string {
    // Keep spoken text from being interpreted as another command-line option.
    return text.startsWith("-") ? ` ${text}` : text;
}

function resolveBackend(): SpeechBackend | undefined {
    if (process.platform === "darwin") {
        const command = executableAt("/usr/bin/say") ?? executableInPath("say");
        if (!command) return undefined;
        return {
            name: "say",
            command,
            args: (text) => ["-r", getRate("210"), speechArgument(text)],
        };
    }

    const espeakNg = executableInPath("espeak-ng");
    if (espeakNg) {
        return {
            name: "espeak-ng",
            command: espeakNg,
            args: (text) => ["-s", getRate("175"), speechArgument(text)],
        };
    }

    const espeak = executableInPath("espeak");
    if (espeak) {
        return {
            name: "espeak",
            command: espeak,
            args: (text) => ["-s", getRate("175"), speechArgument(text)],
        };
    }

    return undefined;
}

function extractAssistantText(message: unknown): string {
    if (!message || typeof message !== "object") return "";

    const msg = message as MessageLike;
    if (msg.role !== "assistant") return "";

    if (typeof msg.content === "string") {
        return msg.content;
    }

    if (!Array.isArray(msg.content)) return "";

    return msg.content
        .map((block: unknown) => {
            if (!block || typeof block !== "object") return "";
            const textBlock = block as TextBlock;
            return textBlock.type === "text" &&
                typeof textBlock.text === "string"
                ? textBlock.text
                : "";
        })
        .filter(Boolean)
        .join("\n")
        .trim();
}

function findLastAssistantText(ctx: ExtensionContext): string | undefined {
    const branch = ctx.sessionManager.getBranch() as SessionEntryLike[];

    for (let i = branch.length - 1; i >= 0; i -= 1) {
        const entry = branch[i];
        if (entry?.type !== "message") continue;

        const text = extractAssistantText(entry.message).trim();
        if (text) return text;
    }

    return undefined;
}

function sanitizeForSpeech(raw: string): { text: string; truncated: boolean } {
    const maxChars =
        Number.parseInt(process.env.PI_READ_REPLY_MAX_CHARS ?? "", 10) ||
        DEFAULT_MAX_CHARS;

    let text = raw.replace(/\r\n?/g, "\n");

    text = text.replace(/```[\s\S]*?```/g, "\nCode block omitted.\n");
    text = text.replace(/`([^`]+)`/g, "$1");
    text = text.replace(/!\[([^\]]*)\]\([^)]*\)/g, (_match, alt: string) =>
        alt ? `Image: ${alt}` : "Image omitted.",
    );
    text = text.replace(/\[([^\]]+)\]\([^)]*\)/g, "$1");
    text = text.replace(/^\s{0,3}#{1,6}\s+/gm, "");
    text = text.replace(/^\s{0,3}>\s?/gm, "");
    text = text.replace(/[*_~]{1,3}/g, "");
    text = text.replace(/^\s*[-*+]\s+/gm, "- ");
    text = text.replace(/\n{3,}/g, "\n\n").trim();

    let truncated = false;
    if (text.length > maxChars) {
        truncated = true;
        const clipped = text.slice(0, maxChars);
        const lastBoundary = Math.max(
            clipped.lastIndexOf(". "),
            clipped.lastIndexOf("\n"),
            clipped.lastIndexOf(" "),
        );
        text = clipped
            .slice(0, lastBoundary > maxChars * 0.8 ? lastBoundary : maxChars)
            .trim();
        text += "\n\nReply truncated.";
    }

    return { text, truncated };
}

function updateStatus(ctx: ExtensionContext): void {
    if (!ctx.hasUI) return;

    if (currentSpeech) {
        ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("accent", "🔊 speaking"));
        return;
    }

    if (autoRead) {
        ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("accent", "🔊 auto"));
        return;
    }

    ctx.ui.setStatus(STATUS_KEY, undefined);
}

function stopSpeech(ctx?: ExtensionContext, notify = true): void {
    if (!currentSpeech) {
        if (notify && ctx?.hasUI)
            ctx.ui.notify("Nothing is being read", "info");
        updateStatusIfPresent(ctx);
        return;
    }

    const speech = currentSpeech;
    currentSpeech = undefined;
    currentSpeechId += 1;

    if (!speech.killed) {
        speech.kill("SIGTERM");
        setTimeout(() => {
            if (!speech.killed) speech.kill("SIGKILL");
        }, 500).unref?.();
    }

    if (notify && ctx?.hasUI) ctx.ui.notify("Stopped reading", "info");
    updateStatusIfPresent(ctx);
}

function updateStatusIfPresent(ctx?: ExtensionContext): void {
    if (ctx) updateStatus(ctx);
}

function speakText(rawText: string, ctx: ExtensionContext): void {
    const { text, truncated } = sanitizeForSpeech(rawText);
    if (!text) {
        if (ctx.hasUI)
            ctx.ui.notify(
                "Last assistant reply has no speakable text",
                "warning",
            );
        return;
    }

    const backend = resolveBackend();
    if (!backend) {
        if (ctx.hasUI) {
            ctx.ui.notify(
                "No text-to-speech command found. macOS uses say; Linux uses espeak-ng/espeak.",
                "warning",
            );
        }
        return;
    }

    stopSpeech(ctx, false);

    const speechId = currentSpeechId + 1;
    currentSpeechId = speechId;

    const child = spawn(backend.command, backend.args(text), {
        stdio: "ignore",
    });

    currentSpeech = child;
    updateStatus(ctx);

    if (ctx.hasUI) {
        ctx.ui.notify(
            truncated
                ? `Reading with ${backend.name} (truncated)`
                : `Reading with ${backend.name}`,
            "info",
        );
    }

    child.once("error", (error) => {
        if (currentSpeechId === speechId) {
            currentSpeech = undefined;
            updateStatus(ctx);
        }
        if (ctx.hasUI)
            ctx.ui.notify(`Failed to read reply: ${error.message}`, "error");
    });

    child.once("exit", () => {
        if (currentSpeechId === speechId) {
            currentSpeech = undefined;
            updateStatus(ctx);
        }
    });
}

function speakLastReply(ctx: ExtensionContext): void {
    const text = findLastAssistantText(ctx);
    if (!text) {
        if (ctx.hasUI)
            ctx.ui.notify("No previous assistant reply found", "warning");
        return;
    }

    speakText(text, ctx);
}

function restoreState(ctx: ExtensionContext): void {
    autoRead = false;

    const branch = ctx.sessionManager.getBranch() as SessionEntryLike[];
    for (let i = branch.length - 1; i >= 0; i -= 1) {
        const entry = branch[i];
        if (entry?.type !== "custom" || entry.customType !== STATE_TYPE)
            continue;
        if (!entry.data || typeof entry.data !== "object") continue;

        const data = entry.data as { autoRead?: unknown };
        if (typeof data.autoRead === "boolean") {
            autoRead = data.autoRead;
            break;
        }
    }
}

function persistState(pi: ExtensionAPI): void {
    pi.appendEntry(STATE_TYPE, { autoRead });
}

function setAutoRead(
    value: boolean,
    pi: ExtensionAPI,
    ctx: ExtensionContext,
): void {
    autoRead = value;
    persistState(pi);
    updateStatus(ctx);
    if (ctx.hasUI)
        ctx.ui.notify(`Auto-read ${autoRead ? "enabled" : "disabled"}`, "info");
}

export default function readLastReply(pi: ExtensionAPI): void {
    pi.registerShortcut("ctrl+alt+r", {
        description: "Read the last assistant reply aloud",
        handler: async (ctx) => {
            speakLastReply(ctx);
        },
    });

    pi.registerShortcut("ctrl+alt+x", {
        description: "Stop reading the assistant reply",
        handler: async (ctx) => {
            stopSpeech(ctx);
        },
    });

    pi.registerCommand("speak-last", {
        description: "Read the last assistant reply aloud",
        handler: async (_args, ctx) => {
            speakLastReply(ctx);
        },
    });

    pi.registerCommand("speak-stop", {
        description: "Stop reading the assistant reply",
        handler: async (_args, ctx) => {
            stopSpeech(ctx);
        },
    });

    pi.registerCommand("speak-auto", {
        description: "Toggle automatic reading of assistant replies",
        handler: async (args, ctx) => {
            const normalized = (args ?? "").trim().toLowerCase();
            if (["on", "true", "yes", "1"].includes(normalized)) {
                setAutoRead(true, pi, ctx);
                return;
            }
            if (["off", "false", "no", "0"].includes(normalized)) {
                setAutoRead(false, pi, ctx);
                return;
            }
            setAutoRead(!autoRead, pi, ctx);
        },
    });

    pi.on("session_start", async (_event, ctx) => {
        restoreState(ctx);
        updateStatus(ctx);
    });

    pi.on("message_end", async (event, ctx) => {
        if (!autoRead) return;

        const text = extractAssistantText(event.message).trim();
        if (!text) return;

        speakText(text, ctx);
    });

    pi.on("session_shutdown", async (_event, ctx) => {
        stopSpeech(ctx, false);
        if (ctx.hasUI) ctx.ui.setStatus(STATUS_KEY, undefined);
    });
}
