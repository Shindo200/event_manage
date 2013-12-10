# encoding: utf-8
module OperationManage
  module ApplicationHelper
    require 'uri'
    require 'rack'
    include Rack::Utils
    alias_method :h, :escape_html

    def load_csv(issues)
      if File.exist?(CSV_PATH)
        issues.import_csv(CSV_PATH)
        Dir::glob("#{CSV_PATH}*").each {|f| File.delete(f)}
      end
    end

    def to_year(ym)
      year = ym[0, 4]
      return nil unless year.to_i >= 2000 && year.to_i <= 3000
      year
    end

    def to_month(ym)
      month = ym[5, 2]
      return nil unless month.to_i >= 1 && month.to_i <= 12
      month
    end

    def summary_escape(summary, words)
      summary = h(summary)
      words = array_escape(words)
      summary = set_match_tag(summary, words)
      summary
    end

    def description_escape(description, words)
      # 文字型ではないとsizeが使えないので文字型に変換
      description = description.to_s
      description = html_slice(description)
      description = h(description)
      words = array_escape(words)
      description = set_match_tag(description, words)
      description
    end

    def array_escape(ary)
      ary.flatten.map {|str| h(str)}
    end

    def uri_escape(str)
      str = h(str)
      str = URI.escape(str)
      str
    end

    def query_params(params)
      "q=#{params[:q]}&start_time=#{params[:start_time]}&end_time=#{params[:end_time]}"
    end

    def html_slice(str)
      return str if str.size <= 100
      str = "#{str.slice(0...100)} ..."
      str
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
