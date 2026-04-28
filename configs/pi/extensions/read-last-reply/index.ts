import { spawn, type ChildProcess } from "node:child_process";
import { accessSync, constants, existsSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { complete } from "@mariozechner/pi-ai";
import type {
    ExtensionAPI,
    ExtensionContext,
} from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "read-last-reply";
const STATE_TYPE = "read-last-reply-state";
const DEFAULT_MAX_CHARS = 6000;
const DEFAULT_PIPER_VOICE = "en_US-ryan-high";
const DEFAULT_AUDIO_ADAPTER_PROVIDER = "openai";
const DEFAULT_AUDIO_ADAPTER_MODEL = "gpt-4o-mini";
const AUDIO_ADAPTER_SYSTEM_PROMPT = [
    "You rewrite coding-agent replies so they are easy to understand when read aloud while the user is driving.",
    "Output only the spoken script. Do not mention that you rewrote the text.",
    "Preserve important facts, file paths, commands, function names, flags, errors, and next steps.",
    "Convert markdown structure into natural spoken prose with short sections.",
    "Convert code blocks into concise spoken explanations. For short commands or snippets, read the command or essential lines verbatim in a speakable way.",
    "For long code blocks, summarize what the code does and call out names and important behavior instead of reading every line.",
    "For tables, summarize rows and columns naturally.",
    "Keep it concise, but do not omit warnings, failures, or requested actions.",
].join("\n");

let currentJob: SpeechJob | undefined;
let currentSpeechId = 0;
let autoRead = false;
const adapterCache = new Map<string, string>();

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
    phase: "adapting" | "synthesizing" | "speaking";
    processes: Set<ChildProcess>;
    tempFiles: Set<string>;
    abortController?: AbortController;
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

type AudioAdapterMode = "off" | "heuristic" | "llm";

function getAudioAdapterMode(): AudioAdapterMode {
    const raw = (
        process.env.PI_READ_REPLY_AUDIO_ADAPTER ?? "off"
    ).toLowerCase();
    if (["llm", "ai", "model"].includes(raw)) return "llm";
    if (["heuristic", "simple", "code"].includes(raw)) return "heuristic";
    return "off";
}

function summarizeCodeBlock(
    language: string | undefined,
    code: string,
): string {
    const lines = code
        .split("\n")
        .map((line) => line.trimEnd())
        .filter((line) => line.trim().length > 0);
    const label = language?.trim() ? `${language.trim()} code` : "code";

    if (lines.length === 0) return `${label} block omitted.`;

    if (lines.length <= 5 && code.length <= 500) {
        return [`Short ${label} block:`, ...lines].join("\n");
    }

    const firstUsefulLine =
        lines.find(
            (line) =>
                !line.trim().startsWith("//") && !line.trim().startsWith("#"),
        ) ?? lines[0];
    return `A ${label} block with ${lines.length} lines. It starts with: ${firstUsefulLine.slice(0, 180)}.`;
}

function heuristicAdaptForSpeech(raw: string): string {
    return raw.replace(
        /```([^\n`]*)?\n?([\s\S]*?)```/g,
        (_match, language: string | undefined, code: string) => {
            return `\n${summarizeCodeBlock(language, code)}\n`;
        },
    );
}

function buildAudioAdapterPrompt(raw: string): string {
    return [
        "Rewrite this assistant reply as a script for text-to-speech.",
        "The listener may be driving, so make code, markdown, tables, and paths understandable by ear.",
        "Keep the same meaning and preserve important technical details.",
        "Aim for less than 900 words unless the reply contains critical step-by-step instructions.",
        "",
        "<assistant_reply>",
        raw,
        "</assistant_reply>",
    ].join("\n");
}

function extractResponseText(response: { content?: unknown }): string {
    if (!Array.isArray(response.content)) return "";
    return response.content
        .filter((content): content is { type: "text"; text: string } => {
            return Boolean(
                content &&
                typeof content === "object" &&
                (content as { type?: unknown }).type === "text" &&
                typeof (content as { text?: unknown }).text === "string",
            );
        })
        .map((content) => content.text)
        .join("\n")
        .trim();
}

function rememberAdaptedText(raw: string, adapted: string): void {
    adapterCache.set(raw, adapted);
    while (adapterCache.size > 20) {
        const first = adapterCache.keys().next().value;
        if (first === undefined) break;
        adapterCache.delete(first);
    }
}

async function adaptWithLlm(
    raw: string,
    ctx: ExtensionContext,
    signal?: AbortSignal,
): Promise<string | undefined> {
    const provider =
        process.env.PI_READ_REPLY_AUDIO_ADAPTER_PROVIDER ??
        DEFAULT_AUDIO_ADAPTER_PROVIDER;
    const modelId =
        process.env.PI_READ_REPLY_AUDIO_ADAPTER_MODEL ??
        DEFAULT_AUDIO_ADAPTER_MODEL;
    const requestedModel = ctx.modelRegistry.find(provider, modelId);
    const candidates = [requestedModel, ctx.model].filter(
        (model, index, models) => {
            return Boolean(
                model &&
                models.findIndex(
                    (other) =>
                        other?.provider === model.provider &&
                        other?.id === model.id,
                ) === index,
            );
        },
    );

    if (candidates.length === 0) {
        throw new Error(
            `No model available for audio adapter (${provider}/${modelId})`,
        );
    }

    const authErrors: string[] = [];
    for (const model of candidates) {
        if (!model) continue;

        const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
        if (!auth.ok || !auth.apiKey) {
            authErrors.push(
                auth.ok
                    ? `No API key for ${model.provider}/${model.id}`
                    : auth.error,
            );
            continue;
        }

        const response = await complete(
            model,
            {
                systemPrompt: AUDIO_ADAPTER_SYSTEM_PROMPT,
                messages: [
                    {
                        role: "user" as const,
                        content: [
                            {
                                type: "text" as const,
                                text: buildAudioAdapterPrompt(raw),
                            },
                        ],
                        timestamp: Date.now(),
                    },
                ],
            },
            {
                apiKey: auth.apiKey,
                headers: auth.headers,
                signal,
                reasoningEffort: "minimal",
            },
        );

        if (response.stopReason === "aborted") return undefined;

        const adapted = extractResponseText(response).trim();
        return adapted.length > 0 ? adapted : undefined;
    }

    throw new Error(
        authErrors.join("; ") ||
            `No API key for audio adapter (${provider}/${modelId})`,
    );
}

async function adaptForSpeech(
    raw: string,
    ctx: ExtensionContext,
): Promise<string | undefined> {
    const mode = getAudioAdapterMode();
    if (mode === "off") return raw;

    const cached = adapterCache.get(raw);
    if (cached) return cached;

    const heuristic = heuristicAdaptForSpeech(raw);
    if (mode === "heuristic") {
        rememberAdaptedText(raw, heuristic);
        return heuristic;
    }

    const job = startJob(ctx, "adapting");
    job.abortController = new AbortController();

    try {
        const adapted = await adaptWithLlm(
            raw,
            ctx,
            job.abortController.signal,
        );
        if (currentJob !== job) return undefined;

        currentJob = undefined;
        cleanupJob(job);
        updateStatus(ctx);

        if (adapted) {
            rememberAdaptedText(raw, adapted);
            return adapted;
        }
    } catch (error) {
        if (currentJob !== job) return undefined;
        finishJob(ctx, job);
        if (ctx.hasUI) {
            const message =
                error instanceof Error ? error.message : String(error);
            ctx.ui.notify(
                `Audio adapter failed; using heuristic fallback: ${message}`,
                "warning",
            );
        }
    }

    rememberAdaptedText(raw, heuristic);
    return heuristic;
}

function updateStatus(ctx: ExtensionContext): void {
    if (!ctx.hasUI) return;

    if (currentJob) {
        const labels: Record<SpeechJob["phase"], string> = {
            adapting: "🔊 adapting",
            synthesizing: "🔊 synthesizing",
            speaking: "🔊 speaking",
        };
        ctx.ui.setStatus(
            STATUS_KEY,
            ctx.ui.theme.fg("accent", labels[currentJob.phase]),
        );
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

    job.abortController?.abort();
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

async function speakText(
    rawText: string,
    ctx: ExtensionContext,
): Promise<void> {
    const backend = resolveBackend(ctx);
    if (!backend) return;

    const adaptedText = await adaptForSpeech(rawText, ctx);
    if (adaptedText === undefined) return;

    const { text, truncated } = sanitizeForSpeech(adaptedText);
    if (!text) {
        if (ctx.hasUI)
            ctx.ui.notify(
                "Last assistant reply has no speakable text",
                "warning",
            );
        return;
    }

    if (backend.kind === "piper") {
        speakWithPiperBackend(text, backend, ctx, truncated);
        return;
    }

    speakWithDirectBackend(text, backend, ctx, truncated);
}

async function speakLastReply(ctx: ExtensionContext): Promise<void> {
    const text = findLastAssistantText(ctx);
    if (!text) {
        if (ctx.hasUI)
            ctx.ui.notify("No previous assistant reply found", "warning");
        return;
    }

    await speakText(text, ctx);
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
            await speakLastReply(ctx);
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
            await speakLastReply(ctx);
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

        await speakText(text, ctx);
    });

    pi.on("session_shutdown", async (_event, ctx) => {
        stopSpeech(ctx, false);
        if (ctx.hasUI) ctx.ui.setStatus(STATUS_KEY, undefined);
    });
}
