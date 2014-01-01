# encoding: utf-8
$LOAD_PATH.unshift File.expand_path('../', __FILE__)
require 'sinatra'
require 'rack-flash'
require 'time'
require 'config/config'
require 'lib/event_manage'

module EventManage
  class Application < Sinatra::Base
    enable :sessions
    use Rack::Flash

    helpers do
      include ApplicationHelper
    end

    before do
      @database = GroongaDatabase.new
    end

    get '/' do
      if File.exist?(CSV_PATH)
        @database.open(DB_FILE_NAME) do |db|
          db.events.import_csv(CSV_PATH)
          Dir::glob("#{CSV_PATH}*").each {|f| File.delete(f)}
        end
      end

      haml :index
    end

    get '/search' do
      redirect '/' unless params[:q]

      # 検索にかかった時間を測りたい場合はコメントを外す
      #start = Time.now

      @keywords = params[:q].gsub(/　/, ' ').split
      begin
        # TODO: ***_time が有効な文字列がチェックする処理を入れる
        start_time = params[:start_time] unless params[:start_time].blank?
        end_time = params[:end_time] unless params[:end_time].blank?
      rescue
        flash[:notice] = "検索期間の入力が不正です。正しい日付を入力してください。"
        redirect '/'
      end

      @database.open(DB_FILE_NAME)

      @events = @database.events.search(@keywords, operator: :and, start_time: start_time, end_time: end_time)
      @top_communities = @events.get_top_community(5)
      @top_organizers = @events.get_top_organizer(5)

      @paged_events = @events.paginate(params[:page].to_i)

      # 検索にかかった時間を測りたい場合はコメントを外す
      #puts (Time.now - start).to_f

      haml :stats
    end

    post '/:event_id/up_vote' do
      # 対象のイベントの vote を1つ増やす
      @database.open(DB_FILE_NAME) { |events| events.up_vote(params[:event_id]) }
    end

    after do
      @database.close
    end
  end
end
