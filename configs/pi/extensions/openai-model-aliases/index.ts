import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

type Payload = {
    model?: unknown;
    service_tier?: unknown;
    [key: string]: unknown;
};

const aliases: Record<string, { model: string; serviceTier?: string }> = {
    "gpt-5.5-fast": {
        model: "gpt-5.5",
        serviceTier: "priority",
    },
};

export default function openaiModelAliases(pi: ExtensionAPI): void {
    pi.on("before_provider_request", (event) => {
        const payload = event.payload as Payload;
        if (typeof payload.model !== "string") return undefined;

        const alias = aliases[payload.model];
        if (!alias) return undefined;

        return {
            ...payload,
            model: alias.model,
            ...(alias.serviceTier ? { service_tier: alias.serviceTier } : {}),
        };
    });
}
