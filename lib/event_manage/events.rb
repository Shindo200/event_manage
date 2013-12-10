# encoding: utf-8
module EventManage
  class Events
    require 'csv'
    require 'time'
    require 'groonga'

    # TODO: eachメソッドが欲しくてgetterを作っている.自力でeventsのeachメソッドを実装する
    attr_reader :events

    def initialize(name)
      @db_path = "#{DB_ROOT}/#{name}"
      open_db
    end

    def import_csv(path)
      csv = CSV.open(path, "r",
        external_encoding: "CP932",
        internal_encoding: "UTF-8",
        headers: true
      )

      csv.each do |row|
        # 開催グループ名が無効の場合は、概要に書かれている開催グループ名を取得する。
        community = row["開催グループ"]
        community = scan_community(row["イベント名"]) unless is_valid_community?(community)

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

    def search_word(words, opts={})
      opts[:operator] ||= :or
      events = if (opts[:start_time] || opts[:end_time])
        start_time = (opts[:start_time] || Time.parse("2000/01/01"))
        end_time = (opts[:end_time] || Time.now)
        select_period(start_time, end_time)
      else
        @events
      end
      result_events = select_word(events, words, opts)
      result_events
    end

    def count_word_period(year, month, words_list)
      start_time = Time.parse("#{year}#{month}01")
      # HACK: 月に関係なく31日後を終了日としているので正確ではない
      end_time = start_time + (60 * 60 * 24 * 31)
      period_events = select_period(start_time, end_time)
      count_word = {}
      words_list.each do |words|
        count_word[words.first] = select_word(period_events, words).size
      end
      count_word
    end

    def get_top_community(events, limit)
      hash_dep = {}
      events.group("community").each do |record|
        community = record.key
        hash_dep[community] = record.n_sub_records
      end
      # 開催グループ名が空の場合の項目があるので削除
      hash_dep.delete(nil)
      communities = hash_dep.sort_by {|k,v| v}
      communities = communities.reverse.slice(0...limit)
      communities
    end

    def get_top_organizer(events, limit)
      hash_sup = {}
      events.group("organizer").each do |record|
        organizer = record.key
        hash_sup[organizer] = record.n_sub_records
      end
      organizers = hash_sup.sort_by {|k,v| v}
      organizers = organizers.reverse.slice(0...limit)
      organizers
    end

    def paginate(events, opts = {})
      opts[:page] ||= 1
      events = events.paginate([
        {:key => "good", :order => :desc},
        {:key => "datetime", :order => :desc}],
        :page => opts[:page],
        :size => SHOW_EVENTS
      )
      events
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

    def delete(key)
      @events.delete(key)
    end

    def truncate
      @events.truncate
    end

    def close_db
      @db.close
      Groonga::Context.default.close
      Groonga::Context.default = nil
      # メモリ使い過ぎでエラーが発生することがあるのでGCを実行しておく
      GC.start
    end

    private

    def open_db
      Groonga::Context.default_options = {:encoding => :utf8}
      if File.exist?(@db_path)
        @db = Groonga::Database.open(@db_path)
      else
        @db = Groonga::Database.create(:path => @db_path)
        define_schema
      end
      @events = Groonga["Events"]
    end

    def select_period(start_time, end_time)
      begin
        result_events = @events.select do |record|
          (record.datetime >= start_time) &
          (record.datetime < end_time)
        end
        result_events
      rescue
        # TODO: log出力処理
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
              select_target_column(record, word)
            end
          when :and
            words.map {|word| select_target_column(record, word)}
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

    def select_target_column(record, word)
      (record.title =~ word) |
      (record.venue =~ word) |
      (record.summary =~ word) |
      (record.note =~ word)
    end

    def is_valid_community?(community)
      return false if community.nil?
      return false if community == 'Null'
      true
    end

    def scan_community(title)
      title.scan(/^(.*?(グループ))/).flatten.shift
    end

    def define_schema
      Groonga::Schema.create_table("Events", :type => :hash) do |table|
        table.time "datetime"
        table.text "title"
        table.string "uri"
        table.string "organizer"
        table.string "community"
        table.text "venue"
        table.text "summary"
        table.text "note"
        table.integer "good"
      end
      Groonga::Schema.create_table("Terms",
        :type => :patricia_trie,
        :key_normalize => true,
        :default_tokenizer => "TokenBigram")
      Groonga::Schema.change_table("Terms") do |table|
        table.index("Events.title")
        table.index("Events.venue")
        table.index("Events.summary")
        table.index("Events.note")
      end
    end
  end
end
