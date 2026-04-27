import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

type Payload = {
    model?: unknown;
    service_tier?: unknown;
    [key: string]: unknown;
};

type ModelLike = {
    provider?: unknown;
    id?: unknown;
    name?: unknown;
};

type ContextLike = {
    model?: ModelLike;
};

const aliases: Record<string, { model: string; serviceTier?: string }> = {
    "gpt-5.5-fast": {
        model: "gpt-5.5",
        serviceTier: "priority",
    },
};

function selectedFastAlias(ctx: ContextLike): boolean {
    const model = ctx.model;
    return (
        model?.provider === "openai-codex" &&
        model.id === "gpt-5.5" &&
        model.name === "gpt-5.5-fast"
    );
}

export default function openaiModelAliases(pi: ExtensionAPI): void {
    pi.on("before_provider_request", (event, ctx) => {
        const payload = event.payload as Payload;
        if (typeof payload.model !== "string") return undefined;

        const alias = aliases[payload.model];
        const serviceTier =
            alias?.serviceTier ??
            (selectedFastAlias(ctx as ContextLike) ? "priority" : undefined);
        if (!alias && !serviceTier) return undefined;

        return {
            ...payload,
            model: alias?.model ?? payload.model,
            ...(serviceTier ? { service_tier: serviceTier } : {}),
        };
    });
}
