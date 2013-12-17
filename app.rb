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
      @database.open(DB_FILE_NAME)

      if File.exist?(CSV_PATH)
        @database.events.import_csv(CSV_PATH)
        Dir::glob("#{CSV_PATH}*").each {|f| File.delete(f)}
      end

      haml :index
    end

    get '/search' do
      redirect '/' unless params[:q]

      # 検索にかかった時間を測りたい場合はコメントを外す
      #start = Time.now

      @keyword = params[:q].gsub(/　/, ' ').split
      begin
        start_time = Time.parse(params[:start_time]) unless params[:start_time].blank?
        # 終了期間+1日までの範囲を検索
        end_time = Time.parse(params[:end_time]) + (60 * 60 * 24) unless params[:end_time].blank?
      rescue
        # Time.parseに失敗した場合
        flash[:notice] = "検索期間の入力が不正です。正しい日付を入力してください。"
        redirect '/'
      end

      @events = Events.search(@keyword, {:operator => :and, :start_time => start_time, :end_time => end_time})
      @communities = @events.get_top_community(5)
      @organizers = @events.get_top_organizer(5)

      @current_page = params[:page].to_i
      @current_page = 1 if @current_page <= 0
      @last_page = ((@result_size - 1) / SHOW_EVENTS) + 1
      @paged_events = @events.paginate(page: @current_page)

      # 検索にかかった時間を測りたい場合はコメントを外す
      #puts (Time.now - start).to_f

      haml :stats
    end

    post '/good' do
      #@events.up_good_count(params[:key]) if params[:key]
      #redirect "/search?q=#{uri_escape params[:q]}"
    end
  end
end
