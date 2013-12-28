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
          expect(File.exist?("#{DB_ROOT}/test.db")).to be_truthy
        end

        it "データベースが開かれること" do
          expect(File.exist?("#{DB_ROOT}/test.db")).to be_falsey
          expect(@groonga_database.opened?).to be_falsey
          @groonga_database.open("test.db")
          expect(@groonga_database.opened?).to be_truthy
        end
      end

      describe "#opened?" do
        it "False を返すこと" do
          expect(@groonga_database.opened?).to be_falsey
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
            expect(@groonga_database.opened?).to be_falsey
            @groonga_database.open("test.db")
            expect(@groonga_database.opened?).to be_truthy
          end
        end

        context "ブロックを渡した場合" do
          it "ブロックの処理を実行すること" do
            expect(@groonga_database.opened?).to be_falsey
            temporary = false
            @groonga_database.open("test.db") { |database| temporary = true }
            expect(temporary).to be_truthy
          end

          it "ブロックの処理を終えたときに、データベースを閉じること" do
            expect(@groonga_database.opened?).to be_falsey
            @groonga_database.open("test.db") { |database| temporary = true }
            expect(@groonga_database.opened?).to be_falsey
          end
        end
      end

      describe "#opened?" do
        it "False を返すこと" do
          expect(@groonga_database.opened?).to be_falsey
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

      describe "#opened?" do
        it "True を返すこと" do
          expect(@groonga_database.opened?).to be_truthy
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
