# frozen_string_literal: true
#
# Feed content filters. Mermaid diagrams render client-side (JS), so in an RSS
# feed they'd appear as raw flowchart source. Replace those blocks with a link
# back to the post, where the diagram actually renders.

module Jekyll
  module FeedFilters
    def feed_content(html, url)
      html.to_s.gsub(%r{<pre><code class="language-mermaid">.*?</code></pre>}m) do
        %(<p><em>📊 This post includes a diagram — <a href="#{url}">view it on the site</a>.</em></p>)
      end
    end
  end
end

Liquid::Template.register_filter(Jekyll::FeedFilters)
