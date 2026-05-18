import { spawnSync } from "node:child_process";
import {
    chmodSync,
    existsSync,
    mkdirSync,
    readdirSync,
    readFileSync,
    renameSync,
    writeFileSync,
} from "node:fs";
import { join } from "node:path";

import {
    getAgentDir,
    type ExtensionAPI,
    type ExtensionContext,
} from "@mariozechner/pi-coding-agent";

// Env-var contract (set by the per-profile shell wrapper in pi.nix):
//   PI_SSHENV_PROFILE             sshenv profile name (required to activate)
//   PI_SSHENV_API_KEYS_JSON       JSON: { providerId: SSHENV_VAR_NAME }
//   PI_SSHENV_OAUTH_KEYS_JSON     JSON: { providerId: SSHENV_VAR_NAME }   value is base64(JSON({...auth.json provider entry...}))
//   PI_SSHENV_FLUSH_DEBOUNCE_MS   debounce window for OAuth round-trip (default 5000)
//   PI_SSHENV_SSHENV_BIN          override sshenv binary path (default "sshenv" via PATH)
//   PI_SSHENV_INIT_RECIPIENT_KEY  optional recipient pubkey path/value override for non-interactive `sshenv init`

type ProviderVarMap = Record<string, string>;

type ConfigBlock = {
    profile: string;
    apiKeys: ProviderVarMap;
    oauth: ProviderVarMap;
    sshenvBin: string;
    debounceMs: number;
    initRecipientKey: string | null;
};

type AuthEntry = Record<string, unknown>;
type AuthFile = Record<string, AuthEntry>;

function isMissingVaultError(stderr: string): boolean {
    return (
        /failed to read vault file/i.test(stderr) &&
        /(no such file|os error 2)/i.test(stderr)
    );
}

function isTruncatedVaultError(stderr: string): boolean {
    return /vault file is truncated/i.test(stderr);
}

function extractVaultPath(stderr: string): string | null {
    const m = stderr.match(/failed to read vault file\s+([^\n]+)/i);
    if (!m) return null;
    const path = m[1]?.trim();
    return path && path.length > 0 ? path : null;
}

function expandHome(path: string): string {
    if (path === "~") return process.env.HOME ?? path;
    if (path.startsWith("~/")) {
        const home = process.env.HOME;
        if (home) return join(home, path.slice(2));
    }
    return path;
}

function findRecipientKeyFromSshConfig(): string | null {
    const home = process.env.HOME;
    if (!home) return null;
    const sshConfig = join(home, ".ssh", "config");
    if (!existsSync(sshConfig)) return null;

    let configText = "";
    try {
        configText = readFileSync(sshConfig, "utf8");
    } catch {
        return null;
    }

    for (const rawLine of configText.split("\n")) {
        const line = rawLine.trim();
        if (!line || line.startsWith("#")) continue;
        const m = line.match(/^IdentityFile\s+(.+)$/i);
        if (!m) continue;
        const ident = m[1].trim().replace(/^"|"$/g, "");
        const pubPath = expandHome(
            ident.endsWith(".pub") ? ident : `${ident}.pub`,
        );
        if (existsSync(pubPath)) return pubPath;
    }
    return null;
}

function findRecipientKeyFromSshDir(): string | null {
    const home = process.env.HOME;
    if (!home) return null;
    const sshDir = join(home, ".ssh");
    if (!existsSync(sshDir)) return null;

    for (const name of ["id_ed25519.pub", "id_rsa.pub", "github.pub"]) {
        const p = join(sshDir, name);
        if (existsSync(p)) return p;
    }

    try {
        const entries = readdirSync(sshDir);
        const pub = entries.find((e) => e.endsWith(".pub"));
        return pub ? join(sshDir, pub) : null;
    } catch {
        return null;
    }
}

