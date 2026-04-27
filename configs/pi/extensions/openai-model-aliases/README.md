# OpenAI Model Aliases for Pi

Maps Pi-visible OpenAI model aliases to the raw OpenAI API request shape.

Currently:

- `gpt-5.5-fast` sends `model: "gpt-5.5"` with `service_tier: "priority"`.

This matches OpenCode's `models.dev` experimental mode behavior for
`gpt-5.5-fast`.
