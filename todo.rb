require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do 
  enable :sessions
  set :session_secret, 'secret'
end

before do 
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
  erb "task manager", layout: :layout
end

get "/lists" do 
  @lists = session[:lists]
  # [
  #   {name: "first list", todos: []},
  #   {name: "second list", todos: []}
  # ]

  erb :lists
end

get "/lists/new" do 
  session[:lists] << {name: "new list", todos: []}
  redirect "/lists"
end