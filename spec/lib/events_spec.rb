# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'
require 'lib/events'
require 'time'

describe Events do
  before :all do
    delete_test_database if File.exist?("#{DB_ROOT}/test.db")
  end

  before do
    @events = Events.new("test.db")
    @events.truncate
  end

  describe "#initialize" do
    it "initializeでDBが作られること" do
      File.exist?("#{DB_ROOT}/test.db").should be_true
    end
  end

  describe "#open_csv" do
    it "CSVの内容が配列で返されること" do
      assert_ary = [
        ["項番","ID","日時","見出し","イベント名","開催者","チーム名","途中経過","結果","備考"],
        ["1","2012010100","2012/01/01 00:00:00","見出しテスト","イベントテスト","shindo200","チームテスト","経過テスト","結果テスト","備考テスト"]
      ]
      @events.send(:open_csv, TEST_CSV_1_PATH).should == assert_ary
    end
  end

  describe "#import_csv" do
    it "テーブルにレコードが追加されること" do
      @events.size.should == 0
      @events.import_csv(TEST_CSV_1_PATH)
      @events.size.should == 1
    end

    it "テーブルに存在しているデータをimportした場合、レコードは追加されないこと" do
      @events.size.should == 0
      @events.import_csv(TEST_CSV_1_PATH)
      @events.import_csv(TEST_CSV_1_PATH)
      @events.size.should == 1
    end

    it "テーブルに存在していないデータをimportした場合、レコードが追加されること" do
      @events.size.should == 0
      @events.import_csv(TEST_CSV_1_PATH)
      @events.import_csv(TEST_CSV_2_PATH)
      @events.size.should == 11
    end

    it "インポートしたCSVの内容がDBに保存されること" do
      @events.import_csv(TEST_CSV_1_PATH)
      @events["2012010100"].datetime.should == Time.parse("2012/01/01 00:00:00")
      @events["2012010100"].summary.should == "見出しテスト"
      @events["2012010100"].name.should == "イベントテスト"
      @events["2012010100"].host_person.should == "小田井"
      @events["2012010100"].team.should == "チームテスト"
      @events["2012010100"].progress.should == "経過テスト"
      @events["2012010100"].result.should == "結果テスト"
      @events["2012010100"].note.should == "備考テスト"
    end

    it "インポートしたCSVのカラムの順番がばらばらでも正しくインポートできること" do
      @events.import_csv(TEST_CSV_3_PATH)
      @events["2012010100"].datetime.should == Time.parse("2012/01/01 00:00:00")
      @events["2012010100"].summary.should == "見出しテスト"
      @events["2012010100"].name.should == "イベントテスト"
      @events["2012010100"].host_person.should == "小田井"
      @events["2012010100"].team.should == "チームテスト"
      @events["2012010100"].progress.should == "経過テスト"
      @events["2012010100"].result.should == "結果テスト"
      @events["2012010100"].note.should == "備考テスト"
    end

    it "チーム名が空の場合は見出しからチーム名を探してインポートすること" do
      @events.import_csv(TEST_CSV_2_PATH)
      @events["2012010127"].team.should == "Aチーム"
    end

    it "チーム名が'Null'の場合は概要から部署を探すしてインポートすること" do
      @events.import_csv(TEST_CSV_2_PATH)
      @events["2012010129"].team.should == "Aチーム"
    end
  end

  describe "#search_word" do
    it "summaryカラムを全文検索し、マッチしたレコードが返されること" do
      @events.import_csv(TEST_CSV_1_PATH)
      record = @events.search_word(["概要"]).map {|r| r[:_key]}
      record.should == ["2012010100"]
    end

    it "progressカラムを全文検索し、マッチしたレコードが返されること" do
      @events.import_csv(TEST_CSV_1_PATH)
      record = @events.search_word(["経過"]).map {|r| r[:_key]}
      record.should == ["2012010100"]
    end

    it "resultカラムを全文検索し、マッチしたレコードが返されること" do
      @events.import_csv(TEST_CSV_1_PATH)
      record = @events.search_word(["結果"]).map {|r| r[:_key]}
      record.should == ["2012010100"]
    end

    it "noteカラムを全文検索し、マッチしたレコードが返されること" do
      @events.import_csv(TEST_CSV_1_PATH)
      record = @events.search_word(["備考"]).map {|r| r[:_key]}
      record.should == ["2012010100"]
    end

    it "マッチしなかった場合は空の配列が返されること" do
      @events.import_csv(TEST_CSV_1_PATH)
      record = @events.search_word(["Nothing"]).map {|r| r[:_key]}
      record.should == []
    end

    it "オプションで開始年月を渡した場合、その開始年月以降の入力だけ検索されること" do
      @events.import_csv(TEST_CSV_2_PATH)
      start_time = Time.parse("2012/01/01 00:00")
      record = @events.search_word(["ゲートボール"], {:start_time => start_time}).map {|r| r[:_key]}
      record.should == ["2012010120", "2012010121", "2012010124", "2012010125"]
    end
  end

  describe "#count_word_period" do
    it "指定したワードごとのイベント件数がハッシュで返されること"do
      @events.import_csv(TEST_CSV_2_PATH)
      @events.count_word_period("2012", "01", [["ゲートボール"], ["投げる"]]).should == {"ゲートボール"=> 3, "投げる"=> 2}
    end

    it "イベントは指定した年月のみで検索されること" do
      @events.import_csv(TEST_CSV_2_PATH)
      @events.count_word_period("2012", "01", [["メール"]]).should == {"メール"=> 2}
    end

    it "同義語をまとめて検索することができること" do
      @events.import_csv(TEST_CSV_2_PATH)
      @events.count_word_period("2012", "01",[["メール","OutlookExpress"]]).should == {"メール" => 3}
    end
  end

  describe "#get_top_department" do
    it "イベントの中で参加の多いチームが順に返されること" do
      @events.import_csv(TEST_CSV_2_PATH)
      (2012010126..2012010129).each {|id| @events.delete(id.to_s)}
      records = @events.get_all_records
      @events.get_top_team(records, 3).should == [["Aチーム", 3], ["Bチーム", 2], ["Cチーム", 1]]
    end

    it "返されるチームの数を指定することができること" do
      @events.import_csv(TEST_CSV_2_PATH)
      (2012010126..2012010129).each {|id| @events.delete(id.to_s)}
      records = @events.get_all_records
      @events.get_top_team(records, 1).should == [["Aチーム", 3]]
    end

    it "チーム名が入力されていなかったレコードが含まれないこと" do
      @events.import_csv(TEST_CSV_2_PATH)
      (2012010120..2012010124).each {|id| @events.delete(id.to_s)}
      (2012010127..2012010129).each {|id| @events.delete(id.to_s)}
      records = @events.get_all_records
      @events.get_top_team(records, 2).should == [["Cチーム", 1]]
    end
  end

  describe "#get_top_supporter" do
    it "指定したイベントの中で開催数の多い開催者が順に返されること" do
      @events.import_csv(TEST_CSV_2_PATH)
      (2012010126..2012010129).each {|id| @events.delete(id.to_s)}
      records = @events.get_all_records
      @events.get_top_host_person(records, 3).should == [["Pat", 3], ["Emi", 2], ["Andy", 1]]
    end

    it "返される開催者の数を指定することができること" do
      @events.import_csv(TEST_CSV_2_PATH)
      (2012010126..2012010129).each {|id| @events.delete(id.to_s)}
      records = @events.get_all_records
      @events.get_top_host_person(records, 1).should == [["Pat", 3]]
    end
  end

  describe "#up_good_count" do
    it "goodが0から1に増えること" do
      @events.import_csv(TEST_CSV_2_PATH)
      @events["2012010120"][:good].should == 0
      @events.up_good_count("2012010120")
      @events["2012010120"][:good].should == 1
    end

    it "2回実行するとgoodが0から2に増えること" do
      @events.import_csv(TEST_CSV_2_PATH)
      @events["2012010120"][:good].should == 0
      @events.up_good_count("2012010120")
      @events.up_good_count("2012010120")
      @events["2012010120"][:good].should == 2
    end
  end

  describe "#down_good_count" do
    it "goodが1から0に減ること" do
      @events.import_csv(TEST_CSV_2_PATH)
      @events.up_good_count("2012010120")
      @events["2012010120"][:good].should == 1
      @events.down_good_count("2012010120")
      @events["2012010120"][:good].should == 0
    end

    it "2回実行するとgoodが2から0に減ること" do
      @events.import_csv(TEST_CSV_2_PATH)
      @events.up_good_count("2012010120")
      @events.up_good_count("2012010120")
      @events["2012010120"][:good].should == 2
      @events.down_good_count("2012010120")
      @events.down_good_count("2012010120")
      @events["2012010120"][:good].should == 0
    end
  end

  describe "#is_valid_department?" do
    it "チーム名が空の場合はfalseを返すこと" do
      @events.send(:is_valid_team?, nil).should be_false
    end

    it "チーム名が'Null'の場合はfalseを返すこと" do
      @events.send(:is_valid_team?, "Null").should be_false
    end

    it "有効なチーム名の場合はtrueを返すこと" do
      @events.send(:is_valid_team?, "Aチーム").should be_true
    end
  end

  describe "#scan_department" do
    it "先頭にチーム名が書かれていた場合はそのチーム名を返すこと" do
      @events.send(:scan_team, "Aチーム Pat 今日も良い天気。").should == "Aチーム"
    end

    it "チーム名が2回書かれていた場合は最初の部署名を返すこと" do
      @events.send(:scan_team, "Aチーム Pat Bチームのメンバーが怒り気味。").should == "Aチーム"
    end

    it "チーム名が書かれていない場合はnilを返すこと" do
      @events.send(:scan_team, "* Pat PCが壊れた。").should be_nil
    end
  end

  after do
    @events.close_db
  end

  after :all do
    delete_test_database
  end
end
