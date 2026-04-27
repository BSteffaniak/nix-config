import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, resolve } from "node:path";

import type {
    ExtensionAPI,
    ExtensionContext,
} from "@mariozechner/pi-coding-agent";

type Action = "allow" | "deny" | "ask";
type ModeName = "build" | "plan";

type ModeConfig = {
    tools?: Record<string, boolean>;
    permission?: {
        bash?: Record<string, Action>;
        external_directory?: Action;
    };
};

type PermissionConfig = {
    agent?: Record<string, ModeConfig>;
};

type Rule = {
    pattern: string;
    action: Action;
    regex: RegExp;
    specificity: number;
};

const CONFIG_PATH = `${homedir()}/.pi/agent/opencode-permissions.json`;
const READ_TOOLS = ["read", "grep", "find", "ls"];
const INTERACTIVE_TOOLS = ["question"];
const BUILD_ONLY_TOOLS = ["subagent"];
const MUTATING_TOOLS = new Set(["write", "edit"]);
const DEFAULT_CONFIG: PermissionConfig = {
    agent: {
        build: {
            tools: { write: true, edit: true, bash: true },
            permission: { bash: { "*": "allow" }, external_directory: "allow" },
        },
        plan: {
            tools: { write: false, edit: false, bash: true },
            permission: { bash: { "*": "deny" }, external_directory: "allow" },
        },
    },
};

function loadConfig(): PermissionConfig {
    if (!existsSync(CONFIG_PATH)) return DEFAULT_CONFIG;
    try {
        return JSON.parse(
            readFileSync(CONFIG_PATH, "utf8"),
        ) as PermissionConfig;
    } catch {
        return DEFAULT_CONFIG;
    }
}

function modeConfig(config: PermissionConfig, mode: ModeName): ModeConfig {
    return config.agent?.[mode] ?? DEFAULT_CONFIG.agent![mode]!;
}

function globToRegex(pattern: string): RegExp {
    let source = "";
    for (const char of pattern) {
        if (char === "*") {
            source += ".*";
        } else if ("\\^$+?.()|{}[]".includes(char)) {
            source += `\\${char}`;
        } else {
            source += char;
        }
    }
    return new RegExp(`^${source}$`);
}

function ruleSpecificity(pattern: string): number {
    const nonWildcardChars = pattern.replaceAll("*", "").length;
    const exactBonus = pattern.includes("*") ? 0 : 1000;
    return exactBonus + nonWildcardChars;
}

function compileRules(config: ModeConfig): Rule[] {
    return Object.entries(config.permission?.bash ?? {}).map(
        ([pattern, action]) => ({
            pattern,
            action,
            regex: globToRegex(pattern),
            specificity: ruleSpecificity(pattern),
        }),
    );
}

function matchingRule(command: string, rules: Rule[]): Rule | undefined {
    return rules
        .filter((rule) => rule.regex.test(command))
        .sort(
            (a, b) =>
                b.specificity - a.specificity ||
                b.pattern.length - a.pattern.length,
        )[0];
}

function commandParts(command: string): string[] {
    const parts = command
        .split(/\s*(?:&&|\|\||;|\|)\s*/)
        .map((part) => part.trim())
        .filter(Boolean);
    return parts.length > 0 ? parts : [command];
}

function deniedCommandPart(
    command: string,
    rules: Rule[],
): { command: string; rule?: Rule; action: Action } | undefined {
    for (const part of commandParts(command)) {
        const rule = matchingRule(part, rules);
        const action = rule?.action ?? "deny";
        if (action !== "allow") return { command: part, rule, action };
    }
    return undefined;
}

function activeToolsFor(config: ModeConfig, mode: ModeName): string[] {
    const tools = config.tools ?? {};
    const active = [...READ_TOOLS, ...INTERACTIVE_TOOLS];
    if (tools.bash !== false) active.push("bash");
    if (tools.edit === true) active.push("edit");
    if (tools.write === true) active.push("write");
    if (mode === "build") active.push(...BUILD_ONLY_TOOLS);
    return active;
}

function candidatePaths(
    toolName: string,
    input: Record<string, unknown>,
): string[] {
    const keys =
        toolName === "edit" ? ["path", "filePath"] : ["path", "filePath"];
    return keys
        .map((key) => input[key])
        .filter((value): value is string => typeof value === "string");
}

function isExternalPath(path: string, cwd: string): boolean {
    const resolvedCwd = resolve(cwd);
    const resolvedPath = isAbsolute(path) ? resolve(path) : resolve(cwd, path);
    return (
        resolvedPath !== resolvedCwd &&
        !resolvedPath.startsWith(`${resolvedCwd}/`)
    );
}

function messageText(message: unknown): string {
    const content = (message as { content?: unknown }).content;
    if (typeof content === "string") return content;
    if (!Array.isArray(content)) return "";
    return content
        .map((item) => {
            if (typeof item === "string") return item;
            if (
                item &&
                typeof item === "object" &&
                typeof (item as { text?: unknown }).text === "string"
            ) {
                return (item as { text: string }).text;
            }
            return "";
        })
        .join("\n");
}

function isStaleModeMessage(message: unknown, activeMode: ModeName): boolean {
    const customType = (message as { customType?: unknown }).customType;
    if (activeMode === "build" && customType === "opencode-plan-mode-context") {
        return true;
    }
    if (activeMode === "plan" && customType === "opencode-build-mode-context") {
        return true;
    }

    const text = messageText(message);
    if (activeMode === "build") {
        return (
            text.includes("[PLAN MODE ACTIVE]") ||
            text.includes("# Plan Mode - System Reminder") ||
            text.includes("Plan mode ACTIVE")
        );
    }
    return text.includes("[BUILD MODE ACTIVE]");
}

