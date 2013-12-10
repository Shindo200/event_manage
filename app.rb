# encoding: utf-8
$LOAD_PATH.unshift File.expand_path('../', __FILE__)
require 'sinatra'
require 'rack-flash'
require 'erb'
require 'time'
require 'config/config'
require 'lib/operation_manage'

class OperationManage < Sinatra::Base
  enable :sessions
  use Rack::Flash

  helpers do
    include ApplicationHelper
  end

  before do
    @events = Events.new('application.db')
  end

  get '/' do
    load_csv(@events)

    haml :index
  end

  get '/stats' do
    redirect '/' unless params[:q]
    redirect '/' unless params[:ym]

    @keyword = SEARCH_WORD.assoc(params[:q])
    year = to_year(params[:ym])
    month = to_month(params[:ym])
    start_time = Time.parse("#{year}#{month}01")
    end_time = start_time + (60 * 60 * 24 * 31)
    records = @events.search_word(@keyword, {:start_time => start_time, :end_time => end_time})
    @result_size = records.size
    @teams = @events.get_top_team(records, 5)
    @persons = @events.get_top_person(records, 5)
    @current_page = params[:page].to_i
    @current_page = 1 if @current_page <= 0
    @last_page = ((@result_size - 1) / SHOW_EVENTS) + 1
    @paged_events = @events.paginate(records, {:page => @current_page})

    haml :stats
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
    records = @events.search_word(@keyword, {:operator => :and, :start_time => start_time, :end_time => end_time})
    @result_size = records.size
    @teams = @events.get_top_team(records, 5)
    @host_persons = @events.get_top_host_person(records, 5)
    @current_page = params[:page].to_i
    @current_page = 1 if @current_page <= 0
    @last_page = ((@result_size - 1) / SHOW_EVENTS) + 1
    @paged_events = @events.paginate(records, {:page => @current_page})

    # 検索にかかった時間を測りたい場合はコメントを外す
    #puts (Time.now - start).to_f

    haml :stats
  end

  post '/good' do
    @events.up_good_count(params[:key]) if params[:key]
    redirect "/search?q=#{uri_escape params[:q]}"
  end

  after do
    @events.close_db
  end
end
