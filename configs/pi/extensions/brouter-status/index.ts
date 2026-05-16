import { createHash } from "node:crypto";
import type {
    ExtensionAPI,
    ExtensionContext,
} from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "brouter-route";
const CUSTOM_ENTRY = "brouter-route";
const DEFAULT_BROUTER_URL = "http://127.0.0.1:8080";

type Headers = Record<string, unknown>;
type Scope = "next" | "session";
type Preference =
    | "balanced"
    | "stronger"
    | "faster"
    | "cheaper"
    | "slower"
    | "local"
    | "conserve_quota";

type Route = {
    requestId?: string;
    eventId?: string;
    sessionId?: string;
    selectedModel: string;
    provider: string;
    upstreamModel: string;
    serviceTier?: string;
    reasoningEffort?: string;
    resourcePools: string[];
    summary?: string;
    fallbackUsed: boolean;
    badges: string[];
};

type PreferenceState = {
    preference?: Preference;
    scope?: Scope;
};

function brouterUrl(): string {
    return (process.env.BROUTER_URL || DEFAULT_BROUTER_URL).replace(/\/$/, "");
}

function header(headers: Headers, name: string): string | undefined {
    const value = headers[name] ?? headers[name.toLowerCase()];
    if (Array.isArray(value)) {
        const first = value.find(
            (item): item is string => typeof item === "string",
        );
        return first?.trim() || undefined;
    }
    if (typeof value === "string") return value.trim() || undefined;
    return undefined;
}

function splitHeader(value: string | undefined): string[] {
    return (value ?? "")
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
}

function routeFromHeaders(headers: Headers): Route | undefined {
    const selectedModel = header(headers, "x-brouter-selected-model");
    const provider = header(headers, "x-brouter-provider");
    const upstreamModel = header(headers, "x-brouter-upstream-model");
    if (!selectedModel || !provider || !upstreamModel) return undefined;

    return {
        requestId: header(headers, "x-brouter-request-id"),
        eventId: header(headers, "x-brouter-event-id"),
        sessionId: header(headers, "x-brouter-session"),
        selectedModel,
        provider,
        upstreamModel,
        serviceTier: header(headers, "x-brouter-service-tier"),
        reasoningEffort: header(headers, "x-brouter-reasoning-effort"),
        resourcePools: splitHeader(header(headers, "x-brouter-resource-pools")),
        summary: header(headers, "x-brouter-routing-summary"),
        fallbackUsed: header(headers, "x-brouter-fallback-used") === "true",
        badges: splitHeader(header(headers, "x-brouter-display-badges")),
    };
}

function sessionId(ctx: ExtensionContext): string {
    const sessionFile = ctx.sessionManager.getSessionFile?.() ?? ctx.cwd;
    return `pi-${createHash("sha256").update(sessionFile).digest("hex").slice(0, 16)}`;
}

function isBrouterPayload(
    payload: unknown,
): payload is Record<string, unknown> {
    if (!payload || typeof payload !== "object") return false;
    const model = (payload as { model?: unknown }).model;
    return (
        process.env.BROUTER_EXTENSION_ALWAYS === "1" ||
        model === "auto" ||
        model === "brouter/auto" ||
        (typeof model === "string" &&
            (model.startsWith("profile:") || model.startsWith("group:")))
    );
}

function routeLabel(route: Route): string {
    const badges = route.badges.length > 0 ? ` ${route.badges.join(" ")}` : "";
    const tier = route.serviceTier ? ` ${route.serviceTier}` : "";
    const reasoning = route.reasoningEffort ? ` ${route.reasoningEffort}` : "";
    const fallback = route.fallbackUsed ? " fallback" : "";
    return `↗ ${route.upstreamModel}${badges}${tier}${reasoning}${fallback}`;
}

function updateStatus(
    ctx: ExtensionContext,
    route: Route | undefined,
    preference: PreferenceState,
) {
    const preferenceLabel = preference.preference
        ? ` pref:${preference.preference}${preference.scope === "next" ? "(next)" : ""}`
        : "";
    const routeText = route ? routeLabel(route) : "brouter";
    ctx.ui.setStatus(
        STATUS_KEY,
        ctx.ui.theme.fg("dim", `${routeText}${preferenceLabel}`),
    );
}

