# frozen_string_literal: true
#
# _plugins/obsidian.rb — render-time bridge from Obsidian-flavored Markdown to
# the Chirpy theme. The transform engine lives in tools/obsidian_md.rb (pure
# Ruby, no Jekyll); this file only wires it into the build.
#
# Runs on posts and the projects collection. At render it applies the
# *presentation* transforms — callouts → Chirpy prompts, ==highlights== →
# <mark>, and [text](Note.md) wikilinks → the target's real published URL
# (or plain text when the target isn't published, so no broken links leak).
#
# NOT done here (done at import, tools/sync-vault.rb): stripping %%comments%%
# (the site repo is public) and setting math:/mermaid: flags (the content
# validator reads them from the committed front matter).

require_relative "../tools/obsidian_md"

module ObsidianPlugin
  # slug -> URL for every published post and project, built once per site.
  def self.link_map(site)
    site.instance_variable_get(:@obsidian_link_map) || begin
      map = {}
      docs = site.posts.docs + (site.collections["projects"]&.docs || [])
      docs.each do |doc|
        [doc.data["slug"], doc.data["title"]].compact.each do |key|
          map[ObsidianMd.slugify(key)] = doc.url
        end
      end
      site.instance_variable_set(:@obsidian_link_map, map)
    end
  end
end

# :documents fires for posts and every collection document. Guard so a doc is
# only transformed once even if Jekyll fans the hook out per container.
Jekyll::Hooks.register :documents, :pre_render do |doc|
  next if doc.data["_obsidian_rendered"] || doc.content.nil?

  doc.data["_obsidian_rendered"] = true
  resolve = ->(slug) { ObsidianPlugin.link_map(doc.site)[slug] }
  doc.content = ObsidianMd.render(doc.content, resolve)
end
