#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Sync published notes from an exported Obsidian vault into the Jekyll site.
#
#   ruby tools/sync-vault.rb <export-dir> [--dry-run]
#
# <export-dir> holds `blog/` and `projects/` as clean Markdown (output of
# `obsidian-export`). Only notes with `publish: true` are copied in:
#   blog/*.md     -> _posts/YYYY-MM-DD-slug.md
#   projects/*.md -> _projects/slug.md
# On the way in: the `publish` flag is stripped; %%comments%% removed; math:/
# mermaid: flags added when needed; body images AND a front-matter cover `image:`
# are copied into assets/img/obsidian/<slug>/ (downscaled if ImageMagick is
# present) with their paths rewritten.
#
# It also removes notes that are no longer published — anything the previous
# manifest (.obsidian-sync.json) recorded but this run didn't produce. Cleanup
# only ever touches manifest-recorded paths (hand-authored files are never at
# risk) and refuses to run if the result looks like an export failure.
#
# --dry-run prints what would be written/removed without touching anything.

require "yaml"
require "date"
require "json"
require "fileutils"
require_relative "obsidian_md"

DRY = !ARGV.delete("--dry-run").nil?
export = ARGV[0] || "vault-export"
abort "✗ export dir not found: #{export}" unless Dir.exist?(export)

# Synced image attachments land here, namespaced per note to avoid collisions.
ASSET_ROOT = "assets/img/obsidian"
# Record of everything the previous sync produced — drives unpublish cleanup.
MANIFEST = ".obsidian-sync.json"
# Raster formats worth shrinking (skip SVG/GIF).
RASTER = %w[.png .jpg .jpeg .webp].freeze

# ── filesystem ops (honor --dry-run) ─────────────────────────────────────────
def fs_write(path, content)
  DRY ? puts("  • would write #{path}") : File.write(path, content)
end

def fs_cp(src, dest)
  DRY ? puts("  • would copy → #{dest}") : FileUtils.cp(src, dest)
end

def fs_rm(path)
  DRY ? puts("  • would remove #{path}") : FileUtils.rm_f(path)
end

def fs_mkdir(path)
  FileUtils.mkdir_p(path) unless DRY
end
fs_mkdir("_posts")
fs_mkdir("_projects")

# ── helpers ──────────────────────────────────────────────────────────────────
def split_doc(path)
  raw = File.read(path)
  return [nil, nil, raw] unless raw.start_with?("---")

  parts = raw.split("---", 3)
  return [nil, nil, raw] if parts.size < 3

  fm = YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
  [fm, parts[1], parts[2]] # parsed hash, raw front-matter text, body
rescue Psych::SyntaxError => e
  # One unparseable note must never crash the whole sync — skip it with a notice.
  # (The vault validator catches these upstream, but this is defense in depth.)
  warn "  skip (front matter won't parse): #{path} — #{e.message}"
  [nil, nil, raw]
end

def slugify(str)
  str.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
end

# Rebuild front matter from the (possibly cover-rewritten) text, minus the
# `publish:` line, adding math:/mermaid: when the body needs them.
def front_matter(fm, fm_text, body)
  kept = fm_text.lines.reject { |l| l =~ /^\s*publish\s*:/i }.join.sub(/\A\n+/, "")
  kept += "\n" unless kept.end_with?("\n")
  ObsidianMd.flags(body).each do |flag, needed|
    kept += "#{flag}: true\n" if needed && !fm.key?(flag)
  end
  "---\n#{kept}---\n"
end

def image_tool
  return @image_tool if defined?(@image_tool)

  @image_tool = %w[magick convert].find { |t| system("command -v #{t} > /dev/null 2>&1") }
end

# Best-effort: shrink oversized images (>1600px) and strip metadata. No-op
# without ImageMagick or in --dry-run. Converts to a temp file and only swaps it
# in on success, so a failed conversion can never corrupt the copied image.
def downscale(path)
  tmp = nil
  return if DRY
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

# Pick a destination name unique within this note (so two same-named images
# from different folders don't clobber each other).
def unique_name(name, used)
  return name unless used.include?(name)

  base = File.basename(name, File.extname(name))
  ext  = File.extname(name)
  i = 1
  i += 1 while used.include?("#{base}-#{i}#{ext}")
  "#{base}-#{i}#{ext}"
end

def copy_asset(src, dest_dir, used)
  fs_mkdir(dest_dir)
  name = unique_name(File.basename(src), used)
  used << name
  dest = File.join(dest_dir, name)
  fs_cp(src, dest)
  downscale(dest)
  dest
end

def cover_path(fm)
  img = fm["image"]
  return img if img.is_a?(String)

  img["path"] if img.is_a?(Hash) # Chirpy also accepts { path:, alt: }
end