function resolveInitRecipientKey(cfg: ConfigBlock): string | null {
    if (cfg.initRecipientKey && cfg.initRecipientKey.trim().length > 0) {
        const raw = cfg.initRecipientKey.trim();
        if (raw.startsWith("ssh-")) return raw;
        return expandHome(raw);
    }
    return findRecipientKeyFromSshConfig() ?? findRecipientKeyFromSshDir();
}

function initVaultWithSshenv(cfg: ConfigBlock): {
    ok: boolean;
    stderr: string;
} {
    const recipientKey = resolveInitRecipientKey(cfg);
    if (!recipientKey) {
        return {
            ok: false,
            stderr: "no SSH recipient key found; set PI_SSHENV_INIT_RECIPIENT_KEY or configure ~/.ssh/config IdentityFile",
        };
    }
    const result = spawnSync(
        cfg.sshenvBin,
        ["init", "--recipient-key", recipientKey],
        {
            stdio: ["ignore", "ignore", "pipe"],
            encoding: "utf8",
        },
    );
    return {
        ok: result.status === 0,
        stderr: (result.stderr ?? "").toString(),
    };
}

function readEnvConfig(): ConfigBlock | null {
    const profile = process.env.PI_SSHENV_PROFILE;
    if (!profile) return null;

    let apiKeys: ProviderVarMap = {};
    let oauth: ProviderVarMap = {};
    try {
        apiKeys = JSON.parse(process.env.PI_SSHENV_API_KEYS_JSON ?? "{}");
    } catch {
        apiKeys = {};
    }
    try {
        oauth = JSON.parse(process.env.PI_SSHENV_OAUTH_KEYS_JSON ?? "{}");
    } catch {
        oauth = {};
    }

    const debounceMs = Number.parseInt(
        process.env.PI_SSHENV_FLUSH_DEBOUNCE_MS ?? "5000",
        10,
    );

    return {
        profile,
        apiKeys,
        oauth,
        sshenvBin: process.env.PI_SSHENV_SSHENV_BIN ?? "sshenv",
        debounceMs: Number.isFinite(debounceMs) ? debounceMs : 5000,
        initRecipientKey: process.env.PI_SSHENV_INIT_RECIPIENT_KEY ?? null,
    };
}

function snapshotProfile(cfg: ConfigBlock): {
    snapshot: Map<string, string>;
    profileExists: boolean;
    vaultExists: boolean;
} {
    // `sshenv export <profile>` prints `export VAR=value` lines on stdout.
    // When the profile does not exist yet (e.g. first run, before any `/login`
    // or `sshenv set`), it exits non-zero with stderr like
    //   error: no such profile: <name>
    // We treat that as "empty snapshot, profile will be created on first
    // flush" rather than a hard failure — sshenv-set auto-creates the profile
    // when we round-trip refreshed creds back later.
    const result = spawnSync(cfg.sshenvBin, ["export", cfg.profile], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
    });
    if (result.error) {
        throw new Error(
            `sshenv-auth: failed to spawn '${cfg.sshenvBin} export ${cfg.profile}': ${result.error.message}`,
        );
    }
    const stderr = (result.stderr ?? "").toString();
    if (result.status !== 0) {
        const missingVault = isMissingVaultError(stderr);
        if (missingVault) {
            const otherStderr = stderr
                .split("\n")
                .filter(
                    (l) =>
                        l.trim() &&
                        !/failed to read vault file/i.test(l) &&
                        !/(no such file|os error 2)/i.test(l),
                )
                .join("\n");
            if (otherStderr) process.stderr.write(otherStderr + "\n");
            return {
                snapshot: new Map(),
                profileExists: false,
                vaultExists: false,
            };
        }
        if (/no such profile/i.test(stderr)) {
            // Surface the underlying stderr lines that aren't the
            // "no such profile" line itself (e.g. ssh-agent prompts), so the
            // user sees them but we still continue.
            const otherStderr = stderr
                .split("\n")
                .filter((l) => l.trim() && !/no such profile/i.test(l))
                .join("\n");
            if (otherStderr) process.stderr.write(otherStderr + "\n");
            return {
                snapshot: new Map(),
                profileExists: false,
                vaultExists: true,
            };
        }
        // Real error: vault locked, sshenv binary missing, etc. Surface and
        // throw so the caller can decide whether to abort or continue.
        if (stderr) process.stderr.write(stderr);
        throw new Error(
            `sshenv-auth: '${cfg.sshenvBin} export ${cfg.profile}' exited ${result.status ?? "?"}`,
        );
    }
    // Pass-through any stderr (e.g. ssh-agent unlock prompts) on success.
    if (stderr) process.stderr.write(stderr);
    const stdout = (result.stdout ?? "").toString();

    const out = new Map<string, string>();
    for (const rawLine of stdout.split("\n")) {
        const line = rawLine.replace(/^export\s+/, "").trim();
        if (!line || !line.includes("=")) continue;
        const eq = line.indexOf("=");
        const key = line.slice(0, eq);
        let value = line.slice(eq + 1);
        // Strip a single layer of surrounding quotes if present.
        if (
            (value.startsWith("'") && value.endsWith("'")) ||
            (value.startsWith('"') && value.endsWith('"'))
        ) {
            value = value.slice(1, -1);
        }
        out.set(key, value);
    }
    return { snapshot: out, profileExists: true, vaultExists: true };
}

