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

# Show index
get '/' do
  pattern = File.join(data_path, '*')
  @files = Dir[pattern].select { |path| File.file?(path) }
  @files = @files.map! { |file| File.basename(file) }
  erb :index
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
  File.write(path, params[:content])
  session[:message] = "#{params[:filename]} has been updated."
  redirect '/'
end

# Edit document
get '/:filename/edit' do
  @filename = params[:filename]
  path = File.join(data_path, @filename)
  @content = if File.file?(path)
               File.read(path)
             else
               ''
             end
  erb :edit
end
