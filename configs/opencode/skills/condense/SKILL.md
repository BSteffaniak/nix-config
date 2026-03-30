---
name: condense
description: Rewrite text to be more concise and direct. Read-only — prints the tightened text for you to copy.
allowed-tools:
---

## Purpose

Rewrite LLM output or user-provided text to be shorter, punchier, and easier to scan. Strips filler, tightens phrasing, and cuts redundancy while preserving all technical content and meaning. Intended for cleaning up verbose responses before sharing them with others.

## Steps

### 1. Identify the input text

Follow the input identification rules in `_shared/text-transform-rules.md`. If the user provided text as an argument, use that. Otherwise, use the last assistant message.

### 2. Condense the text

Apply all preservation rules from `_shared/text-transform-rules.md`, then rewrite the text with these goals:

- **Cut filler words and phrases.** Remove "essentially", "basically", "it's worth noting that", "in order to", "the reason for this is", and similar padding.
- **Shorten sentences.** If a sentence can say the same thing in fewer words, rewrite it. Prefer active voice.
- **Collapse redundancy.** If two sentences say the same thing differently, merge them into one.
- **Tighten bullet points.** Each bullet should be one short line. Strip lead-in phrases and get to the payload immediately.
- **Remove meta-commentary.** Cut lines like "Let me explain...", "Here's what's happening:", "To summarize:" — the content should speak for itself.
- **Preserve all information.** Condensing means fewer words, not less information. Every fact, recommendation, and technical detail from the original must survive in the output.

### 3. Output the result

Print the condensed text directly. Follow the formatting rules in `_shared/text-transform-rules.md` — no preamble, no wrapper, just the transformed text.

## Rules

- **Preserve all information.** Condensing is about fewer words, never about dropping facts. Every technical detail, recommendation, and conclusion from the original must appear in the output.
- **Preserve code blocks verbatim.** Never modify code inside fenced blocks. Only tighten the surrounding prose.
- **No meta-commentary.** The output is the condensed text. Don't prepend "Here's the condensed version" or append "Let me know if you want it shorter."
- **No interaction.** This is a one-shot skill. Produce the output and stop. Don't ask follow-up questions.
- **Respect the shared rules.** All constraints in `_shared/text-transform-rules.md` apply.
