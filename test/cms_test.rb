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
    assert_match 'about.md', last_response.body
    assert_match 'changes.txt', last_response.body
    assert_match 'history.txt', last_response.body
  end

  def test_viewing_text_document
    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain;charset=utf-8', last_response['Content-Type']
    assert_equal File.read('data/history.txt'), last_response.body
  end

  def test_viewing_markup_document
    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_match '<h1>Jan Amos Komenský</h1>', last_response.body
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
