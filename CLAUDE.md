# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Working rules (read first)

1. **Do not edit anything before asking.** Never modify files on your own initiative — always ask and get explicit approval first.
2. **Always check the code before saying anything. No assumptions, no hallucination.** Read the relevant files and verify against the actual code before answering. If something is unverified or unknown, say so rather than guessing.
3. **Discuss and lock the approach before any implementation.** Talk through everything first, agree on the plan, and lock it down. By default, hand me the code to apply myself — do not edit the files unless I explicitly say to implement.

## What this is

A personal blog/site (`extinctCoder.github.io`) built on Jekyll using the **Chirpy** theme, installed as a RubyGem (`jekyll-theme-chirpy ~> 7.0`) via the Chirpy Starter template. Because the theme is a gem, the layouts, includes, sass, and most assets live *inside the gem*, not in this repo — run `bundle info --path jekyll-theme-chirpy` to locate them when you need to inspect or override theme internals.

## Commands

```bash
bundle                       # install dependencies
bundle exec jekyll serve     # local dev server with live reload at http://127.0.0.1:4000
bundle exec jekyll build     # build to _site/

# Run the same HTML validation CI uses (after a build):
bundle exec htmlproofer _site \
  --disable-external \
  --ignore-urls "/^http:\/\/127.0.0.1/,/^http:\/\/0.0.0.0/,/^http:\/\/localhost/"
```

Ruby 3.3 is the version CI builds against.

## Deployment

Pushing to `main` triggers `.github/workflows/pages-deploy.yml`, which builds with `JEKYLL_ENV=production`, runs html-proofer, and deploys to GitHub Pages. Changes to `.gitignore`, `README.md`, and `LICENSE` do not trigger a deploy. There is no manual publish step — merge to `main` is the release.

## Authoring content

- **Posts** go in `_posts/` named `YYYY-MM-DD-title.md` (the date prefix is required by Jekyll). Front matter drives `title`, `date`, `categories`, `tags`.
- **Tabs** (nav pages: about, archives, categories, tags) live in `_tabs/`. They are thin stubs that set a `layout` provided by the theme.
- `_data/contact.yml` and `_data/share.yml` configure the sidebar contact links and post share buttons.
- Site-wide settings (title, social links, comments, analytics, theme mode) are all in `_config.yml`. Comments use **giscus** wired to this repo's Discussions; analytics use **goatcounter** (`extinctcoder`).

## Projects collection

Projects are a **custom collection** (`_projects/`), separate from blog posts (declared in `_config.yml` under `collections:`, `output: true`, served at `/projects/:title/`). Two **custom layouts** drive it — both reuse the theme's own components, no custom CSS:

- **`_layouts/projects.html`** — the listing (the `_tabs/projects.md` tab sets `layout: projects`). Renders the cards (`#post-list` + `card-wrapper`/`post-preview`) **outside `.content`**, like the home page. This matters: inside a tab's `.content` wrapper, the theme's content-typography styles break the card layout.
- **`_layouts/project.html`** — the detail page (`defaults` sets projects → `layout: project`). Title + description + auto source/demo links + a right-sidebar **TOC**, content in `.content`, and deliberately **no** post chrome (date/author/share/license/related/prev-next).

**TOC:** Chirpy picks the page JS bundle by `page.layout` in `_includes/js-selector.html`, and only some bundles call `tocbot.init()`. We keep a **local override of `_includes/js-selector.html`** mapping `layout: project` → the `page` bundle (fires the TOC init on `data-toc="true"`, and loads the clipboard/lightbox libs). Each project needs `toc: true` + `##` headings for the TOC to appear.

**Listing thumbnails:** Chirpy's card-image handling is hardcoded to `layout: home` (`refactor-content.html`), so an `image:` on the projects *listing* gets wrapped in a lightbox `<a>` (nested anchor) and breaks the card — prefer text-only listing cards and show screenshots on the detail page.

**source/demo links** are rendered by `_layouts/project.html` from the `source`/`demo` front matter (single source of truth — only links that exist are emitted). Do **not** put link markup in the project body.

**Mermaid:** Chirpy renders Mermaid natively when `mermaid: true` is set in front matter (see the theme's `_includes/js-selector.html`). Use ```` ```mermaid ```` fenced blocks. Prefer `flowchart`/`sequenceDiagram`/`erDiagram` — Mermaid's `C4*` syntax is experimental and renders inconsistently.

**Standard project file template** (every `_projects/*.md` follows this — keep new ones consistent):

````markdown
---
title: <Project Name>
description: <one-line summary for the card>
order: <n>                 # card position, 1 = first
tech: [<Tech>, <Tech>]     # chips shown on the card
source:                    # repo URL (omit/blank if none)
demo:                      # live URL (omit/blank if none)
mermaid: true              # REQUIRED for diagrams to render
toc: true                  # REQUIRED for the detail-page TOC
# image:                   # optional; NOT for the listing (see thumbnails note above)
---

## At a glance
| | |
|---|---|
| **Role** | … |
| **Timeline** | … |
| **Team** | … |
| **Stack** | … |
| **Status** | … |

## Problem & context
## Architecture        (flowchart diagram)
## Key flow            (sequenceDiagram)
## Data model          (erDiagram)
## What I built
## Outcome
````

Links live in front matter (`source`/`demo`) as the single source of truth and are rendered in the body via Liquid — the block only emits links that exist, so no dead `#` links.

## Notable customization

`_plugins/posts-lastmod-hook.rb` sets each post's `last_modified_at` from git history — it shells out to `git rev-list`/`git log` at build time. This means **accurate "last modified" dates depend on full git history being present**; the CI checkout uses `fetch-depth: 0` for this reason. Squashing or shallow-cloning will break the dates.
