# encoding: utf-8
require File.expand_path("../../spec_helper", __FILE__)
require 'lib/event_manage/events'
require 'time'

module EventManage
  describe Events do
    before :all do
      delete_test_database if File.exist?("#{DB_ROOT}/test.db")
    end

    before do
      @events = Events.new("test.db")
      @events.truncate
    end

    describe "#initialize" do
      it "DB が作られること" do
        expect(File.exist?("#{DB_ROOT}/test.db")).to be_true
      end
    end

    describe "#open_csv" do
      it "CSV の内容が配列で返されること" do
        assert_ary = [
          ["項番","イベントID","開催日時","イベント名","告知サイトURL","開催者","開催グループ","開催地区","概要","備考"],
          ["1","2012010100","2012/01/01 00:00:00","イベントテスト","http://www.example.com/","shindo200","グループテスト","地区テスト","概要テスト","備考テスト"]
        ]
        expect(@events.send(:open_csv, TEST_CSV_1_PATH)).to eq assert_ary
      end
    end

    describe "#import_csv" do
      it "テーブルにレコードが追加されること" do
        expect(@events.size).to eq 0
        @events.import_csv(TEST_CSV_1_PATH)
        expect(@events.size).to eq 1
      end

      it "テーブルに存在しているデータをインポートした場合、DB に保存されないこと" do
        expect(@events.size).to eq 0
        @events.import_csv(TEST_CSV_1_PATH)
        @events.import_csv(TEST_CSV_1_PATH)
        expect(@events.size).to eq 1
      end

      it "テーブルに存在していないデータをインポートした場合、DB に保存されること" do
        expect(@events.size).to eq 0
        @events.import_csv(TEST_CSV_1_PATH)
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.size).to eq 11
      end

      it "CSVの全ての内容がDBに保存されること" do
        @events.import_csv(TEST_CSV_1_PATH)
        expect(@events["2012010100"].datetime).to eq Time.parse("2012/01/01 00:00:00")
        expect(@events["2012010100"].title).to eq "イベントテスト"
        expect(@events["2012010100"].uri).to eq "http://www.example.com/"
        expect(@events["2012010100"].organizer).to eq "shindo200"
        expect(@events["2012010100"].community).to eq "グループテスト"
        expect(@events["2012010100"].venue).to eq "地区テスト"
        expect(@events["2012010100"].summary).to eq "概要テスト"
        expect(@events["2012010100"].note).to eq "備考テスト"
      end

      it "カラムの順番が違うCSVを正しくインポートできること" do
        @events.import_csv(TEST_CSV_3_PATH)
        expect(@events["2012010100"].datetime).to eq Time.parse("2012/01/01 00:00:00")
        expect(@events["2012010100"].title).to eq "イベントテスト"
        expect(@events["2012010100"].uri).to eq "http://www.example.com/"
        expect(@events["2012010100"].organizer).to eq "shindo200"
        expect(@events["2012010100"].community).to eq "グループテスト"
        expect(@events["2012010100"].venue).to eq "地区テスト"
        expect(@events["2012010100"].summary).to eq "概要テスト"
        expect(@events["2012010100"].note).to eq "備考テスト"
      end

      it "チーム名が空のレコードは、見出しからチーム名に相当するものを探して、インポートすること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events["2012010127"].community).to eq "Aグループ"
      end

      it "チーム名が'Null'のレコードは、概要からチーム名に相当するものを探して、インポートすること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events["2012010129"].community).to eq "Aグループ"
      end
    end

    describe "#search_word" do
      it "title カラムを全文検索し、マッチしたレコードが返されること" do
        @events.import_csv(TEST_CSV_1_PATH)
        record = @events.search_word(["イベント"]).map {|r| r[:_key]}
        expect(record).to eq ["2012010100"]
      end

      it "venue カラムを全文検索し、マッチしたレコードが返されること" do
        @events.import_csv(TEST_CSV_1_PATH)
        record = @events.search_word(["地区"]).map {|r| r[:_key]}
        expect(record).to eq ["2012010100"]
      end

      it "summary カラムを全文検索し、マッチしたレコードが返されること" do
        @events.import_csv(TEST_CSV_1_PATH)
        record = @events.search_word(["概要"]).map {|r| r[:_key]}
        expect(record).to eq ["2012010100"]
      end

      it "note カラムを全文検索し、マッチしたレコードが返されること" do
        @events.import_csv(TEST_CSV_1_PATH)
        record = @events.search_word(["備考"]).map {|r| r[:_key]}
        expect(record).to eq ["2012010100"]
      end

      it "マッチしなかった場合は空の配列が返されること" do
        @events.import_csv(TEST_CSV_1_PATH)
        record = @events.search_word(["Nothing"]).map {|r| r[:_key]}
        expect(record).to eq []
      end

      it "オプションで開始年月を渡した場合、その開始年月以降の入力だけ検索されること" do
        @events.import_csv(TEST_CSV_2_PATH)
        start_time = Time.parse("2012/01/01 00:00")
        record = @events.search_word(["ゲートボール"], {:start_time => start_time}).map {|r| r[:_key]}
        expect(record).to eq ["2012010120", "2012010121", "2012010124", "2012010125"]
      end
    end

    describe "#count_word_period" do
      it "指定したワードごとのイベント件数がハッシュで返されること"do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.count_word_period("2012", "01", [["ゲートボール"], ["ドミノ"]])).to eq Hash("ゲートボール"=> 3, "ドミノ"=> 2)
      end

      it "イベントは指定した年月のみで検索されること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.count_word_period("2012", "01", [["ゲートボール"]])).to eq Hash("ゲートボール"=> 3)
      end

      it "同義語をまとめて検索することができること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.count_word_period("2012", "01",[["概要","要説"]])).to eq Hash("概要" => 4)
      end
    end

    describe "#get_top_community" do
      it "イベントの中で参加の多いグループが順に返されること" do
        @events.import_csv(TEST_CSV_2_PATH)
        (2012010126..2012010129).each {|id| @events.delete(id.to_s)}
        records = @events.get_all_records
        expect(@events.get_top_community(records, 3)).to eq [["Aグループ", 3], ["Bグループ", 2], ["Cグループ", 1]]
      end

      it "返されるグループの数を指定することができること" do
        @events.import_csv(TEST_CSV_2_PATH)
        (2012010126..2012010129).each {|id| @events.delete(id.to_s)}
        records = @events.get_all_records
        expect(@events.get_top_community(records, 1)).to eq [["Aグループ", 3]]
      end

      it "グループ名が入力されていなかったレコードが含まれないこと" do
        @events.import_csv(TEST_CSV_2_PATH)
        (2012010120..2012010124).each {|id| @events.delete(id.to_s)}
        (2012010127..2012010129).each {|id| @events.delete(id.to_s)}
        records = @events.get_all_records
        expect(@events.get_top_community(records, 2)).to eq [["Cグループ", 1]]
      end
    end

    describe "#get_top_supporter" do
      it "指定したイベントの中で開催数の多い開催者が順に返されること" do
        @events.import_csv(TEST_CSV_2_PATH)
        (2012010126..2012010129).each {|id| @events.delete(id.to_s)}
        records = @events.get_all_records
        expect(@events.get_top_organizer(records, 3)).to eq [["Pat", 3], ["Emi", 2], ["Andy", 1]]
      end

      it "返される開催者の数を指定することができること" do
        @events.import_csv(TEST_CSV_2_PATH)
        (2012010126..2012010129).each {|id| @events.delete(id.to_s)}
        records = @events.get_all_records
        expect(@events.get_top_organizer(records, 1)).to eq [["Pat", 3]]
      end
    end

    describe "#up_good_count" do
      it "good が 0 から 1 に増えること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events["2012010120"][:good]).to eq 0
        @events.up_good_count("2012010120")
        expect(@events["2012010120"][:good]).to eq 1
      end

      it "2回実行すると good が 0 から 2 に増えること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events["2012010120"][:good]).to eq 0
        @events.up_good_count("2012010120")
        @events.up_good_count("2012010120")
        expect(@events["2012010120"][:good]).to eq 2
      end
    end

    describe "#down_good_count" do
      it "good が 1 から 0 に減ること" do
        @events.import_csv(TEST_CSV_2_PATH)
        @events.up_good_count("2012010120")
        expect(@events["2012010120"][:good]).to eq 1
        @events.down_good_count("2012010120")
        expect(@events["2012010120"][:good]).to eq 0
      end

      it "2回実行すると good が 2 から 0 に減ること" do
        @events.import_csv(TEST_CSV_2_PATH)
        @events.up_good_count("2012010120")
        @events.up_good_count("2012010120")
        expect(@events["2012010120"][:good]).to eq 2
        @events.down_good_count("2012010120")
        @events.down_good_count("2012010120")
        expect(@events["2012010120"][:good]).to eq 0
      end
    end

    describe "#is_valid_community?" do
      it "グループ名が空の場合は false を返すこと" do
        expect(@events.send(:is_valid_community?, nil)).to be_false
      end

      it "グループ名が 'Null' の場合は false を返すこと" do
        expect(@events.send(:is_valid_community?, "Null")).to be_false
      end

      it "有効なグループ名の場合は true を返すこと" do
        expect(@events.send(:is_valid_community?, "Aグループ")).to be_true
      end
    end

    describe "#scan_community" do
      it "イベント名の先頭にグループ名が書かれているならば、そのグループ名を返すこと" do
        expect(@events.send(:scan_community, "Aグループ総選挙")).to eq "Aグループ"
      end

      it "グループ名が2回書かれていた場合は最初のグループ名を返すこと" do
        expect(@events.send(:scan_community, "Aグループ&Bグループ総選挙")).to eq "Aグループ"
      end

      it "グループ名が書かれていない場合は nil を返すこと" do
        expect(@events.send(:scan_community, "テスト大会")).to be_nil
      end
    end

    after do
      @events.close_db
    end

    after :all do
      # テスト用DB をクリアする
      delete_test_database
    end
  end
end
