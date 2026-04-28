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

## Backends

- macOS: `/usr/bin/say`
- Linux: `espeak-ng`, falling back to `espeak`

Environment overrides:

- `PI_READ_REPLY_RATE` — speech rate (`say -r` or `espeak -s`)
- `PI_READ_REPLY_MAX_CHARS` — maximum characters to read before truncating (default: `6000`)

The extension strips markdown formatting, omits fenced code blocks, and truncates long replies so it does not read forever.

After deploying through home-manager, run `/reload` in Pi or restart Pi to load the extension.