function readAuth(authPath: string): AuthFile {
    if (!existsSync(authPath)) return {};
    try {
        const txt = readFileSync(authPath, "utf8");
        const parsed = JSON.parse(txt) as unknown;
        if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
            return parsed as AuthFile;
        }
    } catch {
        // fall through
    }
    return {};
}

function writeAuthAtomic(authPath: string, data: AuthFile): void {
    const dir = authPath.endsWith("/auth.json")
        ? authPath.slice(0, -"/auth.json".length)
        : authPath;
    mkdirSync(dir, { recursive: true });
    const tmp = `${authPath}.sshenv-auth.tmp`;
    writeFileSync(tmp, JSON.stringify(data, null, 2));
    chmodSync(tmp, 0o600);
    renameSync(tmp, authPath);
}

function decodeOAuthBlob(b64: string): AuthEntry | null {
    if (!b64) return null;
    try {
        const json = Buffer.from(b64, "base64").toString("utf8");
        const parsed = JSON.parse(json) as unknown;
        if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
            return parsed as AuthEntry;
        }
    } catch {
        // fall through
    }
    return null;
}

function encodeOAuthBlob(entry: AuthEntry): string {
    return Buffer.from(JSON.stringify(entry), "utf8").toString("base64");
}

function materializeAuthFromSshenv(
    cfg: ConfigBlock,
    snapshot: Map<string, string>,
    authPath: string,
): { wrote: boolean; missing: string[] } {
    const before = readAuth(authPath);
    const after: AuthFile = { ...before };
    const missing: string[] = [];

    for (const [providerId, varName] of Object.entries(cfg.apiKeys)) {
        const v = snapshot.get(varName);
        if (v && v.length > 0) {
            after[providerId] = { type: "api_key", key: v };
        } else if (!(providerId in after)) {
            missing.push(`${providerId} (api_key from ${varName})`);
        }
    }

    for (const [providerId, varName] of Object.entries(cfg.oauth)) {
        const blob = snapshot.get(varName);
        const decoded = blob ? decodeOAuthBlob(blob) : null;
        if (decoded) {
            after[providerId] = decoded;
        } else if (!(providerId in after)) {
            missing.push(`${providerId} (oauth from ${varName})`);
        }
    }

    const wrote = JSON.stringify(before) !== JSON.stringify(after);
    if (wrote) writeAuthAtomic(authPath, after);
    return { wrote, missing };
}

