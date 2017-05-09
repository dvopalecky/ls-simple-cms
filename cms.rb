# File based CMS

require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, escape_html: true
  if ENV["RACK_ENV"] == "test"
    set :public_folder, File.expand_path("/public", __FILE__)
  end
end

# HELPERS CALLED FROM ERB
# -----------------------------------------------------------------------------
helpers do
  def duplicate_filename(filename)
    File.basename(filename, ".*") + "_copy" + File.extname(filename)
  end
end

# HELPERS
# -----------------------------------------------------------------------------
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def images_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/public/images", __FILE__)
  else
    File.expand_path("../public/images", __FILE__)
  end
  #File.join(settings.public_folder, "images")
end

def load_file_content(path)
  content = File.read(path)

  case File.extname(path)
  when ".md"
    erb render_markdown(content)
  when ".txt"
    headers["Content-Type"] = "text/plain;charset=utf-8"
    content
  end
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def load_users_credentials
  YAML.load_file(credentials_path)
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

# returns validation boolean status and message
def validate_new_filename(filename)
  if filename.empty?
    [false, "A name is required"]
  elsif /[^\w\.]/ =~ filename
    [false, "Name must contain only alphanumeric chars or . or _"]
  elsif ![".txt", ".md"].include?(File.extname(filename))
    [false, "Document must have .md or .txt extensions"]
  elsif valid_existing_file_path(filename)
    [false, "Name already exists."]
  else
    [true, ""]
  end
end

def validate_filename(filename)
  filename = File.basename(filename)
  if [".txt", ".md"].include?(File.extname(filename))
    filename
  else
    nil
  end
end

def valid_existing_file_path(filename)
  return nil if filename.nil?
  path = File.join(data_path, filename)
  File.file?(path) ? path : nil
end

def create_new_file(filename)
  path = File.join(data_path, filename)
  File.write(path, "")
  session[:message] = "#{filename} has been created"
  redirect "/"
end

def user_signed_in?
  !!session[:signed_in_user]
end

def redirect_if_signed_out
  return if user_signed_in?
  session[:message] = "You must be signed in to do that."
  redirect "/"
end

def valid_login?(username, input_password)
  credentials = load_users_credentials
  return false unless credentials.key?(username)
  bcrypt_password = BCrypt::Password.new(credentials[username])
  bcrypt_password == input_password
end

def valid_new_username?(username)
  return false if load_users_credentials.key?(username)
  return false if /\W/ =~ username
  true
end

# ROUTES
# -----------------------------------------------------------------------------
# Show index
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir[pattern].select do |path|
    File.file?(path) && validate_filename(path)
  end
  @files = @files.map! { |file| File.basename(file) }

  image_pattern = File.join(images_path, "*.{png,jpg}")
  @images = Dir[image_pattern].select { |path| File.file?(path)}
  @images = @images.map! { |image| File.basename(image) }

  erb :index
end

# Create new document
post "/" do
  redirect_if_signed_out
  filename = params[:name]
  validation_status, validation_msg = validate_new_filename(filename)
  if validation_status
    path = File.join(data_path, filename)
    File.write(path, "")
    session[:message] = "#{filename} has been created"
    redirect "/"
  else
    session[:message] = validation_msg
    status 422
    erb :new
  end
end

# Show sign in page
get "/users/signin" do
  erb :sign_in
end

# Sign in
post "/users/signin" do
  if user_signed_in?
    session[:message] = "You're already signed in"
    redirect "/"
  else
    if valid_login?(params[:username], params[:password])
      session[:signed_in_user] = params[:username]
      session[:message] = "Welcome!"
      redirect "/"
    else
      session[:message] = "Invalid credentials"
      @username = params[:username]
      status 422
      erb :sign_in
    end
  end
end

# Sign out
post "/users/signout" do
  session.delete :signed_in_user
  session[:message] = "You have been signed out."
  redirect "/"
end

# Show sign up page
get "/users/signup" do
  erb :sign_up
end

# Sign up new user
post "/users/signup" do
  username = params[:username]
  if valid_new_username?(username)
    credentials = load_users_credentials
    credentials[username] = BCrypt::Password::create(params[:password]).to_s
    session[:message] = "User #{username} successfully created"
    File.write(credentials_path, credentials.to_yaml)
    redirect '/users/signin'
  else
    session[:message] = "Invalid username."\
      "Username already exists or contains invalid characters."
    status 422
    erb :sign_up
  end
end

# Show form for new document
get "/new" do
  redirect_if_signed_out
  erb :new
end

# Show form for uploading image
get "/upload_image" do
  redirect_if_signed_out
  erb :upload_image
end

# Upload image
post "/upload_image" do
  redirect_if_signed_out

  @filename = params[:file][:filename]
  if %w(.png .jpg).include?(File.extname(@filename))
    File.binwrite(File.join(images_path, @filename),
      params[:file][:tempfile].read)

    session[:message] = "Image has been uploaded successfully."
    redirect "/"
  else
    session[:message] = "Unsupported image format."
    status 422
    erb :upload_image
  end
end

# Show document
get "/:filename" do
  filename = validate_filename(params[:filename])
  path = valid_existing_file_path(filename)
  if path
    load_file_content(path)
  else
    session[:message] = "File doesn't exist."
    redirect "/"
  end
end

# Submit edits of document
post "/:filename" do
  redirect_if_signed_out
  filename = validate_filename(params[:filename])
  path = valid_existing_file_path(filename)
  if path
    File.write(path, params[:content])
    session[:message] = "#{filename} has been updated."
  else
    session[:message] = "Can't edit non-existing document."
  end

  redirect "/"
end

# Show form for editing document
get "/:filename/edit" do
  redirect_if_signed_out
  @filename = validate_filename(params[:filename])
  path = valid_existing_file_path(@filename)
  if path
    @content = File.read(path)
    erb :edit
  else
    session[:message] = "Can't edit non-existing document."
    redirect "/"
  end
end

# Show form for duplicating document
get "/:source_filename/duplicate" do
  redirect_if_signed_out
  @source_filename = validate_filename(params[:source_filename])
  path = valid_existing_file_path(@source_filename)
  if path
    erb :duplicate
  else
    session[:message] = "Can't duplicate non-existing document."
    redirect "/"
  end
end

# Duplicate document
post "/:source_filename/duplicate" do
  redirect_if_signed_out
  @new_filename = params[:name]
  validation_status, validation_msg = validate_new_filename(@new_filename)

  @source_filename = validate_filename(params[:source_filename])
  valid_source_path = valid_existing_file_path(@source_filename)
  unless valid_source_path
    validation_status = false
    validation_msg = "File to duplicate from doesn't exist."
  end

  if validation_status
    new_path = File.join(data_path, @new_filename)
    File.write(new_path, File.read(valid_source_path))
    session[:message] =
      "#{@new_filename} has been duplicated from #{@source_filename}"
    redirect "/"
  else
    session[:message] = validation_msg
    status 422
    erb :duplicate
  end
end

# Delete document
post "/:filename/delete" do
  redirect_if_signed_out
  @filename = validate_filename(params[:filename])
  path = valid_existing_file_path(@filename)
  if path
    File.delete(path)
    session[:message] = "#{@filename} deleted successfully."
  else
    session[:message] = "Can't delete non-existing document."
  end
  redirect "/"
end
