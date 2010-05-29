require 'rubygems'
require 'bundler'

Bundler.setup

ENV['RACK_ENV'] = 'test'

require 'shorty'
require 'test/unit'
require 'rack/test'

class ShortyTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def setup
    @test_url    = "http://jerodsanto.net"
    @test_shorty = "jms"
    Link.create(:url => @test_url, :shorty => @test_shorty)
  end

  def teardown
    Link.destroy_all
  end

  def app
    Shorty
  end

  def test_it_redirects_to_default_on_root_get
    get '/'
    assert last_response.status == 302
    assert last_response.headers["Location"] == Shorty::CONFIG["default_redirect"]
  end

  def test_it_redirects_to_default_on_shorty_miss
    get '/this-will-miss'
    assert last_response.status == 302
    assert last_response.headers["Location"] == Shorty::CONFIG["default_redirect"]
  end

  def test_it_redirects_to_long_url_on_shorty_hit
    get "/#{@test_shorty}"
    assert last_response.status == 302
    assert last_response.headers["Location"] == @test_url
  end

  def test_it_requires_api_key_to_post
    post '/', :url => @test_url
    assert last_response.status == 403
  end

  def test_it_returns_existing_short_url_on_post_with_existing_url
    post '/', :url => @test_url, :key => Shorty::CONFIG["access_key"]
    assert last_response.status == 200
    assert last_response.body == Shorty::CONFIG["short_domain"] + "/#{@test_shorty}"
  end

  def test_it_creates_new_shorty_on_post_with_new_url
    post '/', :url => "http://fuelyourcoding.com", :key => Shorty::CONFIG["access_key"]
    assert last_response.status == 200
    assert last_response.body =~ /#{Shorty::CONFIG["short_domain"]}\/\w{3}/
  end
end
