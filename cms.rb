# File based CMS

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

get '/' do
  @files = Dir['data/*'].select { |path| File.file?(path) }
  @files = @files.map! { |file| File.basename(file) }
  erb :list
end

get '/:filename' do
  path = "data/#{params['filename']}"
  if File.exist?(path)
    headers["Content-Type"] = "text/plain; charset=utf-8"
    File.read(path)
  else
    'File not found'
  end
end
