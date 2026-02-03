require 'feedjira'
require 'httparty'
require 'jekyll'

module ExternalPosts
  class ExternalPostsGenerator < Jekyll::Generator
    safe true
    priority :high

    def generate(site)
      sources = site.config['external_sources']
      return if sources.nil?

      sources.each do |src|
        Jekyll.logger.info "ExternalPosts:", "Fetching external posts from #{src['name']}"

        begin
          response = HTTParty.get(src['rss_url'], timeout: 10)

          if response.code != 200
            raise "HTTP #{response.code}"
          end

          body = response.body

          # Medium & others often return HTML instead of XML
          if body !~ /<rss|<feed/i
            raise "Response is not valid XML feed"
          end

          feed = Feedjira.parse(body)

          if !feed.respond_to?(:entries)
            raise "Feed has no entries"
          end
        rescue => e
          Jekyll.logger.warn "ExternalPosts:", "Skipping #{src['name']} – #{e.class}: #{e.message}"
          next
        end

        feed.entries.each do |entry|
          Jekyll.logger.info "ExternalPosts:", "Importing #{entry.url}"

          slug = entry.title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
          path = site.in_source_dir("_posts/#{slug}.md")

          doc = Jekyll::Document.new(
            path, { site: site, collection: site.collections['posts'] }
          )

          # Metadata
          doc.data['external_source'] = src['name']
          doc.data['feed_content']   = entry.respond_to?(:content) ? entry.content : entry.summary
          doc.data['title']          = entry.title
          doc.data['description']    = entry.summary
          doc.data['date']           = entry.published || Time.now
          doc.data['redirect']       = entry.url

          site.collections['posts'].docs << doc
        end
      end
    end
  end
end
