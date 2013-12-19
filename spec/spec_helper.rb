# encdoing: utf-8
$LOAD_PATH.unshift File.expand_path('../../',__FILE__)
require 'rspec'
require 'config/config'

TEST_EVENT_CSV_PATH = "#{APP_ROOT}/spec/tmp/test_event.csv"
CHANGED_ORDER_CSV_PATH = "#{APP_ROOT}/spec/tmp/changed_order.csv"
TEST_OTHER_EVENT_CSV_PATH = "#{APP_ROOT}/spec/tmp/test_other_event.csv"
TEST_MANY_EVENTS_CSV_PATH = "#{APP_ROOT}/spec/tmp/test_many_events.csv"

module EventManage
  module SpecDatabaseHelper
    module_function

    # test.db というデータベースファイルをまとめて削除する
    def delete_test_database
      begin
        # 想定していないファイルが消えることを防ぐため、DB_ROOT がnilの場合はエラー扱いにする
        raise unless DB_ROOT
        Dir::glob("#{DB_ROOT}/test.db*").each { |f| File.delete(f) }
      rescue
        warn "\nWARNING: データベースファイルの保存先が指定されていません。"
        warn "テストデータベースファイルの削除処理を中止しました。"
      end
    end
  end
end
