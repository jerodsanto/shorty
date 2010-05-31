require 'sinatra'
require 'lib/authorization'
require 'haml'
require 'mongoid'

class Shorty < Sinatra::Base
  configure do
    CONFIG = YAML.load_file("config.yml")[ENV['RACK_ENV']] rescue raise(LoadError, "problem with config.yml")
    Mongoid.database = Mongo::Connection.new(CONFIG['mongo_host'],CONFIG['mongo_port']).db(CONFIG['mongo_db'])
    set :authorization_realm, "Admins Only"
  end

  helpers do
    include Sinatra::Authorization

    def authorize(login, password)
      login == CONFIG['admin_login'] && password == CONFIG['admin_pass']
    end

    def generate_short_code
      chars = ['A'..'Z', 'a'..'z', '0'..'9'].map{ |r| r.to_a }.flatten
      Array.new(3).map{ chars[rand(chars.size)] }.join
    end
  end

  get '/' do
    redirect CONFIG['default_redirect']
  end

  get '/:shorty' do
    link = Link.where(:shorty => params[:shorty]).first

    redirect CONFIG['default_redirect'] if link.nil?

    referrer = Referrer.new(:url => @request.env['HTTP_REFERRER'])
    link.referrers << referrer
    referrer.save
    redirect link.url
  end

  get '/:shorty/stats' do
    login_required
    @link = Link.where(:shorty => params[:shorty]).first

    redirect CONFIG['default_redirect'] if @link.nil?

    haml :stats
  end

  post '/' do
    halt 403, "These aren't the droids you're looking for." unless params[:key] == CONFIG['access_key']

    link = Link.where(:url => params[:url]).first

    if link.nil?
      begin
        shorty = generate_short_code
      end while Link.where(:shorty => shorty).size > 0
      link = Link.create(:url => params[:url], :shorty => shorty)
    end

    "#{CONFIG['short_domain']}/#{link.shorty}"
  end
end

class Link
  include Mongoid::Document
  include Mongoid::Timestamps
  embeds_many :referrers

  field :url
  field :shorty
  index :shorty

  validates_uniqueness_of :url, :shorty
end

class Referrer
  include Mongoid::Document
  include Mongoid::Timestamps
  embedded_in :link, :inverse_of => :referrers

  field :url
end
