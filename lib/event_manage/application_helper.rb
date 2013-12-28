# encoding: utf-8
module EventManage
  module ApplicationHelper
    require 'uri'
    require 'rack'
    require 'groonga'
    include Rack::Utils
    alias_method :h, :escape_html

    def snippet_title(event, keywords)
      snippet_defined_column(event, keywords, 30, :title)
    end

    def snippet_summary(event, keywords)
      snippet_defined_column(event, keywords, 100, :summary)
    end

    def snippet_defined_column(event, keywords, width, column)
      return "" if event[column].nil?
      return event[column] if keywords.size == 0

      snippet = Groonga::Snippet.new(
        width:              width,
        default_open_tag:   '<span class="match">',
        default_close_tag:  '</span>',
        html_escape:        true,
        normalize:          true
        )

      keywords.each { |keyword| snippet.add_keyword(keyword) }

      snippet.execute(event[column]).join
    end

    def escape_uri(str)
      URI.escape(str)
    end

    def escape_query_params(params)
      escape_uri("q=#{params[:q]}&start_time=#{params[:start_time]}&end_time=#{params[:end_time]}")
    end
  end
end
