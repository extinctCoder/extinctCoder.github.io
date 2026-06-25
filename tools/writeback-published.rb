#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Stamp `published_at` back into vault notes once the site has published them.
#
#   ruby tools/writeback-published.rb <vault-dir> [manifest]
#
# Reads the sync manifest (.obsidian-sync.json) — the set of notes the site just
# published — and for each one in <vault-dir> that doesn't already carry a
# `published_at`, inserts it into that note's front matter.
#
# Idempotent by design: a note is stamped exactly once and never rewritten, so
# repeat syncs produce no vault change — which, together with the `[skip-sync]`
# commit message, keeps the vault → site → vault loop from ever spinning.
# Existing front matter is preserved verbatim; only the one line is appended.

require "json"

vault = ARGV[0] or abort "usage: writeback-published.rb <vault-dir> [manifest]"
manifest_path = ARGV[1] || ".obsidian-sync.json"
abort "✗ vault dir not found: #{vault}"     unless Dir.exist?(vault)
abort "✗ manifest not found: #{manifest_path}" unless File.exist?(manifest_path)

notes = JSON.parse(File.read(manifest_path))["notes"] || []
stamp = Time.now.getlocal("+06:00").strftime("%Y-%m-%d %H:%M:%S %z")

stamped = 0
notes.each do |entry|
  path = File.join(vault, entry["source"].to_s)
  next unless File.file?(path)

  raw = File.read(path)
  next unless raw.start_with?("---")

  parts = raw.split("---", 3)
  next if parts.size < 3
  next if parts[1] =~ /^\s*published_at\s*:/i # already stamped — idempotent

  front = "#{parts[1].sub(/\n*\z/, "\n")}published_at: #{stamp}\n"
  File.write(path, "---#{front}---#{parts[2]}")
  stamped += 1
end

puts "✓ stamped published_at on #{stamped} vault note(s)"
