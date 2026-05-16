# brouter-status

Pi extension for brouter route visibility and lightweight routing correction.

## What it does

- Injects stable Pi session metadata into brouter requests:
  - `metadata.session_id`
  - `metadata.brouter_session_id`
  - `metadata.brouter_client = "pi"`
  - optional `metadata.brouter_preference`
- Reads brouter response headers and shows the latest route in the status area.
- Persists compact route/preference state in Pi custom session entries.
- Fetches brouter session timelines from `GET /v1/brouter/sessions/<id>/events`.

Set `BROUTER_URL` to override the default `http://127.0.0.1:8080`.
Set `BROUTER_EXTENSION_ALWAYS=1` to inject metadata into every provider payload; by default the extension only injects for `auto`, `brouter/auto`, `profile:*`, and `group:*` payloads.

## Commands

- `/brouter-status` — show brouter URL, Pi session id, active preference, last route, and event id.
- `/brouter-route` — show detailed latest route headers.
- `/brouter-timeline [session-id]` — show recent brouter events for this Pi session, or for an explicit session id.
- `/brouter-choice` — interactively choose `balanced`, `stronger`, `faster`, `cheaper`, `slower`, `local`, `conserve_quota`, or clear.
- `/brouter-choice stronger` — set a preference directly.
- `/brouter-stronger`, `/brouter-faster`, `/brouter-cheaper`, `/brouter-slower`, `/brouter-local`, `/brouter-conserve-quota` — convenience commands.
- `/brouter-clear-choice` — clear the active routing preference.
