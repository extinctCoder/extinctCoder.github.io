#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Validates the "standard shape" of posts and projects before a build.
# Run from the repo root:  ruby tools/validate-content.rb
# Exits non-zero (failing CI) if any file is missing required front matter.

require "yaml"
require "date"

errors = []

def split_doc(path)
  raw = File.read(path)
  return [nil, raw] unless raw.start_with?("---")

  parts = raw.split("---", 3)
  return [nil, raw] if parts.size < 3

  fm = YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true) || {}
  [fm, parts[2]]
rescue StandardError => e
  raise "#{path}: invalid front-matter YAML — #{e.message}"
end

def present?(value)
  !value.nil? && !value.to_s.strip.empty?
end

# ── Posts ─────────────────────────────────────────────────────────────────
posts = Dir.glob("_posts/*.md").sort
posts.each do |f|
  fm, = split_doc(f)
  if fm.nil?
    errors << "#{f}: missing front matter"
    next
  end

  %w[title description date categories tags].each do |key|
    errors << "#{f}: missing '#{key}'" unless present?(fm[key])
  end

  %w[categories tags].each do |key|
    next unless fm[key]
    errors << "#{f}: '#{key}' must be a list" unless fm[key].is_a?(Array)
  end

  if fm["categories"].is_a?(Array) && fm["categories"].size > 2
    errors << "#{f}: 'categories' has #{fm['categories'].size} (Chirpy supports max 2)"
  end

  if fm["description"].is_a?(String) && fm["description"].length > 200
    errors << "#{f}: 'description' is #{fm['description'].length} chars (keep <= ~160 for SEO)"
  end
end

# ── Projects ──────────────────────────────────────────────────────────────
projects = Dir.glob("_projects/*.md").sort
projects.each do |f|
  fm, body = split_doc(f)
  if fm.nil?
    errors << "#{f}: missing front matter"
    next
  end

  %w[title description order tech].each do |key|
    errors << "#{f}: missing '#{key}'" unless present?(fm[key])
  end

  errors << "#{f}: 'order' must be a number" unless fm["order"].is_a?(Integer)
  errors << "#{f}: 'tech' must be a list" if fm["tech"] && !fm["tech"].is_a?(Array)
  errors << "#{f}: 'mermaid' should be true" unless fm["mermaid"] == true
  errors << "#{f}: 'toc' should be true" unless fm["toc"] == true
  errors << "#{f}: missing the '## At a glance' section" unless body.to_s.include?("## At a glance")
end

# ── Report ──────────────────────────────────────────────────────────────────
if errors.empty?
  puts "✓ content shape OK — #{posts.size} posts, #{projects.size} projects"
else
  warn "✗ content validation failed (#{errors.size} issue(s)):"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