function preferenceFromArg(arg: string): Preference | undefined {
    const normalized = arg.trim().replace(/-/g, "_") as Preference;
    return [
        "balanced",
        "stronger",
        "faster",
        "cheaper",
        "slower",
        "local",
        "conserve_quota",
    ].includes(normalized)
        ? normalized
        : undefined;
}

async function fetchJson(path: string): Promise<unknown> {
    const response = await fetch(`${brouterUrl()}${path}`);
    if (!response.ok) {
        throw new Error(`brouter ${path} failed: HTTP ${response.status}`);
    }
    return response.json();
}

function timelineLines(events: unknown): string[] {
    if (!Array.isArray(events) || events.length === 0)
        return ["No brouter events."];
    return events.slice(-25).map((event) => {
        const item = event as {
            timestamp_ms?: number;
            kind?: string;
            request_id?: string;
            event_id?: string;
            payload?: Record<string, unknown>;
        };
        const payload = item.payload ?? {};
        if (item.kind === "route_decision") {
            const controls = (payload.request_controls ?? {}) as Record<
                string,
                unknown
            >;
            const features = (payload.features ?? {}) as Record<
                string,
                unknown
            >;
            return [
                `${item.timestamp_ms ?? ""} route`,
                String(payload.selected_model ?? "<unknown>"),
                `tier=${String(controls.service_tier ?? "default")}`,
                `reasoning=${String(controls.reasoning_effort ?? "default")}`,
                `intent=${String(features.intent ?? "unknown")}/${String(features.reasoning ?? "unknown")}`,
            ].join("  ");
        }
        if (item.kind === "provider_attempt") {
            return `${item.timestamp_ms ?? ""} attempt  ${String(payload.model_id ?? "<unknown>")} status=${String(payload.status_code ?? "error")}`;
        }
        return `${item.timestamp_ms ?? ""} ${item.kind ?? "event"} ${item.event_id ?? ""}`;
    });
}

