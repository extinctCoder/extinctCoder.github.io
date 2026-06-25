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
# The `publish` flag is stripped on the way in; %%comments%% are removed; math:/
# mermaid: flags are added when needed; and referenced images are copied into
# assets/img/obsidian/<slug>/ with their embeds rewritten.
#
# Everything this run produced is recorded in `.obsidian-sync.json` (the sync
# manifest): for each note its source, output file, and copied assets. That
# record is what a future cleanup pass (sync v2) reads to delete the outputs and
# assets of notes that are no longer published, and what the published_at
# write-back uses to locate the source notes.
#
# This ADDS/UPDATES published notes; it does not delete un-published ones yet —
# a deliberate v1 choice so it can never delete hand-authored posts. Within a
# single note, though, the asset dir is rebuilt each run, so dropping an image
# from a note removes it from the site on the next sync.

require "yaml"
require "date"
require "json"
require "fileutils"
require_relative "obsidian_md"

export = ARGV[0] || "vault-export"
abort "✗ export dir not found: #{export}" unless Dir.exist?(export)

FileUtils.mkdir_p("_posts")
FileUtils.mkdir_p("_projects")

# Synced image attachments land here, namespaced per note to avoid collisions.
ASSET_ROOT = "assets/img/obsidian"

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

# Copy the images a note references out of the export tree into the site assets,
# rewriting each embed to its published `/assets/...` URL. obsidian-export has
# already copied the attachments into the export dir, so paths resolve relative
# to the note. The note's asset dir is rebuilt fresh, so dropped images vanish.
# Returns [rewritten_body, sorted_asset_paths].
def relocate_images(content, source, slug)
  note_dir = File.dirname(source)
  assets = []
  FileUtils.rm_rf(File.join(ASSET_ROOT, slug)) # refresh — leave no orphaned images

  body = ObsidianMd.rewrite_images(content) do |target|
    src = File.expand_path(target, note_dir)
    next nil unless File.file?(src)

    dest_dir = File.join(ASSET_ROOT, slug)
    FileUtils.mkdir_p(dest_dir)
    dest = File.join(dest_dir, File.basename(src))
    FileUtils.cp(src, dest)
    assets << dest
    "/#{dest}"
  end

  [body, assets.sort]
end

# Full import transform: strip comments (privacy), then relocate images.
def import_note(body, source, slug)
  relocate_images(ObsidianMd.strip_comments(body), source, slug)
end

published = []
manifest = []
counts = { posts: 0, projects: 0, skipped: 0, images: 0 }

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

  content, assets = import_note(body, f, slug)
  File.write(out, front_matter(fm, fm_text, body) + content)

  published << f
  manifest << { "source" => f.delete_prefix("#{export}/"), "kind" => "post",
                "output" => out, "assets" => assets }
  counts[:posts] += 1
  counts[:images] += assets.size
end

# ── projects/ -> _projects/ ─────────────────────────────────────────────────
Dir.glob(File.join(export, "projects", "*.md")).sort.each do |f|
  fm, fm_text, body = split_doc(f)
  next unless fm && fm["publish"] == true

  slug = slugify(fm["title"] || File.basename(f, ".md"))
  out  = File.join("_projects", "#{slug}.md")

  content, assets = import_note(body, f, slug)
  File.write(out, front_matter(fm, fm_text, body) + content)

  published << f
  manifest << { "source" => f.delete_prefix("#{export}/"), "kind" => "project",
                "output" => out, "assets" => assets }
  counts[:projects] += 1
  counts[:images] += assets.size
end

# The manifest — stable order so diffs stay clean across runs.
manifest.sort_by! { |entry| entry["output"] }
File.write(".obsidian-sync.json", "#{JSON.pretty_generate("notes" => manifest)}\n")

puts "✓ synced #{counts[:posts]} post(s), #{counts[:projects]} project(s), " \
     "#{counts[:images]} image(s)" \
     "#{counts[:skipped].positive? ? " — skipped #{counts[:skipped]}" : ""}"
