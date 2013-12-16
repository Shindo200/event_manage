# encoding:utf-8
require "config/config"
require "groonga"
require "lib/event_manage/events"

module EventManage
  class GroongaDatabase
    def initialize
      @database = nil
      @events = nil
    end

    def open(file_name)
      # このメソッドは引数が1つのブロックを受け取ることができる
      # ブロック引数には self が渡される
      # ブロックの処理を終えたときに、データベースを閉じる

      file_path = "#{DB_ROOT}/#{file_name}"

      Groonga::Context.default_options = { encoding: :utf8 }
      if File.exist?(file_path)
        @database = Groonga::Database.open(file_path)
      else
        @database = Groonga::Database.create(path: file_path)
        define_schema
      end

      @events = nil

      if block_given?
        # ブロック内の処理を実行し、終わったらデータベースを閉じる
        begin
          yield self
        ensure
          close if opened?
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

    def events
      @events ||= Events.new(Groonga["Events"])
    end

    private

    def define_schema
      Events.define_schema
    end
  end
end
