# frozen_string_literal: true
#
# tools/obsidian_md.rb
#
# Pure (Jekyll-free) engine that bridges Obsidian-flavored Markdown — as emitted
# by `obsidian-export` (CommonMark plus a few leftovers) — to what the Chirpy
# site renders. No gems. Safe to `require` from both a Jekyll plugin
# (_plugins/obsidian.rb, render-time) and the importer (tools/sync-vault.rb,
# import-time), so there is a single source of truth for the transforms.
#
# ── WHAT IT TRANSFORMS ──────────────────────────────────────────────────────
#   Callouts    > [!tip] Title / body   → Chirpy prompt   > body\n{: .prompt-tip }
#   Highlights  ==text==                → <mark>text</mark>
#   Wikilinks   [txt](Note.md#h)        → [txt](/posts/slug/#h)   (target published)
#                                       → txt                     (target NOT published)
#   Comments    %% private %%           → removed   (import-time only — see note)
#   Flags       $$…$$ / ```mermaid      → sets math: / mermaid: true   (import-time)
#
# Every transform is FENCE-AWARE: nothing inside ``` fenced blocks or `inline`
# code is touched, so a tutorial that *shows* this syntax is left intact.
#
# ── WHAT IT DOES NOT DO (yet) ───────────────────────────────────────────────
#   • Image / attachment embeds   ![[img.png]]    — needs an asset-copy step.
#   • Block / heading transclusion ![[Note#^id]]  — no content inlining.
#   • Dataview / Tasks queries.
#   • Inline #tags → site tags.
#
# Comment-stripping is import-time, not render-time, on purpose: the site repo is
# PUBLIC, so a %% private %% note must never be committed into _posts at all.

require "cgi"