async function maybeAsk(
    ctx: ExtensionContext,
    title: string,
    body: string,
): Promise<boolean> {
    if (!ctx.hasUI) return false;
    const choice = await ctx.ui.select(`${title}\n\n${body}`, [
        "Allow",
        "Deny",
    ]);
    return choice === "Allow";
}

export default function opencodeModes(pi: ExtensionAPI): void {
    let config = loadConfig();
    let mode: ModeName = "build";

    pi.registerFlag("plan", {
        description: "Start in OpenCode-style plan mode",
        type: "boolean",
        default: false,
    });

    function applyMode(ctx?: ExtensionContext): void {
        config = loadConfig();
        pi.setActiveTools(activeToolsFor(modeConfig(config, mode), mode));
        ctx?.ui.setStatus("opencode-mode", mode);
    }

    function setMode(nextMode: ModeName, ctx: ExtensionContext): void {
        mode = nextMode;
        applyMode(ctx);
        ctx.ui.notify(`OpenCode ${mode} mode enabled`, "info");
        pi.appendEntry("opencode-mode", { mode });
    }

    function toggleMode(ctx: ExtensionContext): void {
        setMode(mode === "plan" ? "build" : "plan", ctx);
    }

    pi.registerCommand("plan", {
        description: "Switch to OpenCode-style read-only plan mode",
        handler: async (_args, ctx) => setMode("plan", ctx),
    });

    pi.registerCommand("build", {
        description: "Switch to OpenCode-style build mode",
        handler: async (_args, ctx) => setMode("build", ctx),
    });

    pi.registerCommand("mode", {
        description: "Show or change the current OpenCode-style mode",
        handler: async (args, ctx) => {
            const requested = args.trim();
            if (requested === "plan" || requested === "build") {
                setMode(requested, ctx);
                return;
            }
            if (!ctx.hasUI) {
                ctx.ui.notify(`Current mode: ${mode}`, "info");
                return;
            }
            const choice = await ctx.ui.select(`Current mode: ${mode}`, [
                "plan",
                "build",
            ]);
            if (choice === "plan" || choice === "build") setMode(choice, ctx);
        },
    });

    pi.registerShortcut("tab", {
        description: "Toggle OpenCode plan/build mode",
        handler: async (ctx) => toggleMode(ctx),
    });

    pi.on("session_start", async (_event, ctx) => {
        const lastModeEntry = ctx.sessionManager
            .getEntries()
            .filter(
                (entry: any) =>
                    entry.type === "custom" &&
                    entry.customType === "opencode-mode",
            )
            .pop() as { data?: { mode?: ModeName } } | undefined;

        if (
            lastModeEntry?.data?.mode === "plan" ||
            lastModeEntry?.data?.mode === "build"
        ) {
            mode = lastModeEntry.data.mode;
        }

        if (pi.getFlag("plan") === true) mode = "plan";

        applyMode(ctx);
    });

    pi.on("context", async (event) => ({
        messages: event.messages.filter(
            (message) => !isStaleModeMessage(message, mode),
        ),
    }));

    pi.on("before_agent_start", async (event) => {
        if (mode === "build") {
            return {
                systemPrompt: `${event.systemPrompt}

[BUILD MODE ACTIVE]
You are in OpenCode-style build mode.

Capabilities:
- You may edit and write files when needed.
- Bash commands are governed by the OpenCode permission config in ${CONFIG_PATH}.
- Do not claim you are in plan mode. If the user asks you to start implementation, proceed subject to tool permissions.`,
            };
        }

        return {
            systemPrompt: `${event.systemPrompt}

[PLAN MODE ACTIVE]
You are in OpenCode-style plan mode.

Restrictions:
- You may inspect and analyze the codebase.
- You must not edit, write, or otherwise modify files.
- Bash commands are governed by the OpenCode permission config in ${CONFIG_PATH}.
- Produce a concrete implementation plan and wait for the user to switch to build mode before making changes.`,
        };
    });

    pi.on("tool_call", async (event, ctx) => {
        const current = modeConfig(config, mode);
        const tools = current.tools ?? {};
        const toolName = event.toolName;

        if (toolName === "bash" && tools.bash === false) {
            return { block: true, reason: `${mode} mode blocks bash` };
        }

        if (MUTATING_TOOLS.has(toolName) && tools[toolName] !== true) {
            return { block: true, reason: `${mode} mode blocks ${toolName}` };
        }

        const externalDirectory = current.permission?.external_directory;
        if (externalDirectory === "deny" || externalDirectory === "ask") {
            const paths = candidatePaths(
                toolName,
                event.input as Record<string, unknown>,
            );
            const external = paths.find((path) =>
                isExternalPath(path, ctx.cwd),
            );
            if (external) {
                if (externalDirectory === "ask") {
                    const allowed = await maybeAsk(
                        ctx,
                        "External directory access",
                        `${toolName}: ${external}`,
                    );
                    if (allowed) return undefined;
                }
                return {
                    block: true,
                    reason: `${mode} mode blocks external directory access: ${external}`,
                };
            }
        }

        if (toolName !== "bash") return undefined;

        const command = String(
            (event.input as { command?: unknown }).command ?? "",
        ).trim();
        const denied = deniedCommandPart(command, compileRules(current));

        if (!denied) return undefined;

        if (denied.action === "ask") {
            const allowed = await maybeAsk(
                ctx,
                `${mode} mode command permission`,
                denied.command,
            );
            if (allowed) return undefined;
        }

        const pattern = denied.rule ? ` (matched ${denied.rule.pattern})` : "";
        return {
            block: true,
            reason: `${mode} mode denied bash command${pattern}: ${denied.command}`,
        };
    });
}
