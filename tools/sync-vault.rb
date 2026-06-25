#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Sync published notes from an exported Obsidian vault into the Jekyll site.
#
#   ruby tools/sync-vault.rb <export-dir>
#
# <export-dir> holds `blog/` and `projects/` as clean Markdown (output of
# `obsidian-export`). Only notes with `publish: true` are copied in:
#   blog/*.md     -> _posts/YYYY-MM-DD-slug.md
#   projects/*.md -> _projects/slug.md
# The `publish` flag is stripped on the way in. Source paths of published notes
# are written to `published-notes.txt` (used by the write-back step).
#
# Note: this ADDS/UPDATES published notes; it does not delete. Un-publishing a
# note (removing the flag) won't auto-remove it from the site yet — that's a
# deliberate v1 choice so it can never delete hand-authored posts.

require "yaml"
require "date"
require "fileutils"
require_relative "obsidian_md"

export = ARGV[0] || "vault-export"
abort "✗ export dir not found: #{export}" unless Dir.exist?(export)

FileUtils.mkdir_p("_posts")
FileUtils.mkdir_p("_projects")

def split_doc(path)
  raw = File.read(path)
  return [nil, nil, raw] unless raw.start_with?("---")

  parts = raw.split("---", 3)
  return [nil, nil, raw] if parts.size < 3

  fm = YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
  [fm, parts[1], parts[2]] # parsed hash, raw front-matter text, body
end

def slugify(str)
  str.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
end

# Rebuild front matter from the original text, minus the `publish:` line, and
# add math:/mermaid: when the body needs them — so the committed file carries the
# flag (the content validator and Chirpy both read it there, not at render time).
def front_matter(fm, fm_text, body)
  kept = fm_text.lines.reject { |l| l =~ /^\s*publish\s*:/i }.join.sub(/\A\n+/, "")
  kept += "\n" unless kept.end_with?("\n")
  ObsidianMd.flags(body).each do |flag, needed|
    kept += "#{flag}: true\n" if needed && !fm.key?(flag)
  end
  "---\n#{kept}---\n"
end

published = []
counts = { posts: 0, projects: 0, skipped: 0 }

# ── blog/ -> _posts/ ────────────────────────────────────────────────────────
Dir.glob(File.join(export, "blog", "*.md")).sort.each do |f|
  fm, fm_text, body = split_doc(f)
  next unless fm && fm["publish"] == true

  unless fm["date"]
    warn "  skip (post needs a 'date'): #{f}"
    counts[:skipped] += 1
    next
  end

  d = fm["date"].respond_to?(:strftime) ? fm["date"] : Date.parse(fm["date"].to_s)
  slug = slugify(fm["title"] || File.basename(f, ".md"))
  out  = File.join("_posts", "#{d.strftime('%Y-%m-%d')}-#{slug}.md")

  File.write(out, front_matter(fm, fm_text, body) + ObsidianMd.strip_comments(body))
  published << f
  counts[:posts] += 1
end

# ── projects/ -> _projects/ ─────────────────────────────────────────────────
Dir.glob(File.join(export, "projects", "*.md")).sort.each do |f|
  fm, fm_text, body = split_doc(f)
  next unless fm && fm["publish"] == true

  slug = slugify(fm["title"] || File.basename(f, ".md"))
  out  = File.join("_projects", "#{slug}.md")

  File.write(out, front_matter(fm, fm_text, body) + ObsidianMd.strip_comments(body))
  published << f
  counts[:projects] += 1
end

File.write("published-notes.txt", published.join("\n"))
puts "✓ synced #{counts[:posts]} post(s), #{counts[:projects]} project(s)" \
     "#{counts[:skipped].positive? ? " — skipped #{counts[:skipped]}" : ""}"
