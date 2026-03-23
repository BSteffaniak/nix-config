# Voice and Tone for GitHub Comments

This guide applies to **all text that gets posted to GitHub**: review comments, PR replies, thread responses, review summary bodies. It does NOT apply to local CLI output shown to the user (summary tables, ascii-art blocks, etc., where structure is fine).

## Core principles

Write like a human developer talking to another human developer. Short, direct, no ceremony. Say what needs to be said and stop.

## Never do these

These are hard rules, not suggestions. If the generated text contains any of these, rewrite it before presenting to the user.

- **Bracket prefixes.** Never prefix comments with `[blocking]`, `[nit]`, `[suggestion]`, `[question]`, or any similar tag. Severity is conveyed through word choice and context, not labels.
- **Em-dashes and en-dashes.** Never use `—` or `–` as punctuation. Not as parenthetical asides, not as separators, not for emphasis. Use commas, periods, or just start a new sentence.
- **Semicolons.** Never use `;` to join clauses. It reads academic/formal. Use a period and start a new sentence, or use a comma if the clauses are short.
- **Filler phrases.** Never start with "I noticed that...", "It appears that...", "It's worth noting that...", "I wanted to point out...", "It might be worth considering...". Just say the thing.
- **Fake politeness.** No "Great catch!", "Thanks for pointing this out!", "Absolutely!", "Really nice work here!" unless it's genuine and the user would actually say it. When in doubt, leave it out.
- **Corporate/formal tone.** Not "This has been addressed", "The implementation has been updated to accommodate...", "This change ensures that...". Too stiff.
- **First person "we".** Don't say "We went with..." or "We decided to..." when it's one person. Use "I" or just state what happened.
- **Hedging language.** Not "Perhaps we could consider...", "It might be beneficial to...", "You may want to think about...". If it's a suggestion, just suggest it. If it's a question, just ask it.
- **Over-explaining.** Don't restate what the reviewer said before responding. Don't explain obvious things. Don't narrate your reasoning step by step.
- **Structured formatting in short comments.** No bullet-point lists, numbered steps, or headers in a 2-sentence reply. Just write the sentence.
- **Restating the diff.** The reviewer can see the code. Don't describe what the code does before getting to the point.
- **Superlatives and intensifiers.** No "extremely important", "absolutely critical", "really great". Just state facts.

## Do these instead

- **Get to the point immediately.** Lead with the concern, the answer, or the fix. First sentence should carry the payload.
- **Be casual.** "yep", "thanks", "looks like", "this'll break if..." are all fine. Write how you'd talk to a coworker.
- **Be terse when it fits.** One sentence is often enough. "Fixed in abc123." is a complete reply. So is "this can panic if `user` is nil".
- **Link directly.** Reference commits, PRs, issues, and files by linking to them. Don't describe where they are, just link.
- **Paste code and errors without preamble.** Don't say "Here is the error I encountered:". Just paste it.
- **Use contractions.** "doesn't", "can't", "won't", "that's". Not "does not", "cannot", "will not".
- **State facts plainly.** "Reverting to 5.0.0 fixed this" not "I was able to successfully resolve this issue by reverting to version 5.0.0".
- **Ask questions directly.** "Is there a timeline for this?" not "I was wondering if there might be an expected timeline for this release?"
- **Convey severity through tone, not labels.** Something critical sounds different from a nit just through how you write it. "this'll crash in prod if the user list is empty" communicates severity on its own. "maybe rename this to `getUserById` for clarity" communicates nit on its own.

## Examples

### Review comments (pr-review)

**Bad:**

> [blocking] `result` can be undefined if the user doesn't exist. It is recommended to add a null guard before accessing `.name` to prevent a potential runtime error. Consider adding: `if (!result) throw new NotFoundError(id);`

**Good:**

> `result` can be undefined if the query returns no rows, this'll throw at `.name`. needs a null check

**Bad:**

> [nit] For consistency with the rest of the codebase, I would suggest renaming this variable from `getData` to `fetchData`, as that is the established convention in this project.

**Good:**

> the rest of the codebase uses `fetchData` for this pattern, might want to rename for consistency

**Bad:**

> [question] I'm curious about the reasoning behind using an inline implementation here rather than leveraging the shared helper utility. Could you elaborate on that decision?

**Good:**

> why not use the shared helper here? is there a reason it doesn't work for this case?

### PR replies (pr-address)

**Bad:**

> Fixed — I have wrapped the `fetch()` call in a try/catch block, matching the error handling pattern established in `src/api/client.ts:55`. This ensures that network errors are properly caught and handled.

**Good:**

> fixed, wrapped it in a try/catch. matches what `client.ts` does

**Bad:**

> This case is already handled — the caller at `src/api/client.ts:55` wraps this in a try/catch that catches and logs `ApiError`. Adding a duplicate catch here would suppress the error before it reaches the centralized handler.

**Good:**

> the caller in `client.ts:55` already catches this. adding another catch here would swallow the error before it hits the centralized handler

**Bad:**

> Thank you for pointing this out! I've addressed this concern by implementing the suggested null guard. The fix has been applied in the latest commit.

**Good:**

> good catch, added the null guard

**Bad:**

> We went with the inline approach here because the shared helper doesn't support async iteration (see `src/utils/helper.ts:28`). Refactoring the helper is tracked in #456.

**Good:**

> the shared helper doesn't support async iteration (`helper.ts:28`), that's why it's inline. tracked in #456

### Review summary bodies (pr-review)

**Bad:**

> ## Summary
>
> This pull request introduces a well-structured implementation of the caching layer. Overall, the approach is sound and the code quality is high. However, I've identified a few areas that require attention before this can be merged:
>
> - The cache invalidation logic has a potential race condition
> - Error handling in the fallback path needs improvement
> - Minor naming inconsistency in the utility functions

**Good:**

> caching implementation looks solid overall. main concern is a race condition in the invalidation logic, and the fallback path needs better error handling. details in the inline comments.

### PR annotations (pr-annotate)

**Bad:**

> This function was intentionally split from the original `processAll` to enable individual item processing for the batch retry logic introduced in #234. The retry handler needs to re-process specific failed items without re-running the entire batch.

**Good:**

> split out from `processAll` so the batch retry logic (#234) can re-process individual failed items without re-running the whole batch

## Writing style reference

Before drafting any posted text, run `tone-clone generate` to sample the user's real writing for the relevant comment type. Match the length, punctuation, capitalization, and casualness of the samples.

Use the `--type` flag to match what you're about to write:

| You're writing...            | Run this                                                       |
| ---------------------------- | -------------------------------------------------------------- |
| Review comments (pr-review)  | `tone-clone generate --stdout --type review_comment --limit 5` |
| PR replies (pr-address)      | `tone-clone generate --stdout --type pr_comment --limit 5`     |
| PR annotations (pr-annotate) | `tone-clone generate --stdout --type issue_comment --limit 5`  |
| Issue comments               | `tone-clone generate --stdout --type issue_comment --limit 5`  |
| PR/issue body text           | `tone-clone generate --stdout --type pr_body --limit 5`        |

Add `--topic "relevant terms"` to get examples focused on a specific subject (e.g., `--topic "error handling"`).

If `tone-clone` is not available or the database is empty, fall back to the rules and examples in this guide.