module ObsidianMd
  module_function

  # Chirpy ships four prompt styles (tip / info / warning / danger); map
  # Obsidian's longer callout vocabulary onto them.
  CALLOUT_TYPES = {
    "tip" => "tip", "hint" => "tip", "important" => "tip",
    "success" => "tip", "check" => "tip", "done" => "tip",
    "note" => "info", "info" => "info", "abstract" => "info", "summary" => "info",
    "tldr" => "info", "todo" => "info", "question" => "info", "help" => "info",
    "faq" => "info", "example" => "info", "quote" => "info", "cite" => "info",
    "warning" => "warning", "caution" => "warning", "attention" => "warning",
    "danger" => "danger", "error" => "danger", "bug" => "danger",
    "failure" => "danger", "fail" => "danger", "missing" => "danger"
  }.freeze

  SENTINEL = "\u0000" # NUL — cannot occur in real Markdown text

  # ── public entrypoints ──────────────────────────────────────────────────────

  # Render-time: presentation transforms. `resolve` maps a slug -> site URL,
  # or nil when that note isn't published.
  def render(content, resolve = ->(_slug) { nil })
    on_prose(content) do |text|
      text = callouts(text)
      masked, codes = mask_inline_code(text)
      masked = highlights(masked)
      masked = strip_block_ids(masked)
      masked = rewrite_links(masked, resolve)
      unmask_inline_code(masked, codes)
    end
  end

  # Import-time: strip Obsidian comments (privacy), fence-aware.
  def strip_comments(content)
    on_prose(content) do |text|
      masked, codes = mask_inline_code(text)
      masked = masked.gsub(/%%.*?%%/m, "")
      unmask_inline_code(masked, codes)
    end
  end

  # Which front-matter flags a note needs, judged from its body.
  def flags(content)
    prose = segments(content).select { |type, _| type == :prose }.map(&:last).join
    {
      "mermaid" => content.match?(/^[ \t]*`{3,}mermaid\b/),
      # block math, or inline math that actually contains a LaTeX-ish char
      # (so a bare "$5 and $10" doesn't trip the flag)
      "math" => prose.match?(/\$\$.+?\$\$/m) ||
                prose.match?(/(?<!\\)\$[^\s$][^\n$]*[\\^_{}][^\n$]*\$/)
    }
  end

  def slugify(str)
    str.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
  end

  # ── transforms (internal) ────────────────────────────────────────────────────

  # Apply the block to each prose segment; leave fenced-code segments verbatim.
  def on_prose(content)
    segments(content).map { |type, text| type == :code ? text : yield(text) }.join
  end

  # Split into [:code | :prose, text] segments on ``` / ~~~ fences.
  def segments(md)
    segs = []
    buf = []
    fence = nil
    md.each_line do |line|
      if fence
        buf << line
        if line.match?(/^[ \t]*#{Regexp.escape(fence)}[ \t]*$/)
          segs << [:code, buf.join]
          buf = []
          fence = nil
        end
      elsif (m = line.match(/^[ \t]*(`{3,}|~{3,})/))
        segs << [:prose, buf.join] unless buf.empty?
        buf = [line]
        fence = m[1]
      else
        buf << line
      end
    end
    segs << [fence ? :code : :prose, buf.join] unless buf.empty?
    segs
  end

  def mask_inline_code(text)
    codes = []
    masked = text.gsub(/`[^`\n]*`/) do |m|
      codes << m
      "#{SENTINEL}#{codes.size - 1}#{SENTINEL}"
    end
    [masked, codes]
  end

  def unmask_inline_code(text, codes)
    text.gsub(/#{SENTINEL}(\d+)#{SENTINEL}/) { codes[Regexp.last_match(1).to_i] }
  end

  def highlights(text)
    text.gsub(/==(?!\s)(.+?)(?<!\s)==/) { "<mark>#{Regexp.last_match(1)}</mark>" }
  end

  # Remove Obsidian block-reference markers (`^block-id`) — internal anchors that
  # carry no meaning on the site. Whole-line ids drop the line; trailing ids drop
  # just the suffix.
  def strip_block_ids(text)
    text.gsub(/^\^[A-Za-z0-9-]+[ \t]*\n?/, "")
        .gsub(/[ \t]+\^[A-Za-z0-9-]+[ \t]*$/, "")
  end

  # Marker that opens a callout, e.g. `[!tip] Title`. obsidian-export's
  # CommonMark serializer escapes the brackets (`\[!tip\]`) and may pad/blank the
  # blockquote, so the brackets are optionally backslash-escaped.
  CALLOUT_MARKER = /^\\?\[!(\w+)\\?\][+-]?[ \t]*(.*)$/

  # Convert Obsidian callout blocks into Chirpy prompts. Works on the whole
  # blockquote (not just its first line) so it survives the exporter inserting a
  # leading blank quote line and escaping the `[!type]` marker. A blockquote with
  # no marker is left untouched.
  def callouts(text)
    lines = text.lines
    out = []
    i = 0
    while i < lines.length
      unless lines[i].match?(/^[ \t]*>/)
        out << lines[i]
        i += 1
        next
      end

      block = []
      while i < lines.length && lines[i].match?(/^[ \t]*>/)
        block << lines[i]
        i += 1
      end

      inner = block.map { |l| l.sub(/^[ \t]*>[ \t]?/, "").rstrip }
      marker_at = inner.index { |l| l.match?(CALLOUT_MARKER) }

      if marker_at.nil?
        out.concat(block) # ordinary blockquote
        next
      end

      m = inner[marker_at].match(CALLOUT_MARKER)
      type  = CALLOUT_TYPES.fetch(m[1].downcase, "info")
      title = m[2].to_s.strip
      body  = inner[(marker_at + 1)..] || []
      body.shift while !body.empty? && body.first.empty?
      body.pop   while !body.empty? && body.last.empty?

      quoted = []
      quoted << "**#{title}**" unless title.empty?
      quoted.concat(body)
      rendered = quoted.map { |l| l.empty? ? ">" : "> #{l}" }.join("\n")
      out << "#{rendered}\n{: .prompt-#{type} }\n"
    end
    out.join
  end

  # Rewrite local image embeds `![alt](path)`. The block receives the decoded,
  # note-relative target and must return the new URL (after copying the file) —
  # or nil to leave the embed untouched. Remote (`http://…`) and already-absolute
  # (`/…`) targets are never touched. Fence- and inline-code-aware.
  def rewrite_images(text)
    on_prose(text) do |chunk|
      masked, codes = mask_inline_code(chunk)
      masked = masked.gsub(/!\[([^\]]*)\]\(([^)\s]+)\)/) do
        alt    = Regexp.last_match(1)
        target = Regexp.last_match(2)
        full   = Regexp.last_match(0)
        if target =~ %r{\A[a-z][a-z0-9+.\-]*://}i || target.start_with?("/")
          full
        else
          new_url = yield(CGI.unescape(target))
          new_url ? "![#{alt}](#{new_url})" : full
        end
      end
      unmask_inline_code(masked, codes)
    end
  end

  # Rewrite obsidian-export's `[text](Note.md)` links to site URLs (or plain text
  # when the target isn't a published note). Images and non-.md links untouched.
  def rewrite_links(text, resolve)
    text.gsub(/(!?)\[([^\]]*)\]\(([^)\s]+)\)/) do
      bang   = Regexp.last_match(1)
      label  = Regexp.last_match(2)
      target = Regexp.last_match(3)
      full   = Regexp.last_match(0)

      next full unless bang.empty?                            # image — leave for v2
      next full if target =~ %r{\A[a-z][a-z0-9+.\-]*://}i     # external URL
      next full if target.start_with?("#", "/", "mailto:")    # anchor / absolute / mail

      path, anchor = target.split("#", 2)
      next full unless path.downcase.end_with?(".md")

      base = File.basename(CGI.unescape(path), File.extname(path))
      url  = resolve.call(slugify(base))
      if url
        anchor && !anchor.empty? ? "[#{label}](#{url}##{slugify(anchor)})" : "[#{label}](#{url})"
      else
        label.empty? ? base : label                           # not published → plain text
      end
    end
  end
end
