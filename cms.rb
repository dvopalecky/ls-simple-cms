# File based CMS

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

get '/' do
  @files = Dir['data/*'].select { |path| File.file?(path) }
  @files = @files.map! { |file| File.basename(file) }
  erb :list
end

get '/:filename' do
  path = "data/#{params['filename']}"
  if File.file?(path)
    headers["Content-Type"] = "text/plain;charset=utf-8"
    File.read(path)
  else
    session[:error] = "#{params['filename']} doesn't exist."
    redirect '/'
  end
end