export default function brouterStatus(pi: ExtensionAPI) {
    let lastRoute: Route | undefined;
    let preference: PreferenceState = {};

    pi.on("session_start", async (_event, ctx) => {
        lastRoute = undefined;
        preference = {};
        for (const entry of ctx.sessionManager.getBranch()) {
            if (entry.type !== "custom" || entry.customType !== CUSTOM_ENTRY) {
                continue;
            }
            const data = entry.data as {
                preference?: PreferenceState;
                route?: Route;
            };
            if (data.preference) preference = data.preference;
            if (data.route) lastRoute = data.route;
        }
        updateStatus(ctx, lastRoute, preference);
    });

    pi.on("before_provider_request", async (event, ctx) => {
        if (!isBrouterPayload(event.payload)) return;
        const payload = event.payload as Record<string, unknown>;
        const metadata =
            payload.metadata && typeof payload.metadata === "object"
                ? { ...(payload.metadata as Record<string, unknown>) }
                : {};
        metadata.session_id = metadata.session_id ?? sessionId(ctx);
        metadata.brouter_session_id =
            metadata.brouter_session_id ?? sessionId(ctx);
        metadata.brouter_client = "pi";
        if (preference.preference) {
            metadata.brouter_preference = preference.preference;
            metadata.brouter_preference_scope = preference.scope ?? "session";
            metadata.brouter_preference_reason = "user correction from pi";
        }
        return { ...payload, metadata };
    });

    pi.on("after_provider_response", async (event, ctx) => {
        const route = routeFromHeaders((event.headers ?? {}) as Headers);
        if (!route) return;

        lastRoute = route;
        pi.appendEntry(CUSTOM_ENTRY, { route, preference });
        updateStatus(ctx, route, preference);
        if (preference.scope === "next") {
            preference = {};
        }
    });

    pi.registerCommand("brouter-status", {
        description: "Show brouter routing status for this Pi session",
        handler: async (_args, ctx) => {
            ctx.ui.notify(
                [
                    `brouter: ${brouterUrl()}`,
                    `session: ${sessionId(ctx)}`,
                    `preference: ${preference.preference ?? "none"}${preference.scope ? ` (${preference.scope})` : ""}`,
                    lastRoute
                        ? `last route: ${lastRoute.selectedModel} via ${lastRoute.provider}/${lastRoute.upstreamModel}`
                        : "last route: none",
                    lastRoute?.serviceTier
                        ? `service tier: ${lastRoute.serviceTier}`
                        : undefined,
                    lastRoute?.reasoningEffort
                        ? `reasoning: ${lastRoute.reasoningEffort}`
                        : undefined,
                    lastRoute?.eventId
                        ? `event: ${lastRoute.eventId}`
                        : undefined,
                ]
                    .filter(Boolean)
                    .join("\n"),
                "info",
            );
        },
    });

    pi.registerCommand("brouter-timeline", {
        description: "Show brouter routing timeline for this Pi session",
        handler: async (args, ctx) => {
            const id = args.trim() || sessionId(ctx);
            try {
                const events = await fetchJson(
                    `/v1/brouter/sessions/${encodeURIComponent(id)}/events`,
                );
                ctx.ui.notify(timelineLines(events).join("\n"), "info");
            } catch (error) {
                ctx.ui.notify(String(error), "warning");
            }
        },
    });

    async function setPreference(
        ctx: ExtensionContext,
        selected: Preference | undefined,
        scope: Scope = "session",
    ) {
        preference = selected ? { preference: selected, scope } : {};
        pi.appendEntry(CUSTOM_ENTRY, { route: lastRoute, preference });
        updateStatus(ctx, lastRoute, preference);
        ctx.ui.notify(
            selected
                ? `brouter preference: ${selected} (${scope})`
                : "brouter preference cleared",
            "info",
        );
    }

    pi.registerCommand("brouter-choice", {
        description:
            "Choose a stronger/faster/cheaper/slower brouter route preference",
        handler: async (args, ctx) => {
            const argPreference = preferenceFromArg(args);
            if (argPreference) {
                await setPreference(ctx, argPreference, "session");
                return;
            }
            const selected = (await ctx.ui.select("Brouter preference", [
                "balanced",
                "stronger",
                "faster",
                "cheaper",
                "slower",
                "local",
                "conserve_quota",
                "clear",
            ])) as Preference | "clear" | undefined;
            if (!selected) return;
            if (selected === "clear") {
                await setPreference(ctx, undefined);
                return;
            }
            const scope = (await ctx.ui.select("Preference scope", [
                "next",
                "session",
            ])) as Scope | undefined;
            await setPreference(ctx, selected, scope ?? "session");
        },
    });

    for (const selected of [
        "stronger",
        "faster",
        "cheaper",
        "slower",
        "local",
        "conserve_quota",
    ] as Preference[]) {
        pi.registerCommand(`brouter-${selected.replace("_", "-")}`, {
            description: `Set brouter preference to ${selected}`,
            handler: async (_args, ctx) =>
                setPreference(ctx, selected, "session"),
        });
    }

    pi.registerCommand("brouter-clear-choice", {
        description: "Clear the active brouter routing preference",
        handler: async (_args, ctx) => setPreference(ctx, undefined),
    });

    pi.registerCommand("brouter-route", {
        description: "Show the last brouter route decision for this Pi session",
        handler: async (_args, ctx) => {
            if (!lastRoute) {
                ctx.ui.notify(
                    "No brouter route has been observed yet.",
                    "info",
                );
                return;
            }

            ctx.ui.notify(
                [
                    `selected: ${lastRoute.selectedModel}`,
                    `provider: ${lastRoute.provider}`,
                    `upstream: ${lastRoute.upstreamModel}`,
                    `service tier: ${lastRoute.serviceTier ?? "default"}`,
                    `reasoning: ${lastRoute.reasoningEffort ?? "default"}`,
                    `resource pools: ${lastRoute.resourcePools.join(", ") || "none"}`,
                    `badges: ${lastRoute.badges.join(", ") || "none"}`,
                    `fallback: ${lastRoute.fallbackUsed ? "yes" : "no"}`,
                    `request: ${lastRoute.requestId ?? "unknown"}`,
                    `event: ${lastRoute.eventId ?? "unknown"}`,
                    lastRoute.summary
                        ? `summary: ${lastRoute.summary}`
                        : undefined,
                ]
                    .filter(Boolean)
                    .join("\n"),
                "info",
            );
        },
    });
}
