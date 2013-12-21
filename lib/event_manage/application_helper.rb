# encoding: utf-8
module EventManage
  module ApplicationHelper
    require 'uri'
    require 'rack'
    include Rack::Utils
    alias_method :h, :escape_html

    def title_escape(title, words)
      title = h(title)
      words = array_escape(words)
      title = set_match_tag(title, words)
      title
    end

    def summary_escape(summary, words)
      # 文字型ではないとsizeが使えないので文字型に変換
      summary = summary.to_s
      summary = truncate(summary)
      summary = h(summary)
      words = array_escape(words)
      summary = set_match_tag(summary, words)
      summary
    end

    def array_escape(ary)
      ary.flatten.map {|str| h(str)}
    end

    def escape_uri(str)
      URI.escape(str)
    end

    def escape_query_params(params)
      escape_uri("q=#{params[:q]}&start_time=#{params[:start_time]}&end_time=#{params[:end_time]}")
    end

    def truncate(text, opts = {})
      opts[:omission] ||= "..."
      opts[:limit] ||= 100
      if text.size > opts[:limit]
        max_size = opts[:limit] - opts[:omission].size
        text = text[0..max_size] + opts[:omission]
      end
      text
    end

    def set_match_tag(str, words)
      # HACK: "\"で検索をかけるとエラーになるので暫定対応
      begin
        words.each do |word|
          str = str.gsub(/(#{word})/i) {"\<span class=\"match\"\>#{$1}\<\/span\>"}
        end
        str
      rescue
        str
      end
    end
  end
end
