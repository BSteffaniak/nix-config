import { spawn, type ChildProcess } from "node:child_process";
import { accessSync, constants, existsSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import type {
    ExtensionAPI,
    ExtensionContext,
} from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "read-last-reply";
const STATE_TYPE = "read-last-reply-state";
const DEFAULT_MAX_CHARS = 6000;
const DEFAULT_PIPER_VOICE = "en_US-lessac-medium";

let currentJob: SpeechJob | undefined;
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

type DirectSpeechBackend = {
    kind: "direct";
    name: string;
    command: string;
    args: (text: string) => string[];
};

type PiperSpeechBackend = {
    kind: "piper";
    name: string;
    command: string;
    model: string;
    config?: string;
    player: AudioPlayer;
};

type SpeechBackend = DirectSpeechBackend | PiperSpeechBackend;

type AudioPlayer = {
    name: string;
    command: string;
    args: (file: string) => string[];
};

type SpeechJob = {
    id: number;
    phase: "synthesizing" | "speaking";
    processes: Set<ChildProcess>;
    tempFiles: Set<string>;
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

function resolveExecutable(command: string | undefined): string | undefined {
    if (!command) return undefined;
    if (command.includes("/")) return executableAt(expandHome(command));
    return executableInPath(command);
}

function expandHome(path: string): string {
    if (path === "~") return process.env.HOME ?? path;
    if (path.startsWith("~/"))
        return join(process.env.HOME ?? "", path.slice(2));
    return path;
}

function getRate(defaultRate: string): string {
    return process.env.PI_READ_REPLY_RATE ?? defaultRate;
}

function speechArgument(text: string): string {
    // Keep spoken text from being interpreted as another command-line option.
    return text.startsWith("-") ? ` ${text}` : text;
}

function getDefaultPiperModelPath(): string | undefined {
    const home = process.env.HOME;
    if (!home) return undefined;
    return join(
        home,
        ".local",
        "share",
        "tts",
        "piper",
        "voices",
        `${DEFAULT_PIPER_VOICE}.onnx`,
    );
}

function resolveAudioPlayer(): AudioPlayer | undefined {
    const override = resolveExecutable(
        process.env.PI_READ_REPLY_AUDIO_PLAYER ?? process.env.TTS_AUDIO_PLAYER,
    );
    if (override) {
        return {
            name: override.split("/").pop() ?? override,
            command: override,
            args: (file) => [file],
        };
    }

    if (process.platform === "darwin") {
        const afplay =
            executableAt("/usr/bin/afplay") ?? executableInPath("afplay");
        if (afplay) {
            return { name: "afplay", command: afplay, args: (file) => [file] };
        }
    }

    const aplay = executableInPath("aplay");
    if (aplay) return { name: "aplay", command: aplay, args: (file) => [file] };

    const paplay = executableInPath("paplay");
    if (paplay)
        return { name: "paplay", command: paplay, args: (file) => [file] };

    const ffplay = executableInPath("ffplay");
    if (ffplay)
        return {
            name: "ffplay",
            command: ffplay,
            args: (file) => [
                "-nodisp",
                "-autoexit",
                "-loglevel",
                "quiet",
                file,
            ],
        };

    const mpv = executableInPath("mpv");
    if (mpv)
        return {
            name: "mpv",
            command: mpv,
            args: (file) => ["--really-quiet", file],
        };

    return undefined;
}

function resolvePiperBackend(): PiperSpeechBackend | undefined {
    const command =
        resolveExecutable(process.env.PI_READ_REPLY_PIPER_COMMAND) ??
        executableInPath("piper");
    if (!command) return undefined;

    const model = expandHome(
        process.env.PI_READ_REPLY_PIPER_MODEL ??
            process.env.PIPER_VOICE ??
            getDefaultPiperModelPath() ??
            "",
    );
    if (!model || !existsSync(model)) return undefined;

    const configuredConfig =
        process.env.PI_READ_REPLY_PIPER_CONFIG ??
        process.env.PIPER_VOICE_CONFIG;
    const config = expandHome(configuredConfig ?? `${model}.json`);
    const player = resolveAudioPlayer();
    if (!player) return undefined;

    return {
        kind: "piper",
        name: "piper",
        command,
        model,
        config: existsSync(config) ? config : undefined,
        player,
    };
}

function resolveDirectBackend(): DirectSpeechBackend | undefined {
    if (process.platform === "darwin") {
        const command = executableAt("/usr/bin/say") ?? executableInPath("say");
        if (!command) return undefined;
        const voice = process.env.PI_READ_REPLY_VOICE;
        return {
            kind: "direct",
            name: voice ? `say/${voice}` : "say",
            command,
            args: (text) => [
                ...(voice ? ["-v", voice] : []),
                "-r",
                getRate("210"),
                speechArgument(text),
            ],
        };
    }

    const espeakNg = executableInPath("espeak-ng");
    if (espeakNg) {
        return {
            kind: "direct",
            name: "espeak-ng",
            command: espeakNg,
            args: (text) => ["-s", getRate("175"), speechArgument(text)],
        };
    }

    const espeak = executableInPath("espeak");
    if (espeak) {
        return {
            kind: "direct",
            name: "espeak",
            command: espeak,
            args: (text) => ["-s", getRate("175"), speechArgument(text)],
        };
    }

    return undefined;
}

function resolveBackend(ctx: ExtensionContext): SpeechBackend | undefined {
    const requested = (
        process.env.PI_READ_REPLY_BACKEND ??
        process.env.TTS_BACKEND ??
        "auto"
    ).toLowerCase();

    if (
        requested !== "local" &&
        requested !== "say" &&
        requested !== "espeak"
    ) {
        const piper = resolvePiperBackend();
        if (piper) return piper;
        if (requested === "piper") {
            if (ctx.hasUI) {
                ctx.ui.notify(
                    "Piper TTS is not available. Check piper, PIPER_VOICE, and your audio player.",
                    "warning",
                );
            }
            return undefined;
        }
    }

    const direct = resolveDirectBackend();
    if (direct) return direct;

    if (ctx.hasUI) {
        ctx.ui.notify(
            "No text-to-speech backend found. Enable myConfig.tools.tts.piper, or use macOS say / Linux espeak.",
            "warning",
        );
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

    if (currentJob) {
        const label =
            currentJob.phase === "synthesizing"
                ? "🔊 synthesizing"
                : "🔊 speaking";
        ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("accent", label));
        return;
    }

    if (autoRead) {
        ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("accent", "🔊 auto"));
        return;
    }

    ctx.ui.setStatus(STATUS_KEY, undefined);
}

function cleanupJob(job: SpeechJob): void {
    for (const file of job.tempFiles) {
        try {
            unlinkSync(file);
        } catch {
            // Ignore cleanup failures.
        }
    }
    job.tempFiles.clear();
}

function killProcess(process: ChildProcess): void {
    if (!process.killed) {
        process.kill("SIGTERM");
        setTimeout(() => {
            if (!process.killed) process.kill("SIGKILL");
        }, 500).unref?.();
    }
}

function finishJob(ctx: ExtensionContext, job: SpeechJob): void {
    if (currentJob !== job) return;
    currentJob = undefined;
    cleanupJob(job);
    updateStatus(ctx);
}

function stopSpeech(ctx?: ExtensionContext, notify = true): void {
    if (!currentJob) {
        if (notify && ctx?.hasUI)
            ctx.ui.notify("Nothing is being read", "info");
        if (ctx) updateStatus(ctx);
        return;
    }

    const job = currentJob;
    currentJob = undefined;
    currentSpeechId += 1;

    for (const process of job.processes) {
        killProcess(process);
    }
    cleanupJob(job);

    if (notify && ctx?.hasUI) ctx.ui.notify("Stopped reading", "info");
    if (ctx) updateStatus(ctx);
}

function startJob(ctx: ExtensionContext, phase: SpeechJob["phase"]): SpeechJob {
    stopSpeech(ctx, false);

    const job: SpeechJob = {
        id: currentSpeechId + 1,
        phase,
        processes: new Set(),
        tempFiles: new Set(),
    };
    currentSpeechId = job.id;
    currentJob = job;
    updateStatus(ctx);
    return job;
}

function buildPiperArgs(
    backend: PiperSpeechBackend,
    outputFile: string,
): string[] {
    const args = ["--model", backend.model, "--output_file", outputFile];
    if (backend.config) args.push("--config", backend.config);
    if (
        process.env.PI_READ_REPLY_PIPER_LENGTH_SCALE ??
        process.env.PIPER_LENGTH_SCALE
    ) {
        args.push(
            "--length-scale",
            process.env.PI_READ_REPLY_PIPER_LENGTH_SCALE ??
                process.env.PIPER_LENGTH_SCALE!,
        );
    }
    if (
        process.env.PI_READ_REPLY_PIPER_NOISE_SCALE ??
        process.env.PIPER_NOISE_SCALE
    ) {
        args.push(
            "--noise-scale",
            process.env.PI_READ_REPLY_PIPER_NOISE_SCALE ??
                process.env.PIPER_NOISE_SCALE!,
        );
    }
    if (
        process.env.PI_READ_REPLY_PIPER_NOISE_W_SCALE ??
        process.env.PIPER_NOISE_W_SCALE
    ) {
        args.push(
            "--noise-w-scale",
            process.env.PI_READ_REPLY_PIPER_NOISE_W_SCALE ??
                process.env.PIPER_NOISE_W_SCALE!,
        );
    }
    if (
        process.env.PI_READ_REPLY_PIPER_SENTENCE_SILENCE ??
        process.env.PIPER_SENTENCE_SILENCE
    ) {
        args.push(
            "--sentence-silence",
            process.env.PI_READ_REPLY_PIPER_SENTENCE_SILENCE ??
                process.env.PIPER_SENTENCE_SILENCE!,
        );
    }
    if (process.env.PI_READ_REPLY_PIPER_VOLUME ?? process.env.PIPER_VOLUME) {
        args.push(
            "--volume",
            process.env.PI_READ_REPLY_PIPER_VOLUME ?? process.env.PIPER_VOLUME!,
        );
    }
    return args;
}

function speakWithDirectBackend(
    text: string,
    backend: DirectSpeechBackend,
    ctx: ExtensionContext,
    truncated: boolean,
): void {
    const job = startJob(ctx, "speaking");
    const child = spawn(backend.command, backend.args(text), {
        stdio: "ignore",
    });
    job.processes.add(child);

    if (ctx.hasUI) {
        ctx.ui.notify(
            truncated
                ? `Reading with ${backend.name} (truncated)`
                : `Reading with ${backend.name}`,
            "info",
        );
    }

    child.once("error", (error) => {
        job.processes.delete(child);
        if (currentJob === job) finishJob(ctx, job);
        if (ctx.hasUI)
            ctx.ui.notify(`Failed to read reply: ${error.message}`, "error");
    });

    child.once("exit", () => {
        job.processes.delete(child);
        finishJob(ctx, job);
    });
}

function playPiperOutput(
    job: SpeechJob,
    wavFile: string,
    backend: PiperSpeechBackend,
    ctx: ExtensionContext,
): void {
    if (currentJob !== job) return;

    job.phase = "speaking";
    updateStatus(ctx);

    const player = spawn(backend.player.command, backend.player.args(wavFile), {
        stdio: "ignore",
    });
    job.processes.add(player);

    player.once("error", (error) => {
        job.processes.delete(player);
        if (currentJob === job) finishJob(ctx, job);
        if (ctx.hasUI)
            ctx.ui.notify(
                `Failed to play Piper audio: ${error.message}`,
                "error",
            );
    });

    player.once("exit", () => {
        job.processes.delete(player);
        finishJob(ctx, job);
    });
}

function speakWithPiperBackend(
    text: string,
    backend: PiperSpeechBackend,
    ctx: ExtensionContext,
    truncated: boolean,
): void {
    const job = startJob(ctx, "synthesizing");
    const wavFile = join(
        tmpdir(),
        `pi-read-reply-${process.pid}-${Date.now()}-${job.id}.wav`,
    );
    job.tempFiles.add(wavFile);

    const child = spawn(backend.command, buildPiperArgs(backend, wavFile), {
        stdio: ["pipe", "ignore", "ignore"],
    });
    job.processes.add(child);

    if (ctx.hasUI) {
        const player =
            backend.player.name === "afplay" ? "" : ` → ${backend.player.name}`;
        ctx.ui.notify(
            truncated
                ? `Reading with Piper${player} (truncated)`
                : `Reading with Piper${player}`,
            "info",
        );
    }

    child.stdin?.end(`${text}\n`);

    child.once("error", (error) => {
        job.processes.delete(child);
        if (currentJob === job) finishJob(ctx, job);
        if (ctx.hasUI)
            ctx.ui.notify(
                `Failed to synthesize Piper audio: ${error.message}`,
                "error",
            );
    });

    child.once("exit", (code) => {
        job.processes.delete(child);
        if (currentJob !== job) return;
        if (code !== 0) {
            finishJob(ctx, job);
            if (ctx.hasUI)
                ctx.ui.notify(
                    `Piper synthesis failed with exit code ${code ?? "unknown"}`,
                    "error",
                );
            return;
        }
        playPiperOutput(job, wavFile, backend, ctx);
    });
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

    const backend = resolveBackend(ctx);
    if (!backend) return;

    if (backend.kind === "piper") {
        speakWithPiperBackend(text, backend, ctx, truncated);
        return;
    }

    speakWithDirectBackend(text, backend, ctx, truncated);
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
