# brouter-status

Shows the last brouter route decision in Pi's footer/status area.

The extension reads brouter's OpenAI-compatible response headers:

- `x-brouter-selected-model`
- `x-brouter-provider`
- `x-brouter-upstream-model`
- `x-brouter-fallback-used`
- `x-brouter-display-badges`

It does not inject anything into the conversation context.

Use `/brouter-route` to show the most recent route details.
