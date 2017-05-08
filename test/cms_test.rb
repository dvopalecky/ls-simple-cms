ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm Dir[File.join(data_path, "*.md")]
    FileUtils.rm Dir[File.join(data_path, "*.txt")]
    FileUtils.rm Dir[File.join(data_path, "invalid_extension.rb")]
    FileUtils.rmdir data_path
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def admin_session
    { "rack.session" => { signed_in_user: "admin" } }
  end

  def session
    last_request.env["rack.session"]
  end

  def test_index_signed_off
    get "/"

    assert_equal 200, last_response.status
    assert_match "You're signed off", last_response.body
    assert_match "<button", last_response.body
    assert_match %q(href="/users/signin"), last_response.body
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_match "about.md", last_response.body
    assert_match "changes.txt", last_response.body
    assert_match %q(<a href="/about.md/edit">Edit</a>), last_response.body
    assert_match %q(<a href="/new">New document</a>), last_response.body
    assert_match %q(<form action="/changes.txt/delete"), last_response.body
    assert_match "<button", last_response.body
    assert_match "Signed in as admin", last_response.body
    assert_match "Sign out", last_response.body
  end

  def test_sign_in_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_match "Username", last_response.body
    assert_match "Password", last_response.body
    assert_match "<form", last_response.body
    assert_match "<button", last_response.body
  end

  def test_sign_in_valid_credentials
    post "/users/signin", username: "admin", password: "secret"

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:signed_in_user]
  end

  def test_sign_in_invalid_credentials
    post "/users/signin", username: "test", password: "test"

    assert_equal 422, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_match "Invalid credentials", last_response.body
    assert_match %q(<input type="text" name="username" value="test">),
                 last_response.body
    assert_nil session[:user_signed_in]
  end

  def test_sign_in_only_username
    post "/users/signin", username: "test"

    assert_equal 422, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_match "Invalid credentials", last_response.body
    assert_match %q(<input type="text" name="username" value="test">),
                 last_response.body
    assert_nil session[:user_signed_in]
  end

  def test_sign_out
    post "/users/signout"

    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:message]
    assert_nil session[:user_signed_in]

    get last_response["Location"]
    assert_match "You're signed off", last_response.body
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_match "Add a new document", last_response.body
    assert_match "<input", last_response.body
    assert_match %q(<form action="/"), last_response.body
  end

  def test_view_new_document_form_signed_out
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document
    post "/", { name: "newfile.txt" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "newfile.txt has been created", session[:message]

    get "/"
    assert_match "newfile.txt", last_response.body

    get "/newfile.txt"
    assert_equal 200, last_response.status
    assert_equal "", last_response.body
  end

  def test_create_new_document_signed_out
    post "/", name: "newfile.txt"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    assert_equal false, File.file?(File.join(data_path, "newfile.txt"))
  end

  def test_create_new_document_invalid_path
    post "/", { name: "../hello.txt" }, admin_session

    assert_equal 422, last_response.status
    assert_match "Name must contain only alphanumeric chars or . or _",
                 last_response.body
  end

  def test_create_new_document_invalid_extension
    post "/", { name: "hello" }, admin_session

    assert_equal 422, last_response.status
    assert_match "Document must have .md or .txt extensions", last_response.body
  end

  def test_create_new_document_empty_name
    get "/", {}, admin_session
    post "/", name: ""

    assert_equal 422, last_response.status
    assert_match "A name is required", last_response.body
  end

  def test_viewing_text_document
    content = "History of the World\nIn the beginning was the Word.\n"
    create_document "history.txt", content

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
    assert_equal content, last_response.body
  end

  def test_viewing_markup_document
    content = "# Jan Amos Komenský\n\n## Basic info\n"
    create_document "about.md", content

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_match "<h1>Jan Amos Komenský</h1>", last_response.body
  end

  def test_view_edit_form
    content = "# Jan Amos Komensky\n\n## Basic info\n"
    create_document "about.md", content

    get "/about.md/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_match(/<textarea.*>.*Jan Amos/, last_response.body)
    assert_match "<button type=\"submit\"", last_response.body
  end

  def test_view_edit_form_signed_out
    create_document "about.md", "# something"
    get "/about.md/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_edit_form_nonexisting_document
    get "/about.md/edit", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "Can't edit non-existing document.", session[:message]
  end

  def test_view_edit_form_invalid_document
    create_document "invalid_extension.rb", "something"
    get "/invalid_extension.rb/edit", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "Can't edit non-existing document.", session[:message]
  end

  def test_updating_existing_document
    create_document "changes.txt", "something random"
    post "/changes.txt", { content: "new content" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_match "new content", last_response.body
  end

  def test_updating_existing_document_signed_off
    create_document "changes.txt", "old"
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    assert_equal "old", File.read(File.join(data_path, "changes.txt"))
  end

  def test_updating_nonexisting_document
    post "/changes.txt", { content: "new content" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "Can't edit non-existing document.",
                 session[:message]
  end

  def test_nonexisting_document
    get "/notafile.txt"
    assert_equal 302, last_response.status
    assert_equal "File doesn't exist.", session[:message]

    get last_response["Location"]
    assert_nil session[:message]
  end

  def test_delete_document
    create_document "file.txt", "something"
    post "/file.txt/delete", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "file.txt deleted successfully.", session[:message]
    assert_equal false, File.file?(File.join(data_path, "file.txt"))

    get last_response["Location"]
    assert_nil session[:message]
  end

  def test_delete_document_singed_off
    create_document "file.txt", "something"

    post "/file.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
    assert_equal true, File.file?(File.join(data_path, "file.txt"))
  end

  def test_delete_nonnexisting_document
    post "/file.txt/delete", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "Can't delete non-existing document.",
                 session[:message]
    assert_equal false, File.file?(File.join(data_path, "file.txt"))
  end
end
