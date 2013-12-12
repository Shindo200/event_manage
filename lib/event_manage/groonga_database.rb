# encoding:utf-8
require "config/config"
require "groonga"

module EventManage
  class GroongaDatabase
    def initialize
      @database = nil
    end

    def open(file_name)
      # このメソッドは引数が1つのブロックを受け取ることができる
      # ブロック引数には Groonga["Events"] オブジェクトが渡される
      # ブロックの処理を終えたときに、データベースを閉じる

      if opened?
        # TODO: 既にデータベースを開いているときのエラー処理を実装する
        return false
      end

      file_path = "#{DB_ROOT}/#{file_name}"

      Groonga::Context.default_options = { encoding: :utf8 }
      if File.exist?(file_path)
        @database = Groonga::Database.open(file_path)
      else
        @database = Groonga::Database.create(path: file_path)
        define_schema
      end

      if block_given?
        # ブロック内の処理を実行し、終わったらデータベースを閉じる
        begin
          yield(Groonga["Events"])
        ensure
          close
        end
      end
    end

    def close
      @database.close if opened?
      @database = nil
      Groonga::Context.default.close
      Groonga::Context.default = nil
    end

    def opened?
      !!@database
    end

    private

    def define_schema
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
  end
end
