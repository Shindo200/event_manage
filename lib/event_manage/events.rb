# encoding: utf-8
require 'csv'
require 'time'
require 'groonga'
require 'lib/event_manage/groonga_database'
require 'pry'

module EventManage
  class Events
    attr_reader :current_page

    def self.define_schema
      Groonga::Schema.create_table("Events", type: :hash) do |table|
        table.time    "datetime"
        table.text    "title"
        table.string  "uri"
        table.string  "organizer"
        table.string  "community"
        table.text    "venue"
        table.text    "summary"
        table.text    "note"
        table.integer "good"
      end

      Groonga::Schema.create_table("Terms",
        :type               => :patricia_trie,
        :key_normalize      => true,
        :default_tokenizer  => "TokenBigram")

      Groonga::Schema.change_table("Terms") do |table|
        table.index("Events.title")
        table.index("Events.venue")
        table.index("Events.summary")
        table.index("Events.note")
      end
    end

    def initialize(events, current_page = nil)
      @events = events
      @current_page = current_page
    end

    def size
      @events.size
    end

    def key(event_key)
      @events[event_key]
    end

    def each
      @events.select.each { |event| yield event }
    end

    def all
      @events.select
    end

    def last_page
      # 最終ページ数
      ((@events.size - 1) / SHOW_EVENTS) + 1
    end

    def first_page?
      @current_page == 1
    end

    def last_page?
      @current_page == last_page
    end

    def delete(key)
      @events.delete(key)
    end

    def truncate
      @events.truncate
    end

    # 指定した CSV ファイルの内容を DB に追加する
    def import_csv(path)
      csv = CSV.open(path, "r",
        external_encoding: "CP932",
        internal_encoding: "UTF-8",
        headers: true
      )

      csv.each do |row|
        # 開催グループ名が無効の場合は、概要に書かれている開催グループ名を取得する。
        community = row["開催グループ"]
        community = scan_community(row["イベント名"]) unless valid_community?(community)

        attributes = {
          datetime:   Time.parse(row["開催日時"]),
          title:      row["イベント名"],
          uri:        row["告知サイトURL"],
          organizer:  row["開催者"],
          community:  community,
          venue:      row["開催地区"],
          summary:    row["概要"],
          note:       row["備考"],
          good:       0
        }

        # Events データベースに、key がイベントIDとなるデータを追加する。
        @events.add(row["イベントID"], attributes)
      end
    end

    def search(words, opts = {})
      opts[:operator] ||= :or

      result = @events.select do |event|
        expression = nil

        # 開始年月日を指定した場合、その年月日で Event を絞り込む
        if opts[:start_time]
          sub_expression = event.datetime >= Time.parse(opts[:start_time])
          if expression.nil?
            expression = sub_expression
          else
            expression &= sub_expression
          end
        end

        # 終了年月日を指定した場合、その年月日で Event を絞り込む
        if opts[:end_time]
          # 終了年月日で指定した日にちの 23:59:59 まで取得したいので、
          # (イベント開始日時 < 終了年月日の翌日) を検索条件とする
          end_time = Time.parse(opts[:end_time]) + 60 * 60 * 24
          sub_expression = event.datetime < end_time
          if expression.nil?
            expression = sub_expression
          else
            expression &= sub_expression
          end
        end

        # 指定した単語で Event を絞り込む
        sub = word_expression(event, words, opts[:operator])
        if expression.nil?
          expression = sub
        else
          expression &= sub
        end

        # 何も条件を指定しなかったとき、全ての Event を取り出す
        expression = event if expression.nil?

        expression
      end

      Events.new(result, @current_page)
    end

    def paginate(opts = {})
      opts[:page] ||= 1

      events = @events.paginate([
        {:key => "good",     :order => :desc},
        {:key => "datetime", :order => :desc}],
        :page => opts[:page],
        :size => SHOW_EVENTS
      )

      Events.new(events)
    end

    def up_good_count(key)
      @events[key][:good] += 1
    end

    def down_good_count(key)
      @events[key][:good] -= 1
    end

    def get_top_community(limit = nil)
      hash_dep = {}
      @events.group("community").each do |event|
        community = event.key
        hash_dep[community] = event.n_sub_records
      end
      # 開催グループ名が空のイベントを結果を取り除く
      hash_dep.delete(nil)

      # 開催数が多い順でソートする
      communities = hash_dep.sort_by {|_k,v| v}.reverse

      communities.slice!(limit..-1) unless limit.nil?

      communities
    end

    def get_top_organizer(limit = nil)
      hash_sup = {}
      @events.group("organizer").each do |event|
        organizer = event.key
        hash_sup[organizer] = event.n_sub_records
      end
      # 開催数が多い順でソートする
      organizers = hash_sup.sort_by {|_k,v| v}.reverse

      organizers.slice!(limit..-1) unless limit.nil?

      organizers
    end

    def paginate(page = 1)
      # ページ数が 1 未満の場合は、self を返す
      return self if page < 1

      # 最終ページ数より大きいページ数の場合は、最終ページ数でページングする
      page = last_page if page > last_page

      events = @events.paginate([
        {:key => "good",     :order => :desc},
        {:key => "datetime", :order => :desc}],
        :page => page,
        :size => SHOW_EVENTS
      )

      Events.new(events, page)
    end

    private

    def scan_community(title)
      title.scan(/^(.*?(グループ))/).flatten.shift
    end

    def valid_community?(community)
      return false if community.nil?
      return false if community == 'Null'
      true
    end

    def word_expression(event, words, operator)
      sub = nil

      words.each do |word|
        e = target_column(event, word)
        if sub.nil?
          sub = e
        else
          case operator
            when :or
              sub |= e
            when :and
              sub &= e
          end
        end
      end

      sub
    end

    def target_column(event, word)
      # 検索対象となるカラム
      # Groonga 特有の式で解釈されるので、| で式を繋ぐこと
      (event.title   =~ word) |
      (event.venue   =~ word) |
      (event.summary =~ word) |
      (event.note    =~ word)
    end
  end
end
