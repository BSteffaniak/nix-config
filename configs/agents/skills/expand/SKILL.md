---
name: expand
description: Elaborate on text with more detail and explanation. Read-only — prints the expanded text for you to copy.
allowed-tools:
---

## Purpose

Rewrite LLM output or user-provided text to be more detailed, explanatory, and thorough. Fleshes out terse points, adds context and rationale, and makes the text more accessible to readers who may not have full background. Intended for turning concise internal notes into shareable documentation or explanations.

## Steps

### 1. Identify the input text

Follow the input identification rules in `_shared/text-transform-rules.md`. If the user provided text as an argument, use that. Otherwise, use the last assistant message.

### 2. Expand the text

Apply all preservation rules from `_shared/text-transform-rules.md`, then rewrite the text with these goals:

- **Elaborate on terse points.** If a bullet or sentence states a conclusion without explanation, add the reasoning or context behind it.
- **Add "why" and "how".** Where the original only states "what", fill in why it matters and how it works.
- **Unpack jargon.** If the original uses shorthand, acronyms, or domain-specific terms without explanation, briefly clarify them for a broader audience.
- **Flesh out examples.** If the original mentions something in passing, expand it into a concrete example or scenario.
- **Smooth transitions.** Add connecting language between sections or points so the text flows naturally for someone reading it end-to-end.
- **Don't invent new information.** Expansion means elaborating on what's there, not adding new claims, recommendations, or facts that weren't present or clearly implied in the original. If something needs clarification that you can't infer, note it rather than fabricate it.

### 3. Output the result

Print the expanded text directly. Follow the formatting rules in `_shared/text-transform-rules.md` — no preamble, no wrapper, just the transformed text.

## Rules

- **Don't invent new information.** Expanding means elaborating on existing content. Never introduce new facts, claims, or recommendations that aren't present or clearly implied in the original.
- **Preserve code blocks verbatim.** Never modify code inside fenced blocks. Only expand the surrounding prose.
- **No meta-commentary.** The output is the expanded text. Don't prepend "Here's the expanded version" or append "Let me know if you want more detail."
- **No interaction.** This is a one-shot skill. Produce the output and stop. Don't ask follow-up questions.
- **Respect the shared rules.** All constraints in `_shared/text-transform-rules.md` apply.
