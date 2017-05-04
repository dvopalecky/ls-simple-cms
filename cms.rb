# File based CMS

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

root = File.expand_path("..", __FILE__)

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  erb markdown.render(text)
end

get '/' do
  @files = Dir["#{root}/data/*"].select { |path| File.file?(path) }
  @files = @files.map! { |file| File.basename(file) }
  erb :list
end

get '/:filename' do
  path = "#{root}/data/#{params['filename']}"
  if File.file?(path)
    content = File.read(path)
    if File.extname(path) == '.md'
      render_markdown(content)
    else
      headers["Content-Type"] = "text/plain;charset=utf-8"
      content
    end
  else
    session[:error] = "#{params['filename']} doesn't exist."
    redirect '/'
  end
end
