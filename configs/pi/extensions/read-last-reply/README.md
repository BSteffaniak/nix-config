# Read Last Reply

Pi extension for having the latest assistant response read aloud, useful for hands-free sessions.

## Shortcuts

- `Ctrl+Alt+R` — read the last assistant reply
- `Ctrl+Alt+X` — stop reading

## Commands

- `/speak-last` — read the last assistant reply
- `/speak-stop` — stop reading
- `/speak-auto` — toggle auto-reading completed assistant text replies
- `/speak-auto on` — enable auto-read
- `/speak-auto off` — disable auto-read

## Audio adapter

Before TTS, the extension can rewrite an assistant reply into a more natural spoken script. This is useful for code blocks, markdown tables, file paths, commands, and dense technical lists.

Adapter selection:

- `PI_READ_REPLY_AUDIO_ADAPTER=off` — no rewrite; legacy markdown cleanup only
- `PI_READ_REPLY_AUDIO_ADAPTER=heuristic` — local code-block summaries, no API call
- `PI_READ_REPLY_AUDIO_ADAPTER=llm` — use a fast model to rewrite for audio, with heuristic fallback

The Nix-managed Pi module enables the LLM adapter by default:

- `PI_READ_REPLY_AUDIO_ADAPTER=llm`
- `PI_READ_REPLY_AUDIO_ADAPTER_PROVIDER=openai`
- `PI_READ_REPLY_AUDIO_ADAPTER_MODEL=gpt-4o-mini`

If that model or API key is unavailable, the extension falls back to the current Pi model when possible, then to the heuristic adapter.

## Backends

Backend selection:

- `PI_READ_REPLY_BACKEND=auto` — default; prefer Piper when configured, otherwise local fallback
- `PI_READ_REPLY_BACKEND=piper` — require Piper
- `PI_READ_REPLY_BACKEND=local` — use macOS `say` or Linux `espeak-ng`/`espeak`

Piper is configured separately by the general Home Manager TTS module:

```nix
myConfig.tools.tts.piper.enable = true;
```

That module installs `piper`, a default voice, the `tts-say` helper, and exports:

- `TTS_BACKEND=piper`
- `PIPER_VOICE=~/.local/share/tts/piper/voices/en_US-ryan-high.onnx`
- `PIPER_VOICE_CONFIG=~/.local/share/tts/piper/voices/en_US-ryan-high.onnx.json`

The extension also supports Pi-specific overrides:

- `PI_READ_REPLY_PIPER_MODEL`
- `PI_READ_REPLY_PIPER_CONFIG`
- `PI_READ_REPLY_AUDIO_PLAYER`

Local fallback:

- macOS: `/usr/bin/say`
- Linux: `espeak-ng`, falling back to `espeak`

Environment overrides:

- `PI_READ_REPLY_RATE` — speech rate for local fallback (`say -r` or `espeak -s`)
- `PI_READ_REPLY_VOICE` — macOS `say` voice for local fallback
- `PI_READ_REPLY_MAX_CHARS` — maximum characters to read before truncating (default: `6000`)
- `PI_READ_REPLY_PIPER_LENGTH_SCALE` / `PIPER_LENGTH_SCALE`
- `PI_READ_REPLY_PIPER_NOISE_SCALE` / `PIPER_NOISE_SCALE`
- `PI_READ_REPLY_PIPER_NOISE_W_SCALE` / `PIPER_NOISE_W_SCALE`
- `PI_READ_REPLY_PIPER_SENTENCE_SILENCE` / `PIPER_SENTENCE_SILENCE`
- `PI_READ_REPLY_PIPER_VOLUME` / `PIPER_VOLUME`

The extension strips residual markdown formatting and truncates long adapted scripts so it does not read forever.

After deploying through home-manager, restart Pi from a fresh shell to pick up the Piper package and environment variables. `/reload` is enough only for extension code changes inside an already-correct environment.
