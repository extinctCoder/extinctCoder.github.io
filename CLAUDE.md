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

Projects are a **custom collection** (`_projects/`), separate from blog posts. Declared in `_config.yml` under `collections:` with `output: true` (each project gets a page at `/projects/:title/`). The listing/portfolio page is the `_tabs/projects.md` tab, which reuses Chirpy's **native** post-card markup (`#post-list` + `card-wrapper`/`card`/`post-preview`) over `site.projects` — no custom CSS; all styling comes from the theme's `_sass/pages/_home.scss`.

**TOC note:** Chirpy's TOC is implemented only in the `post` layout, not `page`. Projects use `page`, so `toc: true` in their front matter is dormant until a TOC-capable layout is added (deferred UI work).

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
toc: true                  # forward-ready; dormant under `page` layout
# image:                   # optional preview; omit if none
---

{% raw %}{% if page.source or page.demo %}
> {% if page.source %}[Source]({{ page.source }}){% endif %}{% if page.source and page.demo %} · {% endif %}{% if page.demo %}[Live demo]({{ page.demo }}){% endif %}
{% endif %}{% endraw %}

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
