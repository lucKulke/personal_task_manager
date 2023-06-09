require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do 
  enable :sessions
  set :session_secret, "d14e451a1712ec868e809070db22036539e12dfa9eb4d84519d2e57fb195d9dc"
  set :erb, :escape_html => true
end

before do 
  session[:lists] ||= []
end

helpers do 
  def list_complete?(list)
    !list[:todos].size.zero? && list[:todos].all?{ |todo| todo[:completed] }
  end
  
  def list_class(list) 
    return "complete" if list_complete?(list)
    ""
  end

  def count_completed_todos(list)
    list[:todos].count{ |todo| todo[:completed] == true }
  end

  def sorted_lists(lists)
    lists = lists.sort_by{ |a, b| list_complete?(a) ? 1 : 0 }
    lists.each do |list|
      yield(list)
    end
  end

  def sorted_todos(todos)
    todos = todos.sort_by{ |a, b| a[:completed] ? 1 : 0 }
    todos.each do |todo|
      yield(todo)
    end
  end

end


def add_new_list(lists, name)
  id = new_id(lists)
  lists << {name: name, todos: [], id: id}
end

def new_id(array)
  max = array.map{ |obj| obj[:id] }.max || -1
  max + 1 
end

def error_for_list_name(list_name)
  return "List name musst be uniq" if session[:lists].any?{ |list| list[:name] == list_name }
  return "The name of the list musst be between 1 and 100 characters" unless (1..100).cover?(list_name.size)
  nil
end

def error_for_todo_name(todo_name, todos)
  return "Todo name musst be uniq" if todos.any?{ |todo| todo[:name] == todo_name }
  return "The name of the Todo musst be between 1 and 100 characters" unless (1..100).cover?(todo_name.size)
  nil
end

def load_list(id)
  return session[:lists].find{ |list| list[:id] == id } if all_ids.include?(id)
  session[:error] = "The specified list was not found"
  redirect "/lists"
end 

def all_ids
  session[:lists].map{ |list| list[:id] }
end


get "/" do
  redirect "/lists" if !session[:lists].size.zero?
  erb :home
end

# Views all available lists
get "/lists" do
  @lists = session[:lists]
  redirect "/" if @lists.size.zero?
  erb :lists
end

# Renders new list form
get "/lists/new" do 
  erb :new_list
end

# view list
get "/lists/:id" do 
  id = params[:id].to_i
  @list = load_list(id)
  erb :list
end

# edit list name view 
get "/lists/:id/edit" do 
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list
end


# Creates a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    add_new_list(session[:lists], list_name)
    session[:success] = "The list '#{params[:list_name]}' has been created."
    redirect "/lists"
  end
end

# edit list name
post "/lists/:id" do
  id = params[:id].to_i
  @list = load_list(id)
  
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = "The list '#{params[:list_name]}' has been updated."
    redirect "/lists/#{id}"
  end
end

# destroy list

post '/lists/:id/destroy' do
  list_id = params[:id].to_i
  session[:lists].delete_if{ |list| list[:id] == list_id }
  session[:success] = "The list has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect "/lists"
  end
end

# Add new todo to a list
post '/lists/:list_id/todos' do
  list_id = params[:list_id].to_i
  todo_name = params[:todo].strip
  @list = load_list(list_id)


  error = error_for_todo_name(todo_name, @list[:todos])
  if error
    session[:error] = error
    redirect "/lists/#{list_id}"
  else
    id = new_id(@list[:todos])
    @list[:todos] << {id: id, name: todo_name, completed: false}
    session[:success] = "Todo was added successfully."
    redirect "/lists/#{list_id}"
  end
end

# Deletes a todo in a list
post '/lists/:list_id/todos/:todo_id/destroy' do 
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  todos = load_list(list_id)[:todos]
  todos.delete_if{ |todo| todo[:id] == todo_id }
  session[:success] = "The todo has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    redirect "/lists/#{list_id}"
  end
end

# set todo to completed or uncompleted
post '/lists/:list_id/todos/:todo_id/complete' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  list = load_list(list_id)
  todo = list[:todos].select{ |todo| todo[:id] == todo_id }.first
  is_completed = params[:completed] == "true"
  todo[:completed] = is_completed
  session[:success] = is_completed ? "The Todo #{todo[:name]} is completed" : "The Todo #{todo[:name]} is uncompleted"
  redirect "/lists/#{list_id}"
end

# completes all todos inside a list
post '/lists/:list_id/complete_all' do
  list_id = params[:list_id].to_i
  load_list(list_id)[:todos].each do |todo|
      todo[:completed] = true
  end
  session[:success] = "All todos completed!"
  redirect "lists/#{list_id}"
end


