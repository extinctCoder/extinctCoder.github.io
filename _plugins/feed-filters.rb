# frozen_string_literal: true
#
# Feed content filters — make rendered post HTML survive in a feed reader, which
# has none of the site's CSS/JS:
#   1. Mermaid diagrams render client-side (JS) → replace with a Kroki-rendered
#      PNG (light background, so it's readable in light AND dark readers).
#   2. Code blocks use Chirpy's line-number table (gutter + code + copy button),
#      which a reader can't lay out → flatten to plain <pre><code>.

require "zlib"
require "base64"
require "cgi"

module Jekyll
  module FeedFilters
    # Kroki GET URL: zlib-deflate the source, then URL-safe base64 (no padding).
    def kroki_mermaid_url(source)
      encoded = Base64.urlsafe_encode64(Zlib::Deflate.deflate(source, 9), padding: false)
      "https://kroki.io/mermaid/png/#{encoded}"
    end

    def feed_content(html, url)
      out = html.to_s

      # 1. Mermaid → Kroki PNG (server-rendered image; works without JS, light bg)
      out = out.gsub(%r{<pre><code class="language-mermaid">(.*?)</code></pre>}m) do
        source = CGI.unescapeHTML(Regexp.last_match(1).to_s)
        %(<p><img src="#{kroki_mermaid_url(source)}" alt="Diagram (rendered) — see #{url}"/></p>)
      end

      # 2. Line-numbered code table → plain <pre><code> (drop gutter, header, spans)
      out = out.gsub(%r{<div class="language-[^"]*highlighter-rouge">.*?<td class="rouge-code"><pre[^>]*>(.*?)</pre>.*?</div></div>}m) do
        code = Regexp.last_match(1).to_s.gsub(/<[^>]+>/, "")
        "<pre><code>#{code}</code></pre>"
      end

      out
    end
  end
end

Liquid::Template.register_filter(Jekyll::FeedFilters)
