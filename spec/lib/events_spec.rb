# encoding: utf-8
require File.expand_path("../../spec_helper", __FILE__)
require 'lib/event_manage/groonga_database'
require 'lib/event_manage/events'
require 'time'

module EventManage
  describe "Events" do
    before do
      @groonga_database = GroongaDatabase.new
      @groonga_database.open("test.db")
      @events = @groonga_database.events
    end

    describe "#scan_community" do
      context "イベント名の先頭にグループ名が入っているとき" do
        it "そのグループ名を返すこと" do
          expect(@events.send(:scan_community, "Aグループ総選挙")).to eq "Aグループ"
        end
      end

      context "イベント名にグループ名が2つ入っているとき" do
        it "最初のグループ名を返すこと" do
          expect(@events.send(:scan_community, "Aグループ&Bグループ総選挙")).to eq "Aグループ"
        end
      end

      context "イベント名にグループ名が入っていないとき" do
        it "nil を返すこと" do
          expect(@events.send(:scan_community, "テスト大会")).to be_nil
        end
      end
    end

    describe "#valid_community?" do
      context "nil を渡したとき" do
        it "false を返すこと" do
          expect(@events.send(:valid_community?, nil)).to be_false
        end
      end

      context "文字列 \"Null\" を渡したとき"do
        it "false を返すこと" do
          expect(@events.send(:valid_community?, "Null")).to be_false
        end
      end

      context "文字列 \"***グループ\" を渡したとき" do
        it "true を返すこと" do
          expect(@events.send(:valid_community?, "Aグループ")).to be_true
          expect(@events.send(:valid_community?, "テストグループ")).to be_true
          expect(@events.send(:valid_community?, "グループ")).to be_true
        end
      end
    end

    describe "#import_csv" do
      context "CSV を1回インポートしたとき" do
        it "レコードを1つ追加すること" do
          expect(@events.size).to eq 0
          @events.import_csv(TEST_CSV_1_PATH)
          expect(@events.size).to eq 1
        end

        it "CSV の全ての内容がDBに保存されること" do
          @events.import_csv(TEST_CSV_1_PATH)
          event = @events.key("2012010100")
          expect(event.datetime).to eq  Time.parse("2012/01/01 00:00:00")
          expect(event.title).to eq     "イベントテスト"
          expect(event.uri).to eq       "http://www.example.com/"
          expect(event.organizer).to eq "shindo200"
          expect(event.community).to eq "グループテスト"
          expect(event.venue).to eq     "地区テスト"
          expect(event.summary).to eq   "概要テスト"
          expect(event.note).to eq      "備考テスト"
        end

        it "カラムの順番が違うCSVを正しくインポートできること" do
          @events.import_csv(TEST_CSV_3_PATH)
          event = @events.key("2012010100")
          expect(event.datetime).to eq  Time.parse("2012/01/01 00:00:00")
          expect(event.title).to eq     "イベントテスト"
          expect(event.uri).to eq       "http://www.example.com/"
          expect(event.organizer).to eq "shindo200"
          expect(event.community).to eq "グループテスト"
          expect(event.venue).to eq     "地区テスト"
          expect(event.summary).to eq   "概要テスト"
          expect(event.note).to eq      "備考テスト"
        end

        it "チーム名が空のレコードは、見出しからチーム名に相当するものを探して、インポートすること" do
          @events.import_csv(TEST_CSV_2_PATH)
          event = @events.key("2012010127")
          expect(event.community).to eq "Aグループ"
        end

        it "チーム名が'Null'のレコードは、概要からチーム名に相当するものを探して、インポートすること" do
          @events.import_csv(TEST_CSV_2_PATH)
          event = @events.key("2012010129")
          expect(event.community).to eq "Aグループ"
        end
      end

      context "内容が同じ CSV を2回インポートしたとき" do
        it "重複がないようにレコードを追加すること" do
          expect(@events.size).to eq 0
          @events.import_csv(TEST_CSV_1_PATH)
          @events.import_csv(TEST_CSV_1_PATH)
          expect(@events.size).to eq 1
        end
      end

      context "内容が違う CSV をそれぞれ1回ずつインポートしたとき" do
        it "レコードを2つ追加すること" do
          expect(@events.size).to eq 0
          @events.import_csv(TEST_CSV_1_PATH)
          @events.import_csv(TEST_CSV_2_PATH)
          expect(@events.size).to eq 11
        end
      end
    end

    describe "#search" do
      context "オプションに何も渡さない場合" do
        it "title カラムを全文検索し、マッチしたイベントを返すこと" do
          @events.import_csv(TEST_CSV_1_PATH)
          records = @events.search(["イベント"]).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010100"]
        end

        it "venue カラムを全文検索し、マッチしたイベントを返すこと" do
          @events.import_csv(TEST_CSV_1_PATH)
          records = @events.search(["地区"]).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010100"]
        end

        it "summary カラムを全文検索し、マッチしたイベントを返すこと" do
          @events.import_csv(TEST_CSV_1_PATH)
          records = @events.search(["概要"]).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010100"]
        end

        it "note カラムを全文検索し、マッチしたイベントを返すこと" do
          @events.import_csv(TEST_CSV_1_PATH)
          records = @events.search(["備考"]).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010100"]
        end

        it "マッチしなかった場合は、空の配列を返すこと" do
          @events.import_csv(TEST_CSV_1_PATH)
          records = @events.search(["Nothing"]).all.map {|r| r[:_key]}
          expect(records).to eq []
        end

        it "キーワードに何も渡さなかった場合は、全てのイベントを返すこと" do
          @events.import_csv(TEST_CSV_1_PATH)
          records = @events.search([]).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010100"]
        end
      end

      context "オプションで AND 検索を指定した場合" do
        it "キーワードを全て含むイベントだけを返すこと" do
          @events.import_csv(TEST_CSV_2_PATH)
          records = @events.search(["ゲートボール","ドミノ"], operator: :and).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010121"]
        end

        it "キーワードに何も渡さなかった場合は、全てのイベントを返すこと" do
          @events.import_csv(TEST_CSV_2_PATH)
          records = @events.search([]).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010120", "2012010121", "2012010122", "2012010123", "2012010124", "2012010125", "2012010126", "2012010127", "2012010128", "2012010129"]
        end
      end

      context "オプションで検索範囲（開始日〜）を指定した場合" do
        it "検索範囲内に開催したイベントだけを返すこと" do
          @events.import_csv(TEST_CSV_2_PATH)
          start_time = "2012/01/01"
          records = @events.search(["大会"], start_time: start_time).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010120", "2012010121", "2012010122", "2012010123", "2012010124", "2012010125"]
        end
      end

      context "オプションで検索範囲（〜終了日）を指定した場合" do
        it "検索範囲内に開催したイベントだけを返すこと" do
          @events.import_csv(TEST_CSV_2_PATH)
          end_time = "2012/01/31"
          records = @events.search(["大会"], end_time: end_time).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010120", "2012010121", "2012010122", "2012010123", "2012010124", "2012010126"]
        end
      end

      context "オプションで検索範囲（開始日〜終了日）を指定した場合" do
        it "検索範囲内に開催したイベントだけを返すこと" do
          @events.import_csv(TEST_CSV_2_PATH)
          start_time = "2012/01/01"
          end_time = "2012/01/31"
          records = @events.search(["大会"], start_time: start_time, end_time: end_time).all.map {|r| r[:_key]}
          expect(records).to eq ["2012010120", "2012010121", "2012010122", "2012010123", "2012010124"]
        end
      end
    end

    describe "#get_top_community" do
      it "グループをイベント開催数が多い順に返すこと" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.get_top_community).to eq [["Aグループ", 5], ["Bグループ", 2], ["Cグループ", 1], ["Dグループ", 1]]
      end

      it "返されるグループの数を指定することができること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.get_top_community(1)).to eq [["Aグループ", 5]]
      end
    end

    describe "#get_top_supporter" do
      it "開催者をイベント開催数が多い順に返すこと" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.get_top_organizer).to eq [["Pat", 7], ["Emi", 2], ["Andy", 1]]
      end

      it "返される開催者の数を絞ることができること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.get_top_organizer(1)).to eq [["Pat", 7]]
      end
    end

    describe "#up_good_count" do
      it "good が 0 から 1 に増えること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.key("2012010120").good).to eq 0
        @events.up_good_count("2012010120")
        expect(@events.key("2012010120").good).to eq 1
      end

      it "2回実行すると good が 0 から 2 に増えること" do
        @events.import_csv(TEST_CSV_2_PATH)
        expect(@events.key("2012010120").good).to eq 0
        @events.up_good_count("2012010120")
        @events.up_good_count("2012010120")
        expect(@events.key("2012010120").good).to eq 2
      end
    end

    describe "#down_good_count" do
      it "good が 1 から 0 に減ること" do
        @events.import_csv(TEST_CSV_2_PATH)
        @events.up_good_count("2012010120")
        expect(@events.key("2012010120").good).to eq 1
        @events.down_good_count("2012010120")
        expect(@events.key("2012010120").good).to eq 0
      end

      it "2回実行すると good が 2 から 0 に減ること" do
        @events.import_csv(TEST_CSV_2_PATH)
        @events.up_good_count("2012010120")
        @events.up_good_count("2012010120")
        expect(@events.key("2012010120").good).to eq 2
        @events.down_good_count("2012010120")
        @events.down_good_count("2012010120")
        expect(@events.key("2012010120").good).to eq 0
      end
    end

    after do
      # データベースを閉じてから、テストデータベースファイルを削除する
      @groonga_database.close
      SpecDatabaseHelper.delete_test_database
    end
  end
end
