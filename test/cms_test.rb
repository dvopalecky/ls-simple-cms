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

  def assert_message(location, message)
    get location

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_match message, last_response.body
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
    assert_match '<a href="/new">New document</a>', last_response.body
  end

  def test_view_new_document_form
    get '/new'

    assert_equal 200, last_response.status
    assert_match 'Add a new document', last_response.body
    assert_match '<input', last_response.body
    assert_match '<form action="/"', last_response.body
  end

  def test_create_new_document
    post '/', name: 'newfile.txt'

    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_match 'newfile.txt has been created', last_response.body

    get '/'
    assert_match 'newfile.txt', last_response.body

    get '/newfile.txt'
    assert_equal 200, last_response.status
    assert_equal '', last_response.body
  end

  def test_create_new_document_invalid_path
    post '/', name: '../hello.txt'

    assert_equal 422, last_response.status
    assert_match 'Name must contain only alphanumeric chars or . or _', last_response.body
  end

  def test_create_new_document_invalid_extension
    post '/', name: 'hello'

    assert_equal 422, last_response.status
    assert_match "Document must have .md or .txt extensions", last_response.body
  end

  def test_create_new_document_
    post '/', name: ''

    assert_equal 422, last_response.status
    assert_match 'A name is required', last_response.body
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

  def test_view_edit_form
    content = "# Jan Amos Komensky\n\n## Basic info\n"
    create_document 'about.md', content

    get '/about.md/edit'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_match /<textarea.*>.*Jan Amos/, last_response.body
    assert_match "<button type=\"submit\"", last_response.body
  end

  def test_view_edit_form_nonexisting_document
    get '/about.md/edit'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_match "Can't edit non-existing document", last_response.body
  end

  def test_updating_existing_document
    create_document 'changes.txt', 'something random'
    post '/changes.txt', content: 'new content'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_match "changes.txt has been updated.", last_response.body

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_match 'new content', last_response.body
  end

  def test_updating_nonexisting_document
    post '/changes.txt', content: 'new content'

    assert_equal 302, last_response.status

    message = "Can't edit non-existing document changes.txt"
    assert_message(last_response['Location'], message)
  end

  def test_nonexisting_document
    get '/notafile.txt'

    assert_equal 302, last_response.status

    redirected_location = last_response["Location"]

    message = "notafile.txt doesn't exist."
    assert_message(redirected_location, message)

    get redirected_location

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    refute_match "notafile.txt doesn't exist.", last_response.body
  end
end
