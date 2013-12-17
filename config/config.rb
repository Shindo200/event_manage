# encoding:utf-8

# アプリケーションのルートディレクトリ
APP_ROOT = File.expand_path("../../",__FILE__)

# データベースファイルの格納先
DB_ROOT = "#{APP_ROOT}/db"

# データベースファイル名
DB_FILE_NAME = ""

# CSV の保存先
CSV_PATH = "#{APP_ROOT}/tmp/retrieve.csv"

# アプリケーションのルート
APP_HOME = "http://localhost:3000/"

# アプリケーション名
APP_NAME = "りれきサーチ"

# アプリケーションの説明文
APP_DESCRIPTION = "イベント履歴を検索するアプリケーション"

# アプリケーションのコピーライト
APP_COPYRIGHT = "Copyright (c) 2012 Shindo200 All Rights Reserved."

# 1ページあたりの障害表示件数
SHOW_EVENTS = 20
