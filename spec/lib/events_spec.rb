# encoding: utf-8
require File.expand_path("../../spec_helper", __FILE__)
require 'lib/event_manage/groonga_database'
require 'lib/event_manage/events'
require 'time'

module EventManage
  describe "Events" do
    describe "#scan_community" do
      before do
        @events = Events.new(nil)
      end

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
      before do
        @events = Events.new(nil)
      end

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
      before do
        @groonga_database = GroongaDatabase.new
        @groonga_database.open("test.db")
        @events = @groonga_database.events
      end

      context "イベントを1回インポートしたとき" do
        it "全イベント件数が 1 になること" do
          expect(@events.size).to eq 0
          @events.import_csv(TEST_EVENT_CSV_PATH)
          expect(@events.size).to eq 1
        end

        it "イベントの全ての情報が DB に保存されること" do
          @events.import_csv(TEST_EVENT_CSV_PATH)
          event = @events.key("00000000")
          expect(event.datetime).to eq  Time.parse("2012/01/01 00:00:00")
          expect(event.title).to eq     "イベントテスト"
          expect(event.uri).to eq       "http://www.example.com/"
          expect(event.organizer).to eq "shindo200"
          expect(event.community).to eq "グループテスト"
          expect(event.venue).to eq     "地区テスト"
          expect(event.summary).to eq   "概要テスト"
          expect(event.note).to eq      "備考テスト"
        end

        it "カラムの順番が違うイベントを正しくインポートできること" do
          @events.import_csv(CHANGED_ORDER_CSV_PATH)
          event = @events.key("00000000")
          expect(event.datetime).to eq  Time.parse("2012/01/01 00:00:00")
          expect(event.title).to eq     "イベントテスト"
          expect(event.uri).to eq       "http://www.example.com/"
          expect(event.organizer).to eq "shindo200"
          expect(event.community).to eq "グループテスト"
          expect(event.venue).to eq     "地区テスト"
          expect(event.summary).to eq   "概要テスト"
          expect(event.note).to eq      "備考テスト"
        end

        it "グループ名が空のイベントは、イベント名からグループ名に相当するものを探して、インポートすること" do
          @events.import_csv(TEST_MANY_EVENTS_CSV_PATH)
          event = @events.key("E10")
          expect(event.community).to eq "Aグループ"
        end

        it "グループ名が'Null'のイベントは、イベント名からグループ名に相当するものを探して、インポートすること" do
          @events.import_csv(TEST_MANY_EVENTS_CSV_PATH)
          event = @events.key("E20")
          expect(event.community).to eq "Aグループ"
        end
      end

      context "同じイベントを2回インポートしたとき" do
        it "全イベント件数が 1 になること" do
          expect(@events.size).to eq 0
          @events.import_csv(TEST_EVENT_CSV_PATH)
          @events.import_csv(TEST_EVENT_CSV_PATH)
          expect(@events.size).to eq 1
        end
      end

      context "イベントIDが違うイベントをそれぞれ1回ずつインポートしたとき" do
        it "全イベント件数が 2 になること" do
          expect(@events.size).to eq 0
          @events.import_csv(TEST_EVENT_CSV_PATH)
          @events.import_csv(TEST_OTHER_EVENT_CSV_PATH)
          expect(@events.size).to eq 2
        end
      end

      after do
        @groonga_database.close
        SpecDatabaseHelper.delete_test_database
      end
    end

    describe "#search" do
      before :all do
        @groonga_database = GroongaDatabase.new
        @groonga_database.open("test.db")
        @events = @groonga_database.events
        @events.import_csv(TEST_MANY_EVENTS_CSV_PATH)
      end

      context "オプションに何も渡さない場合" do
        it "title カラムを全文検索できること" do
          result_records = @events.search(["球技大会"]).all.map {|r| r[:title]}
          expect(result_records.size).to eq 21
          expect(result_records.uniq).to eq ["球技大会"]
        end

        it "venue カラムを全文検索できること" do
          result_records = @events.search(["A地区"]).all.map {|r| r[:venue]}
          expect(result_records.size).to eq 21
          expect(result_records.uniq).to eq ["A地区"]
        end

        it "summary カラムを全文検索できること" do
          result_records = @events.search(["サッカー"]).all.map {|r| r[:summary]}
          expect(result_records.size).to eq 14
          expect(result_records.uniq).to eq ["サッカー"]
        end

        it "note カラムを全文検索し、マッチしたイベントを返すこと" do
          result_records = @events.search(["初心者のみ"]).all.map {|r| r[:note]}
          expect(result_records.size).to eq 42 
          expect(result_records.uniq).to eq ["初心者のみ"]
        end

        it "マッチしなかった場合は、空の配列を返すこと" do
          result_records = @events.search(["Nothing"]).all.map {|r| r[:_key]}
          expect(result_records.size).to eq 0
        end

        it "title, venue, summary, note のカラムで OR 検索を行うこと" do
          result_records = @events.search(["球技大会","竜王戦"]).all.map {|r| [r[:title], r[:venue], r[:summary], r[:note]]}
          expect(result_records.size).to eq 35
          expect(result_records.flatten.uniq.include?("球技大会")).to be_true
          expect(result_records.flatten.uniq.include?("竜王戦")).to be_true
        end

        it "キーワードに何も渡さなかった場合は、全てのイベントを返すこと" do
          result_records = @events.search([]).all.map {|r| r[:_key]}
          all_records = [
            "E01", "E02", "E03", "E04", "E05", "E06", "E07", "E08", "E09", "E10",
            "E11", "E12", "E13", "E14", "E15", "E16", "E17", "E18", "E19", "E20",
            "E21", "E22", "E23", "E24", "E25", "E26", "E27", "E28", "E29", "E30",
            "E31", "E32", "E33", "E34", "E35", "E36", "E37", "E38", "E39", "E40",
            "E41", "E42", "E43", "E44", "E45", "E46", "E47", "E48", "E49", "E50",
            "E51", "E52", "E53", "E54", "E55", "E56", "E57", "E58", "E59", "E60",
            "E61", "E62", "E63", "E64", "E65", "E66", "E67", "E68", "E69", "E70"
          ]
          expect(result_records).to eq all_records
        end
      end

      context "オプションで AND 検索を指定した場合" do
        it "title, venue, summary, note のカラムで AND 検索を行うこと" do
          result_records = @events.search(["球技大会", "A地区", "サッカー", "初心者のみ"], operator: :and).all.map {|r| [r[:title], r[:venue], r[:summary], r[:note]]}
          expect(result_records.size).to eq 7
          expect(result_records.uniq).to eq [["球技大会", "A地区", "サッカー", "初心者のみ"]]
          result_records = @events.search(["球技大会", "竜王戦"], operator: :and).all.map {|r| r[:_key]}
          expect(result_records.size).to eq 0
        end

        it "キーワードに何も渡さなかった場合は、全てのイベントを返すこと" do
          result_records = @events.search([], operator: :and).all.map {|r| r[:_key]}
          all_records = [
            "E01", "E02", "E03", "E04", "E05", "E06", "E07", "E08", "E09", "E10",
            "E11", "E12", "E13", "E14", "E15", "E16", "E17", "E18", "E19", "E20",
            "E21", "E22", "E23", "E24", "E25", "E26", "E27", "E28", "E29", "E30",
            "E31", "E32", "E33", "E34", "E35", "E36", "E37", "E38", "E39", "E40",
            "E41", "E42", "E43", "E44", "E45", "E46", "E47", "E48", "E49", "E50",
            "E51", "E52", "E53", "E54", "E55", "E56", "E57", "E58", "E59", "E60",
            "E61", "E62", "E63", "E64", "E65", "E66", "E67", "E68", "E69", "E70"
          ]
          expect(result_records).to eq all_records
        end
      end

      context "オプションで検索範囲（開始日〜）を指定した場合" do
        it "検索範囲内に開催したイベントだけを返すこと" do
          start_time = "2012/01/01"
          result_records = @events.search(["大会"], start_time: start_time).all.map {|r| r[:_key]}
          filtered_records = [
            "E11", "E12", "E13", "E14", "E15", "E16", "E17", "E18", "E19", "E20",
            "E21", "E22", "E23", "E24", "E25", "E26", "E27", "E28", "E29", "E30",
            "E31", "E32", "E33", "E34", "E35", "E36", "E37", "E38", "E39", "E40",
            "E41", "E42", "E43", "E44", "E45", "E46", "E47", "E48", "E49", "E50",
            "E51", "E52", "E53", "E54", "E55", "E56", "E57", "E58", "E59", "E60",
            "E61", "E62", "E63", "E64", "E65", "E66", "E67", "E68", "E69", "E70"
          ]
          expect(result_records).to eq filtered_records
        end
      end

      context "オプションで検索範囲（〜終了日）を指定した場合" do
        it "検索範囲内に開催したイベントだけを返すこと" do
          end_time = "2012/01/31"
          result_records = @events.search(["大会"], end_time: end_time).all.map {|r| r[:_key]}
          filtered_records = [
            "E01", "E02", "E03", "E04", "E05", "E06", "E07", "E08", "E09", "E10",
            "E11", "E12", "E13", "E14", "E15", "E16", "E17", "E18", "E19", "E20",
            "E21", "E22", "E23", "E24", "E25", "E26", "E27", "E28", "E29", "E30",
            "E31", "E32", "E33", "E34", "E35", "E36", "E37", "E38", "E39", "E40",
            "E41", "E42", "E43", "E44", "E45", "E46", "E47", "E48", "E49", "E50",
            "E51", "E52", "E53", "E54", "E55", "E56", "E57", "E58", "E59", "E60"
          ]
          expect(result_records).to eq filtered_records
        end
      end

      context "オプションで検索範囲（開始日〜終了日）を指定した場合" do
        it "検索範囲内に開催したイベントだけを返すこと" do
          start_time = "2012/01/01"
          end_time = "2012/01/31"
          result_records = @events.search(["大会"], start_time: start_time, end_time: end_time).all.map {|r| r[:_key]}
          filtered_records = [
            "E11", "E12", "E13", "E14", "E15", "E16", "E17", "E18", "E19", "E20",
            "E21", "E22", "E23", "E24", "E25", "E26", "E27", "E28", "E29", "E30",
            "E31", "E32", "E33", "E34", "E35", "E36", "E37", "E38", "E39", "E40",
            "E41", "E42", "E43", "E44", "E45", "E46", "E47", "E48", "E49", "E50",
            "E51", "E52", "E53", "E54", "E55", "E56", "E57", "E58", "E59", "E60"
          ]
          expect(result_records).to eq filtered_records
        end
      end

      after :all do
        @groonga_database.close
        SpecDatabaseHelper.delete_test_database
      end
    end

    describe "#get_top_community" do
      before :all do
        @groonga_database = GroongaDatabase.new
        @groonga_database.open("test.db")
        @events = @groonga_database.events
        @events.import_csv(TEST_MANY_EVENTS_CSV_PATH)
      end

      it "グループをイベント開催数が多い順に返すこと" do
        expect(@events.get_top_community).to eq [["Aグループ", 28], ["Bグループ", 21]]
      end

      it "返されるグループの数を指定することができること" do
        expect(@events.get_top_community(1)).to eq [["Aグループ", 28]]
      end

       after :all do
        @groonga_database.close
        SpecDatabaseHelper.delete_test_database
      end
    end

    describe "#get_top_supporter" do
      before :all do
        @groonga_database = GroongaDatabase.new
        @groonga_database.open("test.db")
        @events = @groonga_database.events
        @events.import_csv(TEST_MANY_EVENTS_CSV_PATH)
      end

      it "開催者をイベント開催数が多い順に返すこと" do
        expect(@events.get_top_organizer).to eq [["User_1", 42], ["User_2", 21], ["User_3", 7]]
      end

      it "返される開催者の数を絞ることができること" do
        expect(@events.get_top_organizer(1)).to eq [["User_1", 42]]
      end

      after :all do
        @groonga_database.close
        SpecDatabaseHelper.delete_test_database
      end
    end

    describe "#up_vote" do
      before do
        @groonga_database = GroongaDatabase.new
        @groonga_database.open("test.db")
        @events = @groonga_database.events
        @events.import_csv(TEST_MANY_EVENTS_CSV_PATH)
      end

      it "1回呼び出すと vote が 0 から 1 に増えること" do
        expect(@events.key("E01").vote).to eq 0
        @events.up_vote("E01")
        expect(@events.key("E01").vote).to eq 1
      end

      it "2回呼び出すと vote が 0 から 2 に増えること" do
        expect(@events.key("E01").vote).to eq 0
        @events.up_vote("E01")
        @events.up_vote("E01")
        expect(@events.key("E01").vote).to eq 2
      end

      after do
        @groonga_database.close
        SpecDatabaseHelper.delete_test_database
      end
    end

    describe "#down_vote" do
      before do
        @groonga_database = GroongaDatabase.new
        @groonga_database.open("test.db")
        @events = @groonga_database.events
        @events.import_csv(TEST_MANY_EVENTS_CSV_PATH)
      end

      it "1回呼び出すと vote が 1 から 0 に減ること" do
        @events.up_vote("E01")
        expect(@events.key("E01").vote).to eq 1
        @events.down_vote("E01")
        expect(@events.key("E01").vote).to eq 0
      end

      it "2回呼び出すと vote が 2 から 0 に減ること" do
        @events.up_vote("E01")
        @events.up_vote("E01")
        expect(@events.key("E01").vote).to eq 2
        @events.down_vote("E01")
        @events.down_vote("E01")
        expect(@events.key("E01").vote).to eq 0
      end

      after do
        @groonga_database.close
        SpecDatabaseHelper.delete_test_database
      end
    end
  end
end
