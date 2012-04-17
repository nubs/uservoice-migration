#!/usr/bin/ruby
require File.join(File.dirname(__FILE__), 'common')

puts "#{'='*20} Fetching old forums #{'='*20}"
old_forums = JSON.parse(OLDCONSUMER.request(:get, "#{OLDSITE}/api/v1/forums.json").body)["forums"]
puts JSON.pretty_generate(old_forums)

puts "#{'='*20} Fetching new forums #{'='*20}"
new_forums = JSON.parse(NEWCONSUMER.request(:get, "#{NEWSITE}/api/v1/forums.json").body)["forums"]
puts JSON.pretty_generate(new_forums)

old_forums.each {|old_forum|
  if new_forum = new_forums.find {|new_forum| new_forum['name'] == old_forum['name'] }
    puts "#{'='*20} Forum #{old_forum['name']} found on new site #{'='*20}"
  else
    puts "#{'='*20} Forum #{old_forum['name']} not found, creating on new site #{'='*20}"
    at = OAuth::AccessToken.new NEWCONSUMER
    new_forum = JSON.parse(at.post("#{NEWSITE}/api/v1/forums.json", {'forum[name]' => old_forum['name'], 'forum[private]' => old_forum['private']}).body)["forum"]
  end

  puts JSON.pretty_generate(new_forum)
}
