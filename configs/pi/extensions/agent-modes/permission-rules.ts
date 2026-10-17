export type Action = "allow" | "deny" | "ask";
export type ModeName = "build" | "plan";

export type ModeConfig = {
    tools?: Record<string, boolean>;
    permission?: {
        bash?: Record<string, Action>;
        external_directory?: Action;
    };
};

export type PermissionConfig = {
    agent?: Record<string, ModeConfig>;
};

export type Rule = {
    pattern: string;
    action: Action;
    regex: RegExp;
    specificity: number;
};

export function globToRegex(pattern: string): RegExp {
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

export function ruleSpecificity(pattern: string): number {
    const nonWildcardChars = pattern.replaceAll("*", "").length;
    const exactBonus = pattern.includes("*") ? 0 : 1000;
    return exactBonus + nonWildcardChars;
}

export function compileRules(config: ModeConfig): Rule[] {
    return Object.entries(config.permission?.bash ?? {}).map(
        ([pattern, action]) => ({
            pattern,
            action,
            regex: globToRegex(pattern),
            specificity: ruleSpecificity(pattern),
        }),
    );
}

export function matchingRule(command: string, rules: Rule[]): Rule | undefined {
    return rules
        .filter((rule) => rule.regex.test(command))
        .sort(
            (a, b) =>
                b.specificity - a.specificity ||
                b.pattern.length - a.pattern.length,
        )[0];
}

export function commandParts(command: string): string[] {
    const parts = command
        .split(/\s*(?:&&|\|\||;|\|)\s*/)
        .map((part) => part.trim())
        .filter(Boolean);
    return parts.length > 0 ? parts : [command];
}

export function deniedCommandPart(
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
