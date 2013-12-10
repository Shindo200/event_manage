# encoding: utf-8
module OperationManage
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
      csv = open_csv(path)
      csv_head = csv.shift
      column_index = {
        :key => csv_head.index("ID"),
        :datetime => csv_head.index("日時"),
        :summary => csv_head.index("イベント名"),
        :code => csv_head.index("イベントコード"),
        :host_person => csv_head.index("開催者"),
        :team => csv_head.index("チーム名"),
        :progress => csv_head.index("途中経過"),
        :result => csv_head.index("結果"),
        :note => csv_head.index("備考")
      }
      csv.each do |col|
        key = col[column_index[:key]]
        # team とsummary だけ次の処理で使うので先に取得
        team = col[column_index[:team]]
        summary = col[column_index[:summary]]
        # 無効な部署名の場合は概要に書かれている部署名を利用する
        team = scan_team(summary) unless is_valid_team?(team)

        attributes = {
          :datetime => Time.parse(col[column_index[:datetime]]),
          :summary => summary,
          :code => col[column_index[:code]],
          :host_person => col[column_index[:host_person]],
          :team => team,
          :progress => col[column_index[:progress]],
          :result => col[column_index[:result]],
          :note => col[column_index[:note]],
          :good => 0
        }
        @events.add(key, attributes)
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

    def get_top_team(events, limit)
      hash_dep = {}
      events.group("team").each do |record|
        team = record.key
        hash_dep[team] = record.n_sub_records
      end
      # 部署が空の場合の項目があるので削除
      hash_dep.delete(nil)
      teams = hash_dep.sort_by {|k,v| v}
      teams = teams.reverse.slice(0...limit)
      teams
    end

    def get_top_host_person(events, limit)
      hash_sup = {}
      events.group("host_person").each do |record|
        host_person = record.key
        hash_sup[host_person] = record.n_sub_records
      end
      host_persons = hash_sup.sort_by {|k,v| v}
      host_persons = host_persons.reverse.slice(0...limit)
      host_persons
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

    def open_csv(path)
      csv = CSV.open(path, 'r:CP932:UTF-8')
      csv.to_a
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
      (record.summary =~ word) |
      (record.progress =~ word) |
      (record.result =~ word) |
      (record.note =~ word)
    end

    def is_valid_team?(team)
      return false if team.nil?
      return false if team == 'Null'
      true
    end

    def scan_team(summary)
      summary.scan(/^(.*?(チーム))/).flatten.shift
    end

    def define_schema
      Groonga::Schema.create_table("Events", :type => :hash) do |table|
        table.time "datetime"
        table.text "summary"
        table.string "code"
        table.string "host_person"
        table.string "team"
        table.text "progress"
        table.text "result"
        table.text "note"
        table.integer "good"
      end
      Groonga::Schema.create_table("Terms",
        :type => :patricia_trie,
        :key_normalize => true,
        :default_tokenizer => "TokenBigram")
      Groonga::Schema.change_table("Terms") do |table|
        table.index("Events.summary")
        table.index("Events.progress")
        table.index("Events.result")
        table.index("Events.note")
      end
    end
  end
end
