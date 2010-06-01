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

  def basic_auth(user="user", password="test")
    credentials = ["#{user}:#{password}"].pack("m*")

    { "HTTP_AUTHORIZATION" => "Basic #{credentials}" }
  end

  def test_it_soft_redirects_to_default_on_root_get
    get '/'
    assert last_response.status == 302
    assert last_response.headers["Location"] == Shorty::CONFIG["default_redirect"]
  end

  def test_it_soft_redirects_to_default_on_shorty_miss
    get '/this-will-miss'
    assert last_response.status == 302
    assert last_response.headers["Location"] == Shorty::CONFIG["default_redirect"]
  end

  def test_it_hard_redirects_to_long_url_on_shorty_hit
    get "/#{@test_shorty}"
    assert last_response.status == 301
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

  def test_it_requires_basic_authentication_for_link_stats
    get "/#{@test_shorty}/stats"
    assert last_response.status == 401
  end

  def test_it_requires_proper_credentials_for_link_stats
    get "/#{@test_shorty}/stats", {}, basic_auth("bad", "nope")
    assert last_response.status == 401
  end

  def test_it_displays_stats_page_after_authentication_for_link_stats
    get "/#{@test_shorty}/stats", {}, basic_auth(Shorty::CONFIG["admin_login"],Shorty::CONFIG["admin_pass"])
    assert last_response.status == 200
    assert last_response.body =~ /Stats/
  end

  def test_it_adds_referers
    get "/#{@test_shorty}", {}, { "HTTP_REFERER" => "http://www.google.com" }
    get "/#{@test_shorty}"
    get "/#{@test_shorty}", {}, { "HTTP_REFERER" => "http://twitter.com" }

    referers = Link.where(:shorty => @test_shorty).first.referers
    assert referers.first.url == "http://www.google.com"
    assert referers.last.url == "http://twitter.com"
    assert referers.count == 3
  end

  def test_it_aggregates_referers
    get "/#{@test_shorty}", {}, { "HTTP_REFERER" => "http://www.google.com/search?q=blah" }
    get "/#{@test_shorty}", {}, { "HTTP_REFERER" => "http://www.google.com/search?q=jerod" }
    get "/#{@test_shorty}"

    referers = Link.where(:shorty => @test_shorty).first.referers
    assert referers.first.domain == "www.google.com"
    assert referers.last.domain == "unknown"
    grouped = referers.group_by(&:domain)
    assert grouped["www.google.com"].count == 2
    assert grouped["unknown"].count == 1
  end
end
