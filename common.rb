require File.join(File.dirname(__FILE__), 'config')
require 'ezcrypto'
require 'base64'
require 'oauth'
require 'json'

OLDCONSUMER = OAuth::Consumer.new(OLDKEY, OLDSECRET)
NEWCONSUMER = OAuth::Consumer.new(NEWKEY, NEWSECRET)

def symbolize_hash(hash)
  Hash[hash.map {|k, v| [k.to_sym, v] }]
end

def fetch_all(auth, url)
  response = JSON.parse(auth.request(:get, url).body)
  key = response.keys.find {|k| k != 'response_data' }
  pages = (response['response_data']['total_records'].to_f / response['response_data']['per_page'].to_f).ceil
  result = []
  pages.times {|i|
    result += JSON.parse(auth.request(:get, "#{url}?page=#{i+1}").body)[key]
  }

  result
end

def request_token(consumer, site)
  hash = JSON.parse(consumer.request(:get, "#{site}/api/v1/oauth/request_token.json").body)
  OAuth::RequestToken.from_hash(consumer, symbolize_hash(hash['token'])).token
end

def sso_token(subdomain, ssokey, options={})
  options.merge!({:expires => (Time.now.utc + 5 * 60).to_s})

  key = EzCrypto::Key.with_password(subdomain, ssokey)
  Base64.encode64(key.encrypt(options.to_json)).gsub("\n",'')
end

def access_token(consumer, subdomain, site, ssokey, options={})
  rt = request_token(consumer, site)
  st = sso_token(subdomain, ssokey, options)
  hash = JSON.parse(consumer.request(:post, "#{site}/api/v1/oauth/authorize.json", nil, {}, {:sso => st, :request_token => rt}).body)
  return OAuth::AccessToken.new(consumer) if hash['token'].nil?
  OAuth::AccessToken.from_hash(consumer, symbolize_hash(hash['token']))
end
