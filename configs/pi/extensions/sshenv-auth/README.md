# sshenv-auth

Resolve pi's `auth.json` from an [`sshenv`](https://github.com/BSteffaniak/sshenv) vault at session start, and round-trip refreshed OAuth credentials back to the vault. Activated when the per-profile shell wrapper sets `PI_SSHENV_PROFILE`; otherwise the extension is a no-op.

The Nix module at `home/modules/development/pi.nix` reads `configs/pi/providers/*.json`. When a descriptor includes an `sshenv` block, the generated `pi-<name>` wrapper points pi at a per-profile `PI_CODING_AGENT_DIR` for auth/config, symlinks that profile's `sessions/` directory to the shared default `~/.pi/agent/sessions`, then exports the env-var contract this extension consumes. Descriptors without an `sshenv` block keep their original behavior (raw `pi --provider … --model …`).

## What it does

1. **Snapshot at startup.** Calls `sshenv export <profile>` once during the async extension factory (which pi awaits before any provider request). Parses the resulting `export VAR=value` lines into a map.
2. **Materializes `auth.json`.** Atomically writes `$PI_CODING_AGENT_DIR/auth.json` with one entry per configured provider:
   - `apiKeys.<providerId> = "<VAR>"` becomes `{ "type": "api_key", "key": "<value-of-VAR>" }`.
   - `oauth.<providerId> = "<VAR>"` is `base64(JSON({...auth.json provider entry...}))` in the vault. The extension decodes it and merges the entry verbatim under `<providerId>`.
3. **Debounced flush during the session.** On every `after_provider_response`, schedules a `sshenv set <profile> <VAR> --value <base64>` for each OAuth provider. The debounce window is `PI_SSHENV_FLUSH_DEBOUNCE_MS` (default 5000). This captures mid-session OAuth refreshes that pi's AuthStorage writes to `auth.json`.
4. **Final flush on shutdown.** On `session_shutdown` (Ctrl+C / Ctrl+D / SIGHUP / SIGTERM / `/q`), cancels any pending debounce and flushes synchronously.
5. **Skips no-op writes.** Tracks the last successfully flushed value per VAR; if `auth.json`'s entry hasn't changed, no `sshenv set` call is made.

## Env-var contract (set by the wrapper)

| Variable                       | Purpose                                                                                                                                      |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `PI_SSHENV_PROFILE`            | sshenv profile name. Activates the extension.                                                                                                |
| `PI_SSHENV_API_KEYS_JSON`      | JSON `{ providerId: SSHENV_VAR_NAME }` for raw API keys.                                                                                     |
| `PI_SSHENV_OAUTH_KEYS_JSON`    | JSON `{ providerId: SSHENV_VAR_NAME }` for OAuth blobs.                                                                                      |
| `PI_SSHENV_FLUSH_DEBOUNCE_MS`  | Optional. Default `5000`.                                                                                                                    |
| `PI_SSHENV_SSHENV_BIN`         | Optional. Path to the `sshenv` binary. Defaults to `sshenv` from PATH.                                                                       |
| `PI_SSHENV_INIT_RECIPIENT_KEY` | Optional recipient key path/value override used for non-interactive `sshenv init` during first-run vault bootstrap.                          |
| `SSHENV_VAULT`                 | Per-profile vault path, defaulting to `~/.local/state/pi/sshenv/<profile>/vault`, so each profile has isolated vault state.                  |
| `PI_CODING_AGENT_DIR`          | Standard pi env var. The wrapper points it at a per-profile dir under `~/.pi/<name>/agent` so different profiles never share an `auth.json`. |
| `PI_CODING_AGENT_SESSION_DIR`  | Standard pi env var. The wrapper does not set it by default; if you set it yourself, pi honors that explicit session-dir override.           |

## Concurrency

By construction, two pi instances on different profiles use different agent dirs, different `auth.json` files, and different sshenv profiles. Their per-profile `sessions/` directories are symlinked to the same default root (`~/.pi/agent/sessions`), so `/resume` and `pi -c` see the same history for the current working directory across provider wrappers without showing sessions from unrelated directories.

Two pi instances on the **same** profile share `auth.json`. The common case (neither refreshes during their session) works fine; OpenAI doesn't reject parallel use of the same access token. The rare case (both refresh simultaneously) is a brief race that pi's own retry logic handles. The extension does **not** lock by default. Set `PI_SSHENV_LOCK=1` in the wrapper environment to opt into serialization (handled in the wrapper, not here).

For heavy parallel use of one ChatGPT subscription, route through brouter (`pi-brouter`) instead — brouter holds OAuth centrally so refresh races don't happen.

## Commands

