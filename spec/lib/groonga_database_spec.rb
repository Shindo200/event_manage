# encoding:utf-8
require File.expand_path("../../spec_helper", __FILE__)
require 'lib/event_manage/groonga_database'

module EventManage
  describe "GroongaDatabase" do
    context "データベースファイルが作られていない場合" do
      before do
        @groonga_database = GroongaDatabase.new
      end

      describe "#open" do
        it "データベースファイルが作られること" do
          @groonga_database.open("test.db")
          expect(File.exist?("#{DB_ROOT}/test.db")).to be_true
        end

        it "データベースが開かれること" do
          expect(File.exist?("#{DB_ROOT}/test.db")).to be_false
          expect(@groonga_database.opened?).to be_false
          @groonga_database.open("test.db")
          expect(@groonga_database.opened?).to be_true
        end
      end

      describe "#opened?" do
        it "False を返すこと" do
          expect(@groonga_database.opened?).to be_false
        end
      end

      after do
        # データベースを閉じてから、テストデータベースファイルを削除する
        @groonga_database.close
        SpecDatabaseHelper.delete_test_database
      end
    end

    context "データベースファイルが作られている場合" do
      before do
        @groonga_database = GroongaDatabase.new
        @groonga_database.open("test.db")
        @groonga_database.close
      end

      describe "#open" do
        context "ブロックを渡していない場合" do
          it "データベースが開かれること" do
            # #close のテストもこのテストケースに含まれている
            expect(@groonga_database.opened?).to be_false
            @groonga_database.open("test.db")
            expect(@groonga_database.opened?).to be_true
          end
        end

        context "ブロックを渡した場合" do
          it "ブロックの処理を実行すること" do
            expect(@groonga_database.opened?).to be_false
            temporary = false
            @groonga_database.open("test.db") { |database| temporary = true }
            expect(temporary).to be_true
          end

          it "ブロックの処理を終えたときに、データベースを閉じること" do
            expect(@groonga_database.opened?).to be_false
            @groonga_database.open("test.db") { |database| temporary = true }
            expect(@groonga_database.opened?).to be_false
          end
        end
      end

      describe "#opened?" do
        it "False を返すこと" do
          expect(@groonga_database.opened?).to be_false
        end
      end

      after do
        # データベースを閉じてから、テストデータベースファイルを削除する
        @groonga_database.close
        SpecDatabaseHelper.delete_test_database
      end
    end

    context "データベースが開かれている場合" do
      before do
        @groonga_database = GroongaDatabase.new
        @groonga_database.open("test.db")
      end

      describe "#open" do
        it "False を返すこと" do
          expect(@groonga_database.open("test.db")).to be_false
        end
      end

      describe "#opened?" do
        it "True を返すこと" do
          expect(@groonga_database.opened?).to be_true
        end
      end

      after do
        # データベースを閉じてから、テストデータベースファイルを削除する
        @groonga_database.close
        SpecDatabaseHelper.delete_test_database
      end
    end
  end
end
