# encoding: utf-8
require 'csv'
require 'time'
require 'groonga'

module EventManage
  class Events
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

    def self.import_csv
      csv = CSV.open(path, "r",
        external_encoding: "CP932",
        internal_encoding: "UTF-8",
        headers: true
      )

      open_database do |events|
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
            venue:      row["開催地"],
            summary:    row["概要"],
            note:       row["備考"],
            good:       0
          }

          # Events データベースに、key がイベントIDとなるデータを追加する。
          events.add(row["イベントID"], attributes)
        end
      end
    end

    def initialize(events)
      @events = events
    end

    class << self
      def import_csv(path)
      end

      def search(words, opts={})
        opts[:operator] ||= :or
        result_events = nil

        open_database do |events|
          # 検索期間を指定した場合は、その検索期間で絞り込む
          events = select_period(events, opts[:star_time], opts[:end_time]) if opts[:start_time] || opts[:end_time]

          result_events = select_word(events, words, opts)
        end

        binding.pry
        Events.new(result_events)
      end

      private

      def select_period(events, start_time = Time.parse("2000-01-01"), end_time = Time.now)
        begin
          result_events = events.select do |record|
            (record.datetime >= start_time) &
            (record.datetime < end_time)
          end
          result_events
        rescue
          # TODO: log 出力処理
          []
        end
      end

      def select_word(events, words, opts={})
        opts[:operator] ||= :or

        begin
          result_events = events.select do |record|
            case opts[:operator]
              when :or
                words.inject(record) do |tmp_record, word|
                  tmp_record |
                  target_column(record, word)
                end
              when :and
                words.map {|word| target_column(record, word)}
              else
                raise
            end
          end
          result_events
        rescue
          # TODO: log追記処理を入れる
          []
        end
      end

      def target_column(record, word)
        # 検索対象となるカラム。
        # Groonga 特有の式で解釈されるので、| で式を繋ぐこと。
        (record.title =~ word) |
        (record.venue =~ word) |
        (record.summary =~ word) |
        (record.note =~ word)
      end

      def scan_community(title)
        title.scan(/^(.*?(グループ))/).flatten.shift
      end

      def valid_community?(community)
        return false if community.nil?
        return false if community == 'Null'
        true
      end
    end

    def initlaize(events)
      @events = events
    end

    def get_top_community(limit)
      hash_dep = {}
      @events.group("community").each do |event|
        community = event.key
        hash_dep[community] = event.n_sub_records
      end
      # 開催グループ名が空の場合の項目があるので削除
      hash_dep.delete(nil)
      communities = hash_dep.sort_by {|k,v| v}
      communities = communities.reverse.slice(0...limit)
      communities
    end

    def get_top_organizer(limit)
      hash_sup = {}
      @events.group("organizer").each do |event|
        organizer = event.key
        hash_sup[organizer] = event.n_sub_records
      end
      organizers = hash_sup.sort_by {|k,v| v}
      organizers = organizers.reverse.slice(0...limit)
      organizers
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

    def get_all_records
      @events
    end

    def [](key)
      @events[key]
    end

    def size
      @events.size
    end

    def each
      @events.each { |event| yield(event) }
    end

    def delete(key)
      @events.delete(key)
    end

    def truncate
      @events.truncate
    end
  end
end
