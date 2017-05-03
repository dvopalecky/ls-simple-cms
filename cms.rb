# File based CMS

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

get '/' do
  @files = Dir['data/*'].select { |path| File.file?(path) }
  @files = @files.map! { |file| File.basename(file) }
  erb :list
end
