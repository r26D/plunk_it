#!/usr/bin/ruby
require 'yaml'
require 'multi_json'
require 'nokogiri'
require 'mechanize'
require 'logger'
#TODO - allow you to configure what gets excluded from uploading
#TODO - add support for pulling down a plunk to keep the local file in sync
#TODO - build as a gem
#TODO - add support for working on other directories

VALID_EXTENSTIONS = [".js", ".html"]
if !File.exists?(File.expand_path("~/.plunk_it"))
  puts "You must created a ~/.plunk_it with your GitHubToken"
  exit
else
  GITHUB_TOKEN = File.open(File.expand_path("~/.plunk_it"), "rb").read
end


#open the manifest - which should have 
# the url
# the description
# the tags for the item
# get the authentication from a file or env?
payload = YAML.load_file('manifest.yml')
payload["files"] = {} if !payload["files"]
payload["description"] +=  " #{Time.now}"

#get a list of the files in the directory - exclude the manifest
Dir["**/*"].select{|x| !File.directory?(x) && 
                       VALID_EXTENSTIONS.include?(File.extname(x))}.each do |file_name|
  file = File.open(file_name, "rb")
  payload["files"][file_name] = { :filename => file_name,
                        :content => file.read}

end
@agent = Mechanize.new do|a|
#a.log = Logger.new('log.txt')
#   a.log.level = Logger::DEBUG
#   a.user_agent_alias = "Windows IE 6"
end
plnkr_session_page = @agent.get("http://api.plnkr.co/session")
plnkr_session =  MultiJson.load(plnkr_session_page.body)
login_post = @agent.post(plnkr_session["user_url"], MultiJson.dump({"service" => "github",
                                        "token" => GITHUB_TOKEN}),
                    {"Content-type" => "application/json;charset=UTF-8",
                     "Origin" => "http://www.plnkr.co",
                     "Referer" => "http://www.plnkr.co/"})

plunk_post = @agent.get("http://api.plnkr.co/plunks?sessid=#{plnkr_session["id"]}")
plunk_post = @agent.post("http://api.plnkr.co/plunks?sessid=#{plnkr_session["id"]}", MultiJson.dump(payload),
                    {"Content-type" => "application/json;charset=UTF-8",
                      "Host" => "api.plnkr.co",
                      "Origin" => "http://plnkr.co",
                      "Referer" => "http://plnkr.co/edit/"})

                         
plunk_data =  MultiJson.load(plunk_post.body)
puts "It has been plunked to http://plnkr.co/edit/#{plunk_data["id"]}"