- `/sshenv-status` — print the active profile, tracked providers, agent dir, and last-flushed state.
- `/sshenv-flush` — force an immediate flush. Useful right after `/login`.

## Provider descriptor format

Descriptors live in two places:

- `configs/pi/providers/<name>.json` — in-repo, public.
- `myConfig.development.pi.extraProviders.<name>` in a host home.nix — inline. Useful for encrypted hosts (`hosts/bs-mbpro/` is git-sshripped) so private profiles never appear in plaintext on GitHub. Inline entries win on name collisions.

Both use the same shape:

```json
{
  "provider": "openai-codex",
  "model": "gpt-5.5",
  "thinking": "high",
  "sshenv": {
    "profile": "openai",
    "agentSubdir": "openai",
    "vaultPath": "~/.local/state/pi/sshenv/openai/vault",
    "initRecipientKey": "~/.ssh/github.pub",
    "oauth": {
      "openai-codex": "OPENAI_CODEX_AUTH_JSON_B64"
    },
    "apiKeys": {}
  }
}
```

- `profile` — sshenv profile name passed to the extension via `PI_SSHENV_PROFILE`.
- `agentSubdir` — directory under `~/.pi/` for this wrapper's agent dir. Defaults to `profile` when omitted.
- `vaultPath` — optional per-profile vault path exported as `SSHENV_VAULT`. Defaults to `~/.local/state/pi/sshenv/<profile>/vault`.
- `initRecipientKey` — optional recipient key path/value override for first-run `sshenv init`. If omitted, the extension auto-discovers a key from `~/.ssh/config` `IdentityFile` entries, then falls back to common `~/.ssh/*.pub` keys.
- `oauth` — `{ providerId: SSHENV_VAR_NAME }`. The vault var must hold `base64(JSON({...auth.json provider entry...}))`.
- `apiKeys` — `{ providerId: SSHENV_VAR_NAME }`. The vault var holds the raw API key string.

## Bootstrap recipe

### One-time: clean up legacy `auth.json` and stale `OPENAI_API_KEY`

```sh
# We no longer use OpenAI API key for pi; pi now uses the ChatGPT subscription
# OAuth flow per profile. Drop the old key from the openai sshenv profile if it
# was placed there, and clear the legacy default-agent auth.json.
sshenv unset openai OPENAI_API_KEY 2>/dev/null || true
jq 'del(."openai-codex")' ~/.pi/agent/auth.json > ~/.pi/agent/auth.json.tmp \
  && mv ~/.pi/agent/auth.json.tmp ~/.pi/agent/auth.json
```

### ChatGPT subscription profile (`openai`, plus host-only accounts via `extraProviders`)

```sh
# 1. Launch pi via the new wrapper. No setup needed; on a true first run the
#    extension tolerates missing per-profile SSHENV_VAULT, runs `sshenv init`,
#    and then creates profile/var on the first flush after /login.
pi-openai

# 2. Inside pi:
> /login openai-codex          # browser OAuth
> /sshenv-flush                # immediate write-back to vault
> /q

# 3. Confirm the vault now holds the OAuth blob.
sshenv list openai             # should include OPENAI_CODEX_AUTH_JSON_B64
```

Repeat for any host-specific account defined via `extraProviders`. Use the `-fast` wrapper variant when you want the priority-tier alias:

```sh
pi-<private-profile>
# or: pi-<private-profile>-fast
> /login openai-codex
> /sshenv-flush
> /q
```

### API-key profiles (`openrouter`, `zen`, `xai`)

The sshenv profile likely already has the API key from the previous shim-based
flow. The new wrapper reads it directly:

```sh
# Already populated:
sshenv list openrouter         # OPENROUTER_API_KEY
sshenv list opencode-zen       # OPENCODE_API_KEY
sshenv list xai                # XAI_API_KEY

# Just launch:
pi-openrouter
pi-zen
pi-grok-4.3
pi-grok-code-fast
```

## What lives where

- Plaintext `auth.json` exists only inside `~/.pi/<profile>/agent/` (mode 0600), and only while the wrapper is running.
- The per-profile vault file (`SSHENV_VAULT`, default `~/.local/state/pi/sshenv/<profile>/vault`) is the durable store. Refreshed OAuth tokens are flushed back to it during the session and on exit.
- Sessions persist in shared `~/.pi/agent/sessions/` by default via `~/.pi/<profile>/agent/sessions` symlinks, so pi keeps its normal working-directory organization while profiles share the same project history. Set `PI_CODING_AGENT_SESSION_DIR` before invoking a wrapper if you want a different shared or isolated session root.
- Per-profile auth remains in `~/.pi/<profile>/agent/auth.json`; shared static config is symlinked from `~/.pi/agent/` into the per-profile agent dir.
