# OpenAI Model Aliases for Pi

Maps Pi-visible OpenAI model aliases to the raw OpenAI API request shape.

Currently:

- `gpt-5.5-fast` sends `model: "gpt-5.5"` with `service_tier: "priority"`.
- `openai-codex/gpt-6-astra` always requests `service_tier: "priority"`
  (Astra Fast); Pi still displays the built-in model name.

This matches OpenCode's `models.dev` experimental mode behavior for
`gpt-5.5-fast`.
