---
title: Hello from the Vault
description: A note written in Obsidian that exercises the full publishing pipeline — callouts, highlights, wikilinks, transclusion, and an embedded image.
date: 2026-06-26 01:00:00 +0600
categories:
- Meta
tags:
- obsidian
- automation
---


If you're reading this on the live site, a note written in Obsidian — flagged with
`publish: true` — was picked up by GitHub Actions, ==converted automatically==, and
deployed, with no copy-paste in between. 

 > 
 > \[!tip\] Write once, publish anywhere
 > This whole post is a plain Obsidian note. The callout styling you're reading was
 > applied by the pipeline, not hand-written.

It links to [another published note](reusable-notes.md), and pulls a shared section
straight in by transclusion:

## Key idea

Write something once, reuse it everywhere. This section is transcluded into the
hello post — change it here and it updates there on the next sync.

And here's an image embedded straight from the vault:

![diagram.png](/assets/img/obsidian/hello-from-the-vault/diagram.png)
