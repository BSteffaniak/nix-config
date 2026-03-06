# Code Comment Display Format

When presenting code alongside comments (drafts, reviewer feedback, or replies), use the ascii-art embedded format described below. This applies to all contexts: drafting annotations, reviewing reviewer comments, and drafting replies.

## Format specification

- **Gutter**: right-aligned line numbers, padded to consistent width, followed by `│`. Use the actual file line numbers.
- **Context**: show ~3-8 lines above and below the target line(s) — enough to understand the surrounding code.
- **Comment box**: placed immediately after the target line(s), using box-drawing characters (`┌─`, `│ `, `└─`). The gutter continues with blank spaces + `│` for box lines.
- **Box label**: appears after `┌─` and describes the comment source (see examples below).
- **Box width**: extend the `─` characters to roughly match the widest code line or ~50 characters, whichever is less. Do not obsess over exact width.
- **Wrap everything in a single plain fenced code block** (no language identifier — box-drawing characters break syntax highlighting).

## Example: draft annotation (pr-annotate)

````
```
  130 │ function filterCampsites(campsites: Campsite[]) {
  131 │   // Phase 1: server-authoritative filters
  132 │   const exploreFilters = applyExploreFilters(campsites);
  133 │   const localFilters = applyLocalFilters(exploreFilters);
      │
      │  ┌─ Draft comment ─────────────────────────────────
      │  │ Explore-level filters run first because they're
      │  │ server-authoritative and already applied by the
      │  │ API before reaching the client.
      │  └─────────────────────────────────────────────────
      │
  134 │   return localFilters;
  135 │ }
```
````

Box label: `Draft comment`

## Example: reviewer comment (pr-review)

````
```
   13 │ const result = await fetch(url);
   14 │ const data = result.json();
   15 │ return data.items;
      │
      │  ┌─ @reviewer ─────────────────────────────────────
      │  │ This should be `await result.json()` — json()
      │  │ returns a Promise.
      │  └─────────────────────────────────────────────────
      │
   16 │ }
```
````

Box label: `@<reviewer username>`

## Example: reviewer comment with draft reply (pr-review replies)

When presenting a draft reply alongside the original reviewer comment, show both boxes stacked — the reviewer's comment first, then the draft reply:

````
```
   13 │ const result = await fetch(url);
   14 │ const data = result.json();
   15 │ return data.items;
      │
      │  ┌─ @reviewer ─────────────────────────────────────
      │  │ This should be `await result.json()` — json()
      │  │ returns a Promise.
      │  └─────────────────────────────────────────────────
      │
      │  ┌─ Draft reply ───────────────────────────────────
      │  │ Fixed — added the missing await on line 14.
      │  └─────────────────────────────────────────────────
      │
   16 │ }
```
````

Box labels: `@<reviewer username>` for the original comment, `Draft reply` for the reply.

## Guidelines

- **One fenced code block per comment.** Do not split the ascii-art across multiple blocks.
- **Keep the excerpt focused.** 3-8 lines of context above and below the target. Do not show the entire file.
- **Use the diff hunk or current file.** Whichever better captures the relevant context. Prefer the current file state for accuracy.
- **Word-wrap comment text inside the box.** Keep lines inside the box under ~50 characters for readability. Do not let comment text overflow the box width.
- **Multi-line target ranges.** If the comment targets lines 15-20, show all of those lines, then the box below line 20.
