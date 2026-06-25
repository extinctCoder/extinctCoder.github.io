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
# It also removes notes that are no longer published: anything the previous
# manifest recorded but this run didn't produce is deleted (output + assets).
# Cleanup only ever touches manifest-recorded paths, so hand-authored posts are
# never at risk; and a sync that finds zero notes refuses to delete (treated as
# an export failure, not a real "unpublish everything").

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

# Record of everything the previous sync produced — drives unpublish cleanup.
MANIFEST = ".obsidian-sync.json"

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

# Raster formats worth shrinking (skip SVG/GIF).
RASTER = %w[.png .jpg .jpeg .webp].freeze

# Find an ImageMagick CLI once (nil if none — downscaling is then skipped).
def image_tool
  return @image_tool if defined?(@image_tool)

  @image_tool = %w[magick convert].find { |t| system("command -v #{t} > /dev/null 2>&1") }
end

# Best-effort: shrink oversized images (>1600px) and strip metadata. No-op
# without ImageMagick. Converts to a temp file and only swaps it in on success,
# so a failed conversion can never corrupt the copied image.
def downscale(path)
  tmp = nil
  return unless image_tool
  return unless RASTER.include?(File.extname(path).downcase)

  tmp = "#{path}.opt"
  ok = system(image_tool, path, "-resize", "1600x1600>", "-strip", "-quality", "82", tmp,
              out: File::NULL, err: File::NULL)
  if ok && File.exist?(tmp) && File.size(tmp).positive?
    FileUtils.mv(tmp, path)
  else
    FileUtils.rm_f(tmp)
  end
rescue StandardError
  FileUtils.rm_f(tmp) if tmp
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
    downscale(dest)
    assets << dest
    "/#{dest}"
  end

  [body, assets.sort]
end

# Full import transform: strip comments (privacy), then relocate images.
def import_note(body, source, slug)
  relocate_images(ObsidianMd.strip_comments(body), source, slug)
end

def load_manifest(path)
  return [] unless File.exist?(path)

  JSON.parse(File.read(path))["notes"] || []
rescue JSON::ParserError
  []
end

# Remove the outputs + assets of notes that a previous sync published but this
# one did not (un-published or deleted in the vault). It only ever touches paths
# the manifest recorded — hand-authored files are never in the manifest, so they
# can never be deleted here.
def reconcile(previous, manifest, counts)
  # Safety: an empty result against a non-empty history almost always means the
  # export failed — refuse to delete everything on that basis.
  if manifest.empty? && !previous.empty?
    warn "  ⚠ skipping cleanup: 0 notes published but #{previous.size} were before " \
         "(likely an export failure — refusing to delete published content)"
    return
  end

  current_outputs = manifest.map { |e| e["output"] }
  current_assets  = manifest.flat_map { |e| Array(e["assets"]) }

  previous.each do |entry|
    next if current_outputs.include?(entry["output"])

    FileUtils.rm_f(entry["output"])
    Array(entry["assets"]).each { |a| FileUtils.rm_f(a) unless current_assets.include?(a) }
    counts[:removed] += 1
  end

  # Prune asset dirs left empty by the removals.
  Dir.glob(File.join(ASSET_ROOT, "*")).each do |dir|
    FileUtils.rm_rf(dir) if File.directory?(dir) && Dir.empty?(dir)
  end
end

previous = load_manifest(MANIFEST) # what the last sync produced (for cleanup)
published = []
manifest = []
counts = { posts: 0, projects: 0, skipped: 0, images: 0, removed: 0 }

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

# Clean up notes that are no longer published, then write the fresh manifest.
manifest.sort_by! { |entry| entry["output"] } # stable order → clean diffs
reconcile(previous, manifest, counts)
File.write(MANIFEST, "#{JSON.pretty_generate("notes" => manifest)}\n")

puts "✓ synced #{counts[:posts]} post(s), #{counts[:projects]} project(s), " \
     "#{counts[:images]} image(s)" \
     "#{counts[:removed].positive? ? ", removed #{counts[:removed]}" : ""}" \
     "#{counts[:skipped].positive? ? " — skipped #{counts[:skipped]}" : ""}"
