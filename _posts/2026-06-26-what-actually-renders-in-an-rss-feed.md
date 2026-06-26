---
title: "What Actually Renders in an RSS Feed"
description: "A full-content RSS feed sounded trivial — until code blocks shattered and diagrams vanished. What feed readers actually render, and what they silently strip."
date: 2026-06-26 11:00:00 +0600
categories: [DevOps, Automation]
tags: [rss, atom, jekyll, feeds, mermaid]
garden_status: budding
---

I wanted my RSS feed to carry the *whole* post — no "continue reading" teaser. The site
is already [built from notes by a pipeline](/posts/your-notes-app-is-your-cms/); the feed
felt like a one-line afterthought. It wasn't. A feed reader turns out to be a hostile
rendering environment, and "it looks right on my site" buys you almost nothing there.

## The idea

A subscriber should get the full article in their reader, rendered, without a round trip
to the site. Easy to state. The trouble is *where* that HTML ends up: in someone else's
app, with none of my CSS, none of my JavaScript, and an aggressive sanitizer in between.

## What broke

**Teasers, by default.** The theme's feed shipped a `<summary>` plus a `<content … src="…"/>`
— a *pointer* to the page, not the content. Readers showed the excerpt and a link. Fix:
inline the full post HTML as escaped Atom content (`<content type="html">…</content>`),
which round-trips correctly once you stop double-escaping the entities.

**Code blocks shattered.** My theme renders code as a *line-number table* — a gutter
column, a code column, a copy button — all positioned by CSS. A reader has none of that
CSS, so the table collapsed into stacked boxes: "1 2" in one, the code in another. Fix:
in the feed only, flatten those tables to plain `<pre><code>`. The site keeps its fancy
version; the feed gets legible monospace.

**Diagrams vanished.** This was the real lesson. My diagrams are Mermaid, rendered
**client-side by JavaScript**. Readers don't run your JS — so the diagram showed up as
raw flowchart source. Stripping it would lose information; leaving it was gibberish.

## The reality of feed readers

Once you hit the diagram problem, the underlying rule becomes obvious: **a feed reader
sanitizes hard.** It strips `<script>`, `<iframe>`, inline `<svg>`, `<object>` — anything
interactive or embeddable — for security. What reliably survives is plain HTML and a
single element for visuals: **`<img>`**.

So anything your site renders *at view time* — Mermaid, MathJax, syntax highlighting
colors — simply isn't there in a feed. If you want a visual to survive, it has to be a
flat image at a URL, baked **before** the reader ever sees it.

## The Mermaid rabbit hole

Getting a diagram into the feed went through every dead end:

- **Inline SVG?** Stripped by readers.
- **An `<iframe>` to the page?** Stripped.
- **Just render the PNG.** Now we're talking — but with what background? The diagram has
  fixed colors, so a *transparent* PNG with dark lines is invisible in a dark-mode reader,
  and a dark one is invisible in a light reader. A single image can't adapt the way CSS
  can.

The honest fix is a **self-contained image** — the diagram baked onto an opaque card so it
carries its own contrast and reads on any background. Render it server-side at build,
host the image, and the feed just points an `<img>` at it. No JS, no theme assumptions,
no surprises.

## The lesson

A feed isn't a smaller version of your site — it's your content dropped into an unknown
app, with an unknown theme, that runs none of your code. The mental shift that fixes
everything: **author for that target.** Render visuals server-side or link out; inline the
real content, not a pointer; assume your CSS and JS never make the trip.

It's the same discipline as [designing for the bad day](/posts/designing-for-the-bad-days/)
— the happy path (your own browser) hides all the cases that matter. "Works on my site"
and "works everywhere my content goes" are different claims, and RSS is a blunt reminder
of the gap.