function flushOAuthToSshenv(
    cfg: ConfigBlock,
    authPath: string,
    lastFlushed: Map<string, string>,
): { updated: string[]; errors: string[] } {
    const auth = readAuth(authPath);
    const updated: string[] = [];
    const errors: string[] = [];

    for (const [providerId, varName] of Object.entries(cfg.oauth)) {
        const entry = auth[providerId];
        if (!entry || typeof entry !== "object") continue;
        const encoded = encodeOAuthBlob(entry);
        if (lastFlushed.get(varName) === encoded) continue;
        const result = spawnSync(
            cfg.sshenvBin,
            ["set", cfg.profile, varName, "--value", encoded],
            { stdio: ["ignore", "ignore", "pipe"] },
        );
        if (result.status === 0) {
            lastFlushed.set(varName, encoded);
            updated.push(varName);
        } else {
            const stderr = result.stderr?.toString() ?? "";
            if (isMissingVaultError(stderr)) {
                const init = initVaultWithSshenv(cfg);
                if (!init.ok) {
                    const vaultPath = extractVaultPath(stderr);
                    const initErr = init.stderr.trim() || "unknown init error";
                    errors.push(
                        `${varName}: missing vault${vaultPath ? ` (${vaultPath})` : ""}; failed to initialize vault via '${cfg.sshenvBin} init --recipient-key <auto>': ${initErr}`,
                    );
                    continue;
                }

                const retry = spawnSync(
                    cfg.sshenvBin,
                    ["set", cfg.profile, varName, "--value", encoded],
                    { stdio: ["ignore", "ignore", "pipe"] },
                );
                if (retry.status === 0) {
                    lastFlushed.set(varName, encoded);
                    updated.push(varName);
                } else {
                    const retryStderr = retry.stderr?.toString() ?? "";
                    errors.push(
                        `${varName}: ${retryStderr.trim() || `exit ${retry.status}`} (after vault bootstrap)`,
                    );
                }
            } else {
                if (isTruncatedVaultError(stderr)) {
                    errors.push(
                        `${varName}: ${stderr.trim()} (vault is corrupted/truncated; repair by moving it aside and running '${cfg.sshenvBin} init')`,
                    );
                    continue;
                }
                errors.push(
                    `${varName}: ${stderr.trim() || `exit ${result.status}`}`,
                );
            }
        }
    }
    return { updated, errors };
}

