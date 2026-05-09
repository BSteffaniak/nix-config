import {
    existsSync,
    mkdirSync,
    readFileSync,
    renameSync,
    writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import type { Api, Model } from "@mariozechner/pi-ai";
import type {
    ExtensionAPI,
    ExtensionContext,
} from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";

const STORAGE_PATH = join(getAgentDir(), "per-model-thinking.json");
const POLL_INTERVAL_MS = 500;
const CUSTOM_TYPE = "per-model-thinking";

const THINKING_LEVELS = [
    "off",
    "minimal",
    "low",
    "medium",
    "high",
    "xhigh",
] as const;
type ThinkingLevel = (typeof THINKING_LEVELS)[number];
type Preferences = Record<string, ThinkingLevel>;

function isThinkingLevel(value: unknown): value is ThinkingLevel {
    return (
        typeof value === "string" &&
        (THINKING_LEVELS as readonly string[]).includes(value)
    );
}

function modelKey(model: Pick<Model<Api>, "provider" | "id">): string {
    return `${model.provider}/${model.id}`;
}

function loadPreferences(): Preferences {
    if (!existsSync(STORAGE_PATH)) return {};

    try {
        const parsed = JSON.parse(readFileSync(STORAGE_PATH, "utf8")) as Record<
            string,
            unknown
        >;
        const prefs: Preferences = {};

        for (const [key, value] of Object.entries(parsed)) {
            if (isThinkingLevel(value)) prefs[key] = value;
        }

        return prefs;
    } catch (error) {
        console.error(
            `[${CUSTOM_TYPE}] Failed to load ${STORAGE_PATH}:`,
            error,
        );
        return {};
    }
}

function savePreferences(preferences: Preferences): void {
    try {
        mkdirSync(dirname(STORAGE_PATH), { recursive: true });
        const tmpPath = `${STORAGE_PATH}.tmp`;
        writeFileSync(
            tmpPath,
            `${JSON.stringify(preferences, null, 2)}\n`,
            "utf8",
        );
        renameSync(tmpPath, STORAGE_PATH);
    } catch (error) {
        console.error(
            `[${CUSTOM_TYPE}] Failed to save ${STORAGE_PATH}:`,
            error,
        );
    }
}

function getLatestSessionThinkingLevel(
    ctx: ExtensionContext,
): ThinkingLevel | undefined {
    const entries = ctx.sessionManager.getBranch();

    for (let i = entries.length - 1; i >= 0; i--) {
        const entry = entries[i] as { type?: string; thinkingLevel?: unknown };
        if (
            entry.type === "thinking_level_change" &&
            isThinkingLevel(entry.thinkingLevel)
        ) {
            return entry.thinkingLevel;
        }
    }

    return undefined;
}

export default function perModelThinking(pi: ExtensionAPI) {
    let preferences: Preferences = loadPreferences();
    let currentModelKey: string | undefined;
    let lastSeenLevel: ThinkingLevel | undefined;
    let pollTimer: ReturnType<typeof setInterval> | undefined;
    let suppressNextPoll = false;

    function persistCurrentLevel(level: ThinkingLevel = pi.getThinkingLevel()) {
        if (!currentModelKey) return;
        if (preferences[currentModelKey] === level) return;

        preferences[currentModelKey] = level;
        savePreferences(preferences);
    }

    function updateStatus(ctx: ExtensionContext) {
        const level = pi.getThinkingLevel();
        const key = currentModelKey ? ` ${currentModelKey}` : "";
        ctx.ui.setStatus(
            CUSTOM_TYPE,
            ctx.ui.theme.fg("dim", `think ${level}${key}`),
        );
    }

    function startPolling(ctx: ExtensionContext) {
        if (pollTimer) clearInterval(pollTimer);

        pollTimer = setInterval(() => {
            const level = pi.getThinkingLevel();

            if (suppressNextPoll) {
                suppressNextPoll = false;
                lastSeenLevel = level;
                updateStatus(ctx);
                return;
            }

            if (level !== lastSeenLevel) {
                lastSeenLevel = level;
                persistCurrentLevel(level);
                updateStatus(ctx);
            }
        }, POLL_INTERVAL_MS);
        (pollTimer as { unref?: () => void }).unref?.();
    }

    function applySavedLevelForCurrentModel(ctx: ExtensionContext) {
        if (!currentModelKey) return;

        const saved = preferences[currentModelKey];
        if (!saved) {
            lastSeenLevel = pi.getThinkingLevel();
            updateStatus(ctx);
            return;
        }

        if (pi.getThinkingLevel() !== saved) {
            suppressNextPoll = true;
            pi.setThinkingLevel(saved);
        }

        lastSeenLevel = pi.getThinkingLevel();
        updateStatus(ctx);
    }

    pi.on("session_start", async (_event, ctx) => {
        preferences = loadPreferences();
        currentModelKey = modelKey(ctx.model);

        // If this session already contains a thinking-level change, treat it as
        // the latest user preference for the current model. This preserves
        // Shift+Tab changes even across /reload before the poller sees them.
        const sessionLevel = getLatestSessionThinkingLevel(ctx);
        if (sessionLevel) {
            preferences[currentModelKey] = sessionLevel;
            savePreferences(preferences);
        }

        applySavedLevelForCurrentModel(ctx);
        startPolling(ctx);
    });

    pi.on("model_select", async (event, ctx) => {
        // Save the level observed for the model we were on before this switch.
        if (currentModelKey && lastSeenLevel) {
            preferences[currentModelKey] = lastSeenLevel;
            savePreferences(preferences);
        }

        currentModelKey = modelKey(event.model);
        applySavedLevelForCurrentModel(ctx);
    });

    pi.on("session_shutdown", async (_event, ctx) => {
        if (pollTimer) {
            clearInterval(pollTimer);
            pollTimer = undefined;
        }

        currentModelKey = modelKey(ctx.model);
        persistCurrentLevel();
    });

    pi.registerCommand("think-save", {
        description: "Save/apply per-model thinking level preferences",
        getArgumentCompletions: (prefix) => {
            const values = [...THINKING_LEVELS, "clear", "list"];
            const filtered = values.filter((value) => value.startsWith(prefix));
            return filtered.length
                ? filtered.map((value) => ({ value, label: value }))
                : null;
        },
        handler: async (args, ctx) => {
            preferences = loadPreferences();
            currentModelKey = modelKey(ctx.model);
            const arg = args.trim();

            if (arg === "list") {
                const entries = Object.entries(preferences).sort(([a], [b]) =>
                    a.localeCompare(b),
                );
                ctx.ui.notify(
                    entries.length
                        ? entries
                              .map(([key, level]) => `${key}: ${level}`)
                              .join("\n")
                        : "No per-model thinking preferences saved",
                    "info",
                );
                return;
            }

            if (arg === "clear") {
                delete preferences[currentModelKey];
                savePreferences(preferences);
                lastSeenLevel = pi.getThinkingLevel();
                updateStatus(ctx);
                ctx.ui.notify(
                    `Cleared thinking preference for ${currentModelKey}`,
                    "info",
                );
                return;
            }

            if (arg) {
                if (!isThinkingLevel(arg)) {
                    ctx.ui.notify(`Unknown thinking level: ${arg}`, "error");
                    return;
                }

                pi.setThinkingLevel(arg);
            }

            lastSeenLevel = pi.getThinkingLevel();
            preferences[currentModelKey] = lastSeenLevel;
            savePreferences(preferences);
            updateStatus(ctx);
            ctx.ui.notify(
                `Saved ${currentModelKey} → ${lastSeenLevel}`,
                "info",
            );
        },
    });
}
