#!/usr/bin/ruby
require File.join(File.dirname(__FILE__), 'common')

puts "#{'='*20} Fetching old forums #{'='*20}"
old_forums = JSON.parse(OLDCONSUMER.request(:get, "#{OLDSITE}/api/v1/forums.json").body)["forums"]
puts "  - Found #{old_forums.length} forums"

puts "#{'='*20} Fetching new forums #{'='*20}"
new_forums = JSON.parse(NEWCONSUMER.request(:get, "#{NEWSITE}/api/v1/forums.json").body)["forums"]
puts "  - Found #{old_forums.length} forums"

puts "#{'='*20} Fetching old users #{'='*20}"
old_users = fetch_all(OLDCONSUMER, "#{OLDSITE}/api/v1/users.json")
puts "  - Found #{old_users.length} users"

email_map = Hash[File.open('usermap.csv') {|f| f.readlines.map {|l| l.strip.split(',') } }]
puts "#{'='*20} Updating user emails #{'='*20}"
old_users.map! {|u| u['email'] = email_map[u['email']]; u }

old_forums.each {|old_forum|
  if new_forum = new_forums.find {|new_forum| new_forum['name'] == old_forum['name'] }
    puts "#{'='*20} Fetching suggestions on old forum #{old_forum['name']} #{'='*20}"
    old_suggestions = fetch_all(OLDCONSUMER, "#{OLDSITE}/api/v1/forums/#{old_forum['id']}/suggestions.json")
    puts "  - Found #{old_suggestions.length} suggestions"

    puts "#{'='*20} Fetching suggestions on new forum #{new_forum['name']} #{'='*20}"
    new_suggestions = fetch_all(NEWCONSUMER, "#{NEWSITE}/api/v1/forums/#{new_forum['id']}/suggestions.json")
    puts "  - Found #{new_suggestions.length} suggestions"

    old_suggestions.each {|old_suggestion|
      unless new_suggestion = new_suggestions.find {|new_suggestion| new_suggestion['title'] == old_suggestion['title'] }
        puts "#{'='*20} Suggestion '#{old_suggestion['title']}' not found, creating on new site #{'='*20}"

        old_user = old_suggestion['creator'].nil? ? {} : old_users.find {|old_user| old_user['id'] == old_suggestion['creator']['id'] }
        at = access_token(NEWCONSUMER, NEWSUBDOMAIN, NEWSITE, NEWSSOKEY, {:email => old_user['email'], :display_name => old_user['name'], :allow_forums => new_forums.map {|nf| nf['id'] }})
        object = {'suggestion[text]' => old_suggestion['text'].nil? ? "#{old_suggestion['title']} - null text" : old_suggestion['text'], 'suggestion[title]' => old_suggestion['title']}
        raw = at.request(:post, "#{NEWSITE}/api/v1/forums/#{new_forum['id']}/suggestions.json", object)
        new_suggestion = JSON.parse(raw.body)['suggestion']
        if new_suggestion.nil?
          p object
          p raw
          next
        end
      end

      # Having trouble getting this to work.
      #if old_suggestion.has_key?('response') && (!new_suggestion.has_key?('response') || new_suggestion['response'].nil? || new_suggestion['response'].empty? || new_suggestion['response']['text'].empty?)
        #puts "#{'='*20} Responding to suggestion #{'='*20}"
        #old_user = old_users.find {|old_user| old_user['email'] == OLDEMAIL}
        #at = access_token(NEWCONSUMER, NEWSUBDOMAIN, NEWSITE, NEWSSOKEY, {:email => old_user['email'], :display_name => old_user['name'], :allow_forums => new_forums.map {|nf| nf['id'] }})
        #new_response = JSON.parse(at.request(:put, "#{NEWSITE}/api/v1/forums/#{new_forum['id']}/suggestions/#{new_suggestion['id']}/respond.json", {'response[text]' => old_suggestion['response']['text'], 'response[status_id]' => old_suggestion['status']['id']}).body)
        #puts JSON.pretty_generate(new_response)
      #end
      
      puts "#{'='*20} Fetching comments for old suggestion #{'='*20}"
      old_comments = fetch_all(OLDCONSUMER, "#{OLDSITE}/api/v1/forums/#{old_forum['id']}/suggestions/#{old_suggestion['id']}/comments.json")
      puts "  - Found #{old_comments.length} comments"

      puts "#{'='*20} Fetching comments for new suggestion #{'='*20}"
      new_comments = fetch_all(NEWCONSUMER, "#{NEWSITE}/api/v1/forums/#{new_forum['id']}/suggestions/#{new_suggestion['id']}/comments.json")
      puts "  - Found #{new_comments.length} comments"

      old_comments.each {|old_comment|
        unless new_comment = new_comments.find {|new_comment| new_comment['text'][0..20] == old_comment['text'][0..20] }
          puts "#{'='*20} Comment not found, creating on new site #{'='*20}"

          old_user = old_comment['creator'].nil? ? {} : old_users.find {|old_user| old_user['id'] == old_comment['creator']['id'] }
          at = access_token(NEWCONSUMER, NEWSUBDOMAIN, NEWSITE, NEWSSOKEY, {:email => old_user['email'], :display_name => old_user['name'], :allow_forums => new_forums.map {|nf| nf['id'] }})
          new_comment = JSON.parse(at.request(:post, "#{NEWSITE}/api/v1/forums/#{new_forum['id']}/suggestions/#{new_suggestion['id']}/comments.json", {'comment[text]' => old_comment['text']}).body)['comment']
        end
      }

      puts "#{'='*20} Fetching supporters for old suggestion #{'='*20}"
      old_supporters = fetch_all(OLDCONSUMER, "#{OLDSITE}/api/v1/forums/#{old_forum['id']}/suggestions/#{old_suggestion['id']}/supporters.json")
      puts "  - Found #{old_supporters.length} supporters"

      puts "#{'='*20} Fetching supporters for new suggestion #{'='*20}"
      new_supporters = fetch_all(NEWCONSUMER, "#{NEWSITE}/api/v1/forums/#{new_forum['id']}/suggestions/#{new_suggestion['id']}/supporters.json")
      puts "  - Found #{new_supporters.length} supporters"

      tmpto = 0
      old_supporters.each {|old_supporter|
        unless new_supporter = new_supporters.find {|new_supporter| new_supporter['text'] == old_supporter['text'] }
          puts "#{'='*20} Supporter not found, creating on new site #{'='*20}"

          old_user = old_supporter['user']
          at = access_token(NEWCONSUMER, NEWSUBDOMAIN, NEWSITE, NEWSSOKEY, {:email => old_user['email'], :display_name => old_user['name'], :allow_forums => new_forums.map {|nf| nf['id'] }})
          tmpto += old_supporter['votes_for'].to_i
          new_supporter = JSON.parse(at.request(:post, "#{NEWSITE}/api/v1/forums/#{new_forum['id']}/suggestions/#{new_suggestion['id']}/votes.json", {'to' => old_supporter['votes_for'].to_i}).body)['supporter']
        end
      }
    }
  end
}
