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

type RoutingEvent = {
    timestamp_ms?: number;
    kind?: string;
    request_id?: string;
    event_id?: string;
    payload?: Record<string, unknown>;
};

function asRecord(value: unknown): Record<string, unknown> {
    return value && typeof value === "object"
        ? (value as Record<string, unknown>)
        : {};
}

function asArray(value: unknown): unknown[] {
    return Array.isArray(value) ? value : [];
}

function timelineLines(events: unknown): string[] {
    if (!Array.isArray(events) || events.length === 0)
        return ["No brouter events."];
    return events.slice(-25).flatMap((event) => {
        const item = event as RoutingEvent;
        const payload = item.payload ?? {};
        if (item.kind === "route_decision") {
            const controls = asRecord(payload.request_controls);
            const features = asRecord(payload.features);
            const judgeTrigger = asRecord(payload.judge_trigger);
            const judge = asRecord(payload.judge);
            const lines = [
                [
                    `${item.timestamp_ms ?? ""} route`,
                    String(payload.selected_model ?? "<unknown>"),
                    `tier=${String(controls.service_tier ?? "default")}`,
                    `reasoning=${String(controls.reasoning_effort ?? "default")}`,
                    `intent=${String(features.intent ?? "unknown")}/${String(features.reasoning ?? "unknown")}`,
                    `judge=${judgeTrigger.fired ? "fired" : "skipped"}`,
                ].join("  "),
            ];
            if (judge.rationale) {
                lines.push(`  judge why: ${String(judge.rationale)}`);
            }
            const top = asArray(payload.candidates)
                .slice(0, 2)
                .map((candidate) =>
                    String(asRecord(candidate).model_id ?? "<unknown>"),
                )
                .join(" vs ");
            if (top) lines.push(`  candidates: ${top}`);
            return lines;
        }
        if (item.kind === "provider_attempt") {
            return [
                `${item.timestamp_ms ?? ""} attempt  ${String(payload.model_id ?? "<unknown>")} status=${String(payload.status_code ?? "error")} fallback=${String(payload.fallback_used ?? false)}`,
            ];
        }
        return [
            `${item.timestamp_ms ?? ""} ${item.kind ?? "event"} ${item.event_id ?? ""}`,
        ];
    });
}

function whyLines(event: unknown): string[] {
    const item = event as RoutingEvent;
    const payload = item.payload ?? {};
    const controls = asRecord(payload.request_controls);
    const features = asRecord(payload.features);
    const sources = asRecord(payload.control_sources);
    const judgeTrigger = asRecord(payload.judge_trigger);
    const judge = asRecord(payload.judge);
    const lines = [
        `selected: ${String(payload.selected_model ?? "<unknown>")}`,
        `provider: ${String(payload.provider ?? "<unknown>")}`,
        `upstream: ${String(payload.upstream_model ?? "<unknown>")}`,
        `intent/reasoning: ${String(features.intent ?? "unknown")}/${String(features.reasoning ?? "unknown")}`,
        `controls: service_tier=${String(controls.service_tier ?? "default")} (${String(sources.service_tier ?? "unknown")}), reasoning_effort=${String(controls.reasoning_effort ?? "default")} (${String(sources.reasoning_effort ?? "unknown")})`,
        `judge: ${judgeTrigger.fired ? "fired" : "skipped"} gap=${String(judgeTrigger.score_gap ?? "unknown")} reason=${String(judgeTrigger.reason ?? "unknown")}`,
    ];
    const reasons = asArray(payload.reasons).map(String).filter(Boolean);
    if (reasons.length > 0) lines.push(`router why: ${reasons.join("; ")}`);
    if (Object.keys(judge).length > 0) {
        lines.push(
            `judge result: ${String(judge.model ?? "unknown")} chose ${String(judge.chosen_model ?? "unknown")} overridden=${String(judge.overridden ?? false)}`,
        );
        if (judge.rationale)
            lines.push(`judge why: ${String(judge.rationale)}`);
    }
    const candidates = asArray(payload.candidates).slice(0, 4);
    if (candidates.length > 0) {
        lines.push("top candidates:");
        const first = asRecord(candidates[0]);
        const topScore = Number(first.score ?? 0);
        for (const candidateValue of candidates) {
            const candidate = asRecord(candidateValue);
            const score = Number(candidate.score ?? 0);
            const delta = score - topScore;
            const reasons = asArray(candidate.reasons).map(String).join("; ");
            lines.push(
                `  ${String(candidate.model_id ?? "<unknown>")}: score=${score.toFixed(2)} Δ=${delta.toFixed(2)} cost=${String(candidate.estimated_cost ?? "?")} ${reasons}`,
            );
        }
    }
    const excluded = asArray(payload.excluded_candidates).slice(0, 5);
    if (excluded.length > 0) {
        lines.push("excluded:");
        for (const excludedValue of excluded) {
            const item = asRecord(excludedValue);
            lines.push(
                `  ${String(item.model_id ?? "<unknown>")}: ${String(item.reason ?? "unknown")}`,
            );
        }
    }
    return lines;
}

async function latestRouteDecisionEvent(
    session: string,
    requestId?: string,
): Promise<unknown | undefined> {
    const events = await fetchJson(
        `/v1/brouter/sessions/${encodeURIComponent(session)}/events`,
    );
    if (!Array.isArray(events)) return undefined;
    return [...events].reverse().find((event) => {
        const item = event as RoutingEvent;
        return (
            item.kind === "route_decision" &&
            (!requestId || item.request_id === requestId)
        );
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

    pi.registerCommand("brouter-why", {
        description:
            "Show why brouter selected the latest model/tier/reasoning",
        handler: async (_args, ctx) => {
            try {
                const event = await latestRouteDecisionEvent(
                    sessionId(ctx),
                    lastRoute?.requestId,
                );
                if (!event) {
                    ctx.ui.notify(
                        "No brouter route decision has been observed yet.",
                        "info",
                    );
                    return;
                }
                ctx.ui.notify(whyLines(event).join("\n"), "info");
            } catch (error) {
                ctx.ui.notify(String(error), "warning");
            }
        },
    });

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
