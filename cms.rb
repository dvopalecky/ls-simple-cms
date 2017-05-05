# File based CMS

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  erb markdown.render(text)
end

# returns validation boolean status and message
def validate_filename(filename)
  if filename.empty?
    [false, 'A name is required']
  elsif /[^\w\.]/ =~ filename
    [false, 'Name must contain only alphanumeric chars or . or _']
  elsif !['.txt', '.md'].include?(File.extname(filename))
    [false, 'Document must have .md or .txt extensions']
  else
    [true, '']
  end
end

# Show index
get '/' do
  pattern = File.join(data_path, '*')
  @files = Dir[pattern].select { |path| File.file?(path) }
  @files = @files.map! { |file| File.basename(file) }
  erb :index
end

# Create new document
post '/' do
  name = params[:name].strip
  validation_status, validation_msg = validate_filename(name)
  if validation_status
    path = File.join(data_path, name)
    File.write(path, '')
    session[:message] = "#{name} has been created"
    redirect '/'
  else
    session[:message] = validation_msg
    status 422
    erb :new
  end
end

# Show form for new document
get '/new' do
  erb :new
end

# Show document
get '/:filename' do
  path = File.join(data_path, params[:filename])
  if File.file?(path)
    content = File.read(path)
    if File.extname(path) == '.md'
      render_markdown(content)
    else
      headers['Content-Type'] = 'text/plain;charset=utf-8'
      content
    end
  else
    session[:message] = "#{params[:filename]} doesn't exist."
    redirect '/'
  end
end

# Submit edits of document
post '/:filename' do
  path = File.join(data_path, params[:filename])
  if File.file?(path)
    File.write(path, params[:content])
    session[:message] = "#{params[:filename]} has been updated."
  else
    session[:message] = "Can't edit non-existing document #{params[:filename]}"
  end

  redirect '/'
end

# Show form for editing document
get '/:filename/edit' do
  @filename = params[:filename]
  path = File.join(data_path, @filename)
  if File.file?(path)
    @content = File.read(path)
    erb :edit
  else
    session[:message] = "Can't edit non-existing document #{@filename}"
    redirect '/'
  end
end
