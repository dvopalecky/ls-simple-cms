ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_match 'about.txt', last_response.body
    assert_match 'changes.txt', last_response.body
    assert_match 'history.txt', last_response.body
  end

  def test_viewing_text_document
    get '/about.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain;charset=utf-8', last_response['Content-Type']
    assert_equal File.read('data/about.txt'), last_response.body
  end

  def test_nonexisting_document
    get '/notafile.txt'

    assert_equal 302, last_response.status

    redirected_location = last_response["Location"]
    get redirected_location

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_match "notafile.txt doesn't exist.", last_response.body

    get redirected_location

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    refute_match "notafile.txt doesn't exist.", last_response.body
  end
end
