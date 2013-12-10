# encdoing: utf-8
$LOAD_PATH.unshift File.expand_path('../../',__FILE__)
require 'rspec'
require 'config/config'
TEST_CSV_1_PATH = "#{APP_ROOT}/spec/tmp/20121010.csv"
TEST_CSV_2_PATH = "#{APP_ROOT}/spec/tmp/20121020.csv"
TEST_CSV_3_PATH = "#{APP_ROOT}/spec/tmp/20121030.csv"

def delete_test_database
  begin
    # 想定していないファイルが消えることを防ぐため、DB_ROOT がnilの場合はエラー扱いにする
    raise unless DB_ROOT
    Dir::glob("#{DB_ROOT}/test.db*").each { |f| File.delete(f) }
  rescue
    puts "\nWARNING: Cannot load DB_ROOT. Please set DB_ROOT."
  end
end
