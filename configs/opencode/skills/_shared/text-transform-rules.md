# Text Transformation Rules

Shared rules for skills that rewrite text (condense, expand, etc.).

## Identifying input text

When the user invokes the skill:

1. **With an argument** — the argument IS the text to transform. Use it directly.
2. **Without an argument** — use the last assistant message in the conversation as input. If the conversation has no prior assistant message, tell the user to provide text as an argument.

## Preservation rules

These are hard constraints. Never violate them regardless of the transformation direction.

- **Code blocks.** Never modify the contents of fenced code blocks. Reproduce them exactly. You may adjust the surrounding prose that describes them, but the code itself is untouchable.
- **Links and references.** Preserve all URLs, file paths, issue/PR references, and commit hashes verbatim.
- **Technical accuracy.** Never change the factual meaning. If the original says "this function returns null on failure", the transformed version must say the same thing, just with different verbosity.
- **Structure type.** If the input uses bullet points, the output uses bullet points. If the input uses prose paragraphs, the output uses prose paragraphs. Don't convert between structural formats unless doing so is inherent to the transformation (e.g., condensing a verbose paragraph into a bullet list is acceptable for condense).
- **Headings and hierarchy.** Preserve heading levels and section organization. Don't merge or split sections.

## Formatting

- Output raw markdown. No wrapping in a code fence unless the input itself was a code fence.
- Don't add meta-commentary like "Here's the condensed version:" — just output the transformed text directly.
- Don't add a preamble or closing summary. The output IS the transformed text, nothing more.
