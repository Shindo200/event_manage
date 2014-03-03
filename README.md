[WIP]

# Introduction
CSV で管理されているイベント履歴ファイルをインポートして、Web 上で全文検索できるようにするアプリです。

# System Requirement
* >= Ruby 1.9.3
* >= Groonga 4.0.0

# Usage
`./tmp` にインポートしたいイベント履歴ファイルを `retrieve.csv` という名前で保存します。  
(!--- インポート時にイベント履歴ファイルは消去されます ---!)  
Rack を使ってアプリを立ち上げれば、使うことができます。
