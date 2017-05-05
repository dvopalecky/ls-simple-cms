ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm Dir[File.join(data_path,'*.md')]
    FileUtils.rm Dir[File.join(data_path,'*.txt')]
    FileUtils.rmdir data_path
  end

  def create_document(name, content='')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def test_index
    create_document 'about.md'
    create_document 'changes.txt'

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_match 'about.md', last_response.body
    assert_match 'changes.txt', last_response.body
    assert_match '<a href="/about.md/edit">Edit</a>', last_response.body
  end

  def test_viewing_text_document
    content = "History of the World\nIn the beginning was the Word.\n"
    create_document 'history.txt', content

    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain;charset=utf-8', last_response['Content-Type']
    assert_equal content, last_response.body
  end

  def test_viewing_markup_document
    content = "# Jan Amos Komenský\n\n## Basic info\n"
    create_document 'about.md', content

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_match '<h1>Jan Amos Komenský</h1>', last_response.body
  end

  def test_editing_document
    content = "# Jan Amos Komensky\n\n## Basic info\n"
    create_document 'about.md', content

    get '/about.md/edit'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_match /<textarea.*>.*Jan Amos/, last_response.body
    assert_match "<button type=\"submit\"", last_response.body
  end

  def test_updating_existing_document
    create_document 'changes.txt', 'something random'
    test_creating_new_document
  end

  def test_creating_new_document
    post '/changes.txt', content: 'new content'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_match "changes.txt has been updated.", last_response.body

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_match 'new content', last_response.body
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
