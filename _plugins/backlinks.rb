# frozen_string_literal: true
#
# Backlinks generator — the digital-garden "linked from" index.
#
# For every post, find which OTHER posts link to it, and expose that list as
# `page.backlinks` for the sidebar panel. Runs before render, so it reads the raw
# Markdown (wikilinks still as `[txt](Note.md)`); it resolves those the same way
# the Obsidian render plugin does, plus matches absolute `/posts/<slug>/` links.

require "set"
require "cgi"

module Jekyll
  class BacklinksGenerator < Generator
    safe true
    priority :low

    def generate(site)
      posts = site.posts.docs

      # slug/title -> url, mirroring _plugins/obsidian.rb's link map
      slug_to_url = {}
      posts.each do |p|
        [p.data["slug"], p.data["title"]].compact.each { |k| slug_to_url[slugify(k)] = p.url }
      end
      urls = posts.map(&:url).to_set

      incoming = Hash.new { |h, k| h[k] = [] }
      posts.each do |p|
        forward_urls(p.content, slug_to_url, urls).each do |target|
          incoming[target] << p unless target == p.url
        end
      end

      posts.each do |p|
        p.data["backlinks"] = incoming[p.url].uniq.sort_by(&:date).reverse
      end
    end

    private

    def slugify(str)
      str.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
    end

    # URLs of posts this content links to (absolute /posts/ links + .md wikilinks).
    def forward_urls(content, slug_to_url, urls)
      found = []
      content.to_s.scan(/(!?)\[[^\]]*\]\(([^)\s]+)\)/) do |bang, target|
        next unless bang.empty? # skip images

        path = target.split("#", 2).first
        if path.start_with?("/posts/")
          url = path.end_with?("/") ? path : "#{path}/"
          found << url if urls.include?(url)
        elsif path.downcase.end_with?(".md")
          base = File.basename(CGI.unescape(path), File.extname(path))
          url = slug_to_url[slugify(base)]
          found << url if url
        end
      end
      found.uniq
    end
  end
end