# Copy a front-matter cover image into assets and rewrite its path. Returns the
# (possibly updated) front-matter text.
def relocate_cover(fm, fm_text, note_dir, dest_dir, used, assets)
  path = cover_path(fm)
  return fm_text unless path.is_a?(String) && !path.empty?
  return fm_text if path =~ %r{\A([a-z][a-z0-9+.\-]*://|/)}i # external / already absolute

  src = File.expand_path(path, note_dir)
  return fm_text unless File.file?(src)

  dest = copy_asset(src, dest_dir, used)
  assets << dest
  fm_text.sub(path, "/#{dest}")
end

# Import one note: strip comments, relocate body images + cover (deduped,
# downscaled). Returns [content, rewritten_front_matter_text, sorted_assets].
def import_note(fm, fm_text, body, source, slug)
  note_dir = File.dirname(source)
  dest_dir = File.join(ASSET_ROOT, slug)
  DRY ? puts("  • would refresh #{dest_dir}/") : FileUtils.rm_rf(dest_dir) # no orphaned assets
  assets = []
  used = []

  content = ObsidianMd.rewrite_images(ObsidianMd.strip_comments(body)) do |target|
    src = File.expand_path(target, note_dir)
    next nil unless File.file?(src)

    dest = copy_asset(src, dest_dir, used)
    assets << dest
    "/#{dest}"
  end

  new_fm_text = relocate_cover(fm, fm_text, note_dir, dest_dir, used, assets)
  [content, new_fm_text, assets.sort]
end

def load_manifest(path)
  return [] unless File.exist?(path)

  JSON.parse(File.read(path))["notes"] || []
rescue JSON::ParserError
  []
end

# Remove outputs + assets of notes a previous sync published but this one didn't.
# Only touches manifest-recorded paths. Refuses to run if the drop looks like an
# export failure rather than a real un-publish.
def reconcile(previous, manifest, counts)
  current_outputs = manifest.map { |e| e["output"] }
  to_remove = previous.reject { |e| current_outputs.include?(e["output"]) }

  # Suspected export failure (nothing, or a big chunk, gone since last time):
  # don't delete — and keep the would-be-removed notes IN the manifest, so they
  # stay tracked and disk/manifest don't drift.
  suspect = (manifest.empty? && !previous.empty?) ||
            (previous.size >= 4 && to_remove.size > previous.size / 2)
  if suspect && to_remove.any?
    warn "  ⚠ skipping cleanup: would remove #{to_remove.size} of #{previous.size} notes — " \
         "suspected export problem. Keeping them tracked; remove by hand if that's intended."
    manifest.concat(to_remove)
    manifest.sort_by! { |e| e["output"] }
    return
  end

  current_assets = manifest.flat_map { |e| Array(e["assets"]) }
  to_remove.each do |entry|
    fs_rm(entry["output"])
    Array(entry["assets"]).each { |a| fs_rm(a) unless current_assets.include?(a) }
    counts[:removed] += 1
  end

  return if DRY

  Dir.glob(File.join(ASSET_ROOT, "*")).each do |dir|
    FileUtils.rm_rf(dir) if File.directory?(dir) && Dir.empty?(dir)
  end
end

# ── main ──────────────────────────────────────────────────────────────────────
puts "▶ dry run — no files will be written\n\n" if DRY
previous = load_manifest(MANIFEST)
published = []
manifest = []
counts = { posts: 0, projects: 0, skipped: 0, images: 0, removed: 0 }

# blog/ -> _posts/
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

  content, new_fm_text, assets = import_note(fm, fm_text, body, f, slug)
  fs_write(out, front_matter(fm, new_fm_text, body) + content)

  published << f
  manifest << { "source" => f.delete_prefix("#{export}/"), "kind" => "post",
                "output" => out, "assets" => assets }
  counts[:posts] += 1
  counts[:images] += assets.size
end

# projects/ -> _projects/
Dir.glob(File.join(export, "projects", "*.md")).sort.each do |f|
  fm, fm_text, body = split_doc(f)
  next unless fm && fm["publish"] == true

  slug = slugify(fm["title"] || File.basename(f, ".md"))
  out  = File.join("_projects", "#{slug}.md")

  content, new_fm_text, assets = import_note(fm, fm_text, body, f, slug)
  fs_write(out, front_matter(fm, new_fm_text, body) + content)

  published << f
  manifest << { "source" => f.delete_prefix("#{export}/"), "kind" => "project",
                "output" => out, "assets" => assets }
  counts[:projects] += 1
  counts[:images] += assets.size
end

manifest.sort_by! { |entry| entry["output"] } # stable order → clean diffs
reconcile(previous, manifest, counts)
fs_write(MANIFEST, "#{JSON.pretty_generate("notes" => manifest)}\n")

puts "✓ synced #{counts[:posts]} post(s), #{counts[:projects]} project(s), " \
     "#{counts[:images]} image(s)" \
     "#{counts[:removed].positive? ? ", removed #{counts[:removed]}" : ""}" \
     "#{counts[:skipped].positive? ? " — skipped #{counts[:skipped]}" : ""}" \
     "#{DRY ? "  (dry run)" : ""}"