export default async function (pi: ExtensionAPI): Promise<void> {
    const cfg = readEnvConfig();
    if (!cfg) return; // No-op when not invoked via a sshenv-aware wrapper.

    const agentDir = getAgentDir();
    const authPath = join(agentDir, "auth.json");

    // Track what we last successfully flushed so we don't no-op write.
    const lastFlushed = new Map<string, string>();

    // 1. Snapshot the sshenv profile and materialize auth.json BEFORE any
    //    provider request runs. The async extension factory is awaited by pi
    //    before session_start and before the first AuthStorage read, so this
    //    is the right place to do it.
    //
    //    If the profile doesn't exist yet, we proceed with an empty snapshot.
    //    The first OAuth refresh / `sshenv-flush` will create the profile via
    //    `sshenv set`, which auto-creates missing profiles + vars.
    let snapshot: Map<string, string>;
    let profileExists: boolean;
    let vaultExists: boolean;
    try {
        ({ snapshot, profileExists, vaultExists } = snapshotProfile(cfg));
    } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        // Real error (vault locked, binary missing, etc.). Don't crash pi — the
        // user can still use providers with creds already in auth.json or env
        // vars. Just log loudly and skip the round-trip hooks.
        // eslint-disable-next-line no-console
        console.error(msg);
        return;
    }
    const { wrote, missing } = materializeAuthFromSshenv(
        cfg,
        snapshot,
        authPath,
    );

    if (!vaultExists && missing.length > 0) {
        // eslint-disable-next-line no-console
        console.error(
            "sshenv-auth: vault file not found yet — it will be created automatically on first flush after /login.",
        );
    } else if (!profileExists && missing.length > 0) {
        // eslint-disable-next-line no-console
        console.error(
            `sshenv-auth: profile '${cfg.profile}' not found in vault yet — it will be created automatically on first flush after /login.`,
        );
    }

    // Seed lastFlushed from what we just wrote so the first refresh genuinely
    // diffs against the on-disk state.
    for (const [providerId, varName] of Object.entries(cfg.oauth)) {
        const entry = readAuth(authPath)[providerId];
        if (entry && typeof entry === "object") {
            lastFlushed.set(varName, encodeOAuthBlob(entry));
        }
    }

    // 2. Debounced flush on each provider response. Captures mid-session OAuth
    //    refresh writes by pi's AuthStorage. Skipped entirely when oauth map
    //    is empty.
    let flushTimer: ReturnType<typeof setTimeout> | null = null;
    const scheduleFlush = (): void => {
        if (Object.keys(cfg.oauth).length === 0) return;
        if (flushTimer) clearTimeout(flushTimer);
        flushTimer = setTimeout(() => {
            flushTimer = null;
            const { errors } = flushOAuthToSshenv(cfg, authPath, lastFlushed);
            if (errors.length > 0) {
                // eslint-disable-next-line no-console
                console.error(
                    `sshenv-auth: flush errors for profile '${cfg.profile}': ${errors.join("; ")}`,
                );
            }
        }, cfg.debounceMs);
    };

    pi.on("after_provider_response", async () => {
        scheduleFlush();
    });

    // 3. Final synchronous flush on shutdown, then optional plaintext wipe.
    pi.on("session_shutdown", async () => {
        if (flushTimer) {
            clearTimeout(flushTimer);
            flushTimer = null;
        }
        const { errors } = flushOAuthToSshenv(cfg, authPath, lastFlushed);
        if (errors.length > 0) {
            // eslint-disable-next-line no-console
            console.error(
                `sshenv-auth: shutdown flush errors for profile '${cfg.profile}': ${errors.join("; ")}`,
            );
        }
    });

    // 4. Status command for visibility.
    pi.registerCommand("sshenv-status", {
        description:
            "Show sshenv-auth status: profile, tracked providers, last sync state",
        handler: async (_args: string, ctx: ExtensionContext) => {
            const apiKeyList = Object.keys(cfg.apiKeys).join(", ") || "(none)";
            const oauthList = Object.keys(cfg.oauth).join(", ") || "(none)";
            const flushed =
                Array.from(lastFlushed.keys()).join(", ") || "(none)";
            ctx.ui.notify(
                [
                    `sshenv profile: ${cfg.profile}`,
                    `agent dir:      ${agentDir}`,
                    `api_key providers: ${apiKeyList}`,
                    `oauth providers:   ${oauthList}`,
                    `last flushed vars: ${flushed}`,
                    vaultExists
                        ? profileExists
                            ? wrote
                                ? "auth.json was updated from sshenv on startup."
                                : "auth.json already matched sshenv on startup."
                            : `profile '${cfg.profile}' will be created in the vault on first flush.`
                        : "vault file will be created on first flush.",
                    missing.length > 0
                        ? `missing creds (run /login): ${missing.join(", ")}`
                        : "all configured providers have credentials.",
                ].join("\n"),
                "info",
            );
        },
    });

    pi.registerCommand("sshenv-flush", {
        description:
            "Force an immediate flush of auth.json OAuth credentials back to sshenv",
        handler: async (_args: string, ctx: ExtensionContext) => {
            if (flushTimer) {
                clearTimeout(flushTimer);
                flushTimer = null;
            }
            const { updated, errors } = flushOAuthToSshenv(
                cfg,
                authPath,
                lastFlushed,
            );
            if (errors.length > 0) {
                ctx.ui.notify(
                    `sshenv-auth: flush errors: ${errors.join("; ")}`,
                    "warning",
                );
            } else if (updated.length === 0) {
                ctx.ui.notify("sshenv-auth: nothing to flush.", "info");
            } else {
                ctx.ui.notify(
                    `sshenv-auth: flushed ${updated.join(", ")} to profile '${cfg.profile}'.`,
                    "info",
                );
            }
        },
    });
}
