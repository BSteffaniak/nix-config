# Figma Tool Gate

Keeps `pi-figma-mcp` tools disabled by default so non-design sessions do not drift into Figma context.

Commands:

- `/figma-on` enables `figma_*` tools for the current session.
- `/figma-off` disables them again.
- `/figma-status` reports the current gate state and discovered Figma tools.

While disabled, the extension removes Figma MCP tools from Pi's active tool list, filters the package's hidden Figma hint out of model context, and blocks accidental `figma_*` tool calls as a fallback.
