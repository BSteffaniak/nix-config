# Code Comment Display Format

When presenting code alongside comments (drafts, reviewer feedback, or replies), use the ascii-art embedded format described below. This applies to all contexts: drafting annotations, reviewing reviewer comments, and drafting replies.

## Line anatomy

Every line in the ascii-art block is one of these types. The **gutter column** (the `│` after the line number) must be in the **same column on every line** — code lines, blank separators, and box lines alike.

### Code line

```
  <NNN> │ <code>
```

`<NNN>` is the line number, right-aligned, padded with leading spaces to a consistent width (typically 3-5 digits depending on the file). One space after the number, then `│`, then one space, then the code.

### Blank separator

```
        │
```

Same gutter column as code lines. No content after the `│`. Used to visually separate code from comment boxes (one blank separator above and below each box).

### Box top border

```
        │  ┌─ <label> ─────────────────────────────────────────┐
```

Same gutter column. Two spaces after `│`, then `┌─ `, then the label text, then a space, then `─` repeated to fill, then `┐`. The `┐` marks the right edge of the box.

### Box content line

```
        │  │ <comment text, padded with trailing spaces>       │
```

Same gutter column. Two spaces after `│`, then `│ `, then the comment text, then trailing spaces to fill, then ` │`. The closing `│` **must be in the same column as the `┐` and `┘`**.

### Box bottom border

```
        │  └───────────────────────────────────────────────────┘
```

Same gutter column. Two spaces after `│`, then `└`, then `─` repeated to fill, then `┘`. The `┘` **must be in the same column as the `┐`**.

## Alignment rules

These are critical. The most common rendering mistakes come from violating these:

1. **The gutter `│` is in the same column on every line.** Code lines, blank separators, box borders, box content — all have `│` in the same column.

2. **The right box edge (`┐`, `│`, `┘`) is in the same column on all box lines.** The top border's `┐`, every content line's closing `│`, and the bottom border's `┘` must vertically align. Pad content lines with trailing spaces before the closing `│` to achieve this.

3. **The box left edge (`┌`, `│`, `└`) is in the same column on all box lines.** Two spaces after the gutter `│`, then the box border character.

4. **Word-wrap comment text** to keep it shorter than the top/bottom border width. If a content line's text is shorter than the border, pad with spaces. If text is too long, wrap to the next line.

## Common mistakes — do NOT do these

- **Omitting the gutter on box lines.** Wrong: putting the box flush-left. The gutter `│` continues on every line.
- **Using `:` instead of `│` for the gutter.** Always use `│` (the box-drawing pipe), not `:`.
- **Misaligning the right edge.** If the `┐` is in column 60, then every content `│` and the `┘` must also be in column 60. Pad with spaces.
- **Omitting blank separator lines.** Always put one blank gutter line (`        │`) above and below each box.
- **Forgetting the right edge entirely.** Every box must have `┐`, closing `│` on content lines, and `┘`.

## Example: draft annotation (pr-annotate)

````
```ts
  130 │ function filterCampsites(campsites: Campsite[]) {
  131 │   // Phase 1: server-authoritative filters
  132 │   const exploreFilters = applyExploreFilters(campsites);
  133 │   const localFilters = applyLocalFilters(exploreFilters);
      │
      │  ┌─ Draft comment ────────────────────────────────────┐
      │  │ Explore-level filters run first because they're    │
      │  │ server-authoritative and already applied by the    │
      │  │ API before reaching the client.                    │
      │  └────────────────────────────────────────────────────┘
      │
  134 │   return localFilters;
  135 │ }
```
````

Box label: `Draft comment`

## Example: reviewer comment (pr-review)

````
```ts
   13 │ const result = await fetch(url);
   14 │ const data = result.json();
   15 │ return data.items;
      │
      │  ┌─ @reviewer ────────────────────────────────────────┐
      │  │ This should be `await result.json()` — json()      │
      │  │ returns a Promise.                                 │
      │  └────────────────────────────────────────────────────┘
      │
   16 │ }
```
````

Box label: `@<reviewer username>`

## Example: reviewer comment with draft reply (pr-review replies)

When presenting a draft reply alongside the original reviewer comment, show both boxes stacked — the reviewer's comment first, then the draft reply:

````
```ts
   13 │ const result = await fetch(url);
   14 │ const data = result.json();
   15 │ return data.items;
      │
      │  ┌─ @reviewer ────────────────────────────────────────┐
      │  │ This should be `await result.json()` — json()      │
      │  │ returns a Promise.                                 │
      │  └────────────────────────────────────────────────────┘
      │
      │  ┌─ Draft reply ──────────────────────────────────────┐
      │  │ Fixed — added the missing await on line 14.        │
      │  └────────────────────────────────────────────────────┘
      │
   16 │ }
```
````

Box labels: `@<reviewer username>` for the original comment, `Draft reply` for the reply.

## Guidelines

- **One fenced code block per comment.** Do not split the ascii-art across multiple blocks.
- **Keep the excerpt focused.** 3-8 lines of context above and below the target. Do not show the entire file.
- **Use the diff hunk or current file.** Whichever better captures the relevant context. Prefer the current file state for accuracy.
- **Word-wrap comment text inside the box.** Wrap text so it fits within the box borders. Pad shorter lines with trailing spaces so the right `│` stays aligned.
- **Multi-line target ranges.** If the comment targets lines 15-20, show all of those lines, then the box below line 20.
- **Use the appropriate language identifier.** Tag the fenced code block with the file's language (e.g., `ts`, `py`, `go`, `nix`). The code lines get proper syntax highlighting while the box-drawing lines render as plain text — this provides natural visual contrast, making the comment box stand out from the surrounding code.
