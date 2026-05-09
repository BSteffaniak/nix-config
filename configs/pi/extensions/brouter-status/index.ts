import type {
    ExtensionAPI,
    ExtensionContext,
} from "@mariozechner/pi-coding-agent";

const STATUS_KEY = "brouter-route";
const PROVIDER_NAME = "brouter";

type Headers = Record<string, unknown>;

type Route = {
    selectedModel: string;
    provider: string;
    upstreamModel: string;
    fallbackUsed: boolean;
    badges: string[];
};

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

function routeFromHeaders(headers: Headers): Route | undefined {
    const selectedModel = header(headers, "x-brouter-selected-model");
    const provider = header(headers, "x-brouter-provider");
    const upstreamModel = header(headers, "x-brouter-upstream-model");
    if (!selectedModel || !provider || !upstreamModel) return undefined;

    return {
        selectedModel,
        provider,
        upstreamModel,
        fallbackUsed: header(headers, "x-brouter-fallback-used") === "true",
        badges: splitHeader(header(headers, "x-brouter-display-badges")),
    };
}

function splitHeader(value: string | undefined): string[] {
    return (value ?? "")
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
}

function routeLabel(route: Route): string {
    const badges = route.badges.length > 0 ? ` ${route.badges.join(" ")}` : "";
    const fallback = route.fallbackUsed ? " fallback" : "";
    return `↗ ${route.upstreamModel}${badges}${fallback}`;
}

function updateStatus(ctx: ExtensionContext, route?: Route) {
    if (ctx.model.provider !== PROVIDER_NAME || !route) {
        ctx.ui.setStatus(STATUS_KEY, "");
        return;
    }

    ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("dim", routeLabel(route)));
}

export default function brouterStatus(pi: ExtensionAPI) {
    let lastRoute: Route | undefined;

    pi.on("session_start", async (_event, ctx) => {
        updateStatus(ctx, lastRoute);
    });

    pi.on("model_select", async (_event, ctx) => {
        lastRoute = undefined;
        updateStatus(ctx);
    });

    pi.on("after_provider_response", async (event, ctx) => {
        const route = routeFromHeaders((event.headers ?? {}) as Headers);
        if (!route) return;

        lastRoute = route;
        updateStatus(ctx, route);
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
                    `badges: ${lastRoute.badges.join(", ") || "none"}`,
                    `fallback: ${lastRoute.fallbackUsed ? "yes" : "no"}`,
                ].join("\n"),
                "info",
            );
        },
    });
}
