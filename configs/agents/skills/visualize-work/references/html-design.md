# HTML design guide

## Visual contract

Build an editorial technical walkthrough, not a wall of markdown inside HTML.
The first screen should communicate the outcome, comparison scope, and where
to start. Prefer a few useful visual explanations over decorative charts or
counts of changed lines. Scale chapter count and detail to the work; a tiny fix
should not become an enormous report.

Use the shell's semantic structure and visual language, adapting the layout to
the subject. Replace every `VW_*` token, including tokens in comments. Tokens
are insertion points, not a templating language: construct trusted HTML and
escape its source-derived text and quoted attributes separately. Do not perform
unescaped global substitution with PR bodies or code.

## Shell insertion points

| Token             | Required content                                                             |
| ----------------- | ---------------------------------------------------------------------------- |
| `VW_TITLE`        | Concise escaped title, used in title and heading                             |
| `VW_SCOPE`        | Escaped human-readable scope summary                                         |
| `VW_OUTCOME`      | Escaped plain-language outcome                                               |
| `VW_NAV`          | Trusted list items with internal anchor links to actual chapter IDs          |
| `VW_OVERVIEW`     | Outcome summary and useful before/after comparison                           |
| `VW_MAP`          | Accessible architecture, flow, or stack map with textual equivalent          |
| `VW_CHAPTERS`     | Evidence-backed theme sections with unique IDs                               |
| `VW_DECISIONS`    | Rationale/tradeoffs with documented, inferred, or unknown labels             |
| `VW_VERIFICATION` | Actual checks and limitations, clearly separating execution from metadata    |
| `VW_PROVENANCE`   | Timestamp, revisions, comparisons, source references, coverage, privacy note |

Remove irrelevant components rather than leaving empty cards. Preserve the
summary, scope, verification, and provenance even for small reports.

## Chapter anatomy

Each chapter should answer one reader question, with a descriptive heading such
as “Requests now retain their cancellation context,” not “Backend
files.”

- Start with a one-sentence behavioral change and why the reader should care.
- Pair `.comparison` panels labeled **Before** and **After**; do not rely on
  red/green color. A configuration or lifecycle comparison works for non-UI work.
- Show a compact `.flow` or inline SVG when relationships are easier to see than
  read. Give each SVG `role="img"` and unique title/description IDs referenced by
  `aria-labelledby`; include a nearby textual summary. Use a responsive viewBox.
- Include representative `<pre><code>` snippets in `.code-grid` panels. Label
  path, revision, side, and line range in visible text. Prefer 8–30 useful lines
  over an unbounded dump, without imposing a rigid limit that loses context.
- Put deeper edge cases and secondary excerpts in `<details>` with meaningful
  `<summary>` labels. Critical conclusions must not be hidden by default.
- Cite source anchors near the claim; map these to provenance entries.

Optional pattern, with real content substituted and escaped:

```html
<section id="theme-cancellation" aria-labelledby="heading-cancellation">
  <p class="eyebrow">Implementation · 01</p>
  <h2 id="heading-cancellation">Descriptive behavioral heading</h2>
  <p class="lead">Evidence-backed change summary.</p>
  <div class="comparison">
    <article class="panel"><h3>Before</h3><p>Previous behavior.</p></article>
    <article class="panel"><h3>After</h3><p>New behavior.</p></article>
  </div>
  <details><summary>Explore the implementation</summary>
    <p>Source path, side, revision, and line range.</p>
    <pre><code>Escaped representative source.</code></pre>
  </details>
  <p><span class="badge">Inferred</span> Rationale with a source reference.</p>
</section>
```

## Screenshots

Use `<figure>` with a descriptive `<figcaption>` and an `<img>` with informative
alt text. Embed raster images as data URIs, include width/height, and constrain
layout without cropping important content. Use paired labeled figures for true
before/after captures. Mark unmatched viewport/data/revision differences so the
reader does not mistake them for product changes. A screenshot is evidence of a
particular state, not proof that all behavior works.

For optional zoom, wrap the image in native `<details class="image-zoom">` with
an explicit summary (for example, “Expand settings screenshot”). The shell
supports a scrollable full-resolution view; this works without JavaScript.
Do not add a modal unless focus trapping, Escape, close controls, and focus
restoration are implemented and actually tested.

## Stack presentation

Show external base → ordered PR layers → combined outcome, with arrows and
PR
labels that are understandable without color. Link map nodes to chapters. Use
branching diagrams for non-linear dependencies. In each layer distinguish its
increment from inherited code. Separate “stack structure observed in Git”
from
“reason for the split documented by author.” Net result and per-PR analysis
must agree; disclose gaps when unavailable objects prevent checking that.

## Accessibility, responsiveness, and offline behavior

- One `h1`, ordered heading hierarchy, semantic landmarks, skip link, and visible
  keyboard focus. Use real links/buttons, not clickable divs.
- Restrained accent colors; body contrast at least WCAG AA. Include text labels
  for status, confidence, and before/after. Use system fonts, readable line
  lengths, and generous space.
- Narrow screens stack comparison/code panels. Long paths wrap; code scrolls
  inside its panel, never forcing the document wider than the viewport.
- Respect reduced motion. No autoplay, animations, tracking, or hidden network
  requests. No JavaScript is necessary for reading or basic navigation.
- Print styling removes sticky navigation/controls, exposes details, and keeps
  code readable. Verify print behavior with a browser when possible; browser
  handling of closed details can differ.
- The optional shell button expands/collapses all details using `textContent` and
  fixed selectors. Do not inject source-derived values into that script.
- Retain the CSP: no network connections, remote resources, forms, embeds, or
  executable event attributes. Inline CSS and the fixed presentation script are
  intentional. CSP complements escaping; it does not make unsafe HTML safe.

## Quality bar

A reader should be able to explain the outcome and major tradeoffs without
opening GitHub. Every major theme needs a purposeful visual treatment (a flow,
comparison, diagram, or screenshot); prose remains necessary to explain it.
Do not pad a report with generic architecture or unsupported claims. Include
remaining risks and evidence gaps with the same care as the accomplishments.
