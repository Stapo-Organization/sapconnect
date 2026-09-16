#!/usr/bin/env ruby
# Google Play Developer API from the terminal, the way tool/asc.rb does App
# Store Connect. Auth: the service account key at ~/.zooboxi/play-service-account.json
# (invited as Admin on the app in Play Console → Users and permissions).
#
#   ruby tool/play.rb token
#   ruby tool/play.rb get  <path>              # GET  /androidpublisher/v3/<path>
#   ruby tool/play.rb post <path> [json-file]  # POST (JSON body)
#   ruby tool/play.rb put  <path> [json-file]
#   ruby tool/play.rb patch <path> [json-file]
#   ruby tool/play.rb upload <path> <file> <mime>   # media upload (bundle, image)
#   ruby tool/play.rb delete <path>
require 'json'
require 'openssl'
require 'net/http'
require 'uri'
require 'base64'

KEY = JSON.parse(File.read(File.join(Dir.home, '.zooboxi', 'play-service-account.json')))
BASE = 'https://androidpublisher.googleapis.com'

def b64(s)
  Base64.urlsafe_encode64(s, padding: false)
end

def token
  now = Time.now.to_i
  header = b64({ alg: 'RS256', typ: 'JWT' }.to_json)
  claims = b64({ iss: KEY['client_email'], scope: 'https://www.googleapis.com/auth/androidpublisher',
                 aud: KEY['token_uri'], iat: now, exp: now + 3600 }.to_json)
  key = OpenSSL::PKey::RSA.new(KEY['private_key'])
  sig = b64(key.sign(OpenSSL::Digest.new('SHA256'), "#{header}.#{claims}"))
  res = Net::HTTP.post_form(URI(KEY['token_uri']),
                            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                            'assertion' => "#{header}.#{claims}.#{sig}")
  body = JSON.parse(res.body)
  abort "token: #{res.code} #{res.body}" unless body['access_token']
  body['access_token']
end

def call(method, path, body: nil, ctype: 'application/json', upload: false)
  prefix = upload ? '/upload' : ''
  uri = URI("#{BASE}#{prefix}/androidpublisher/v3/#{path}")
  req = { 'get' => Net::HTTP::Get, 'post' => Net::HTTP::Post, 'put' => Net::HTTP::Put,
          'patch' => Net::HTTP::Patch, 'delete' => Net::HTTP::Delete }.fetch(method).new(uri)
  req['Authorization'] = "Bearer #{token}"
  if body
    req['Content-Type'] = ctype
    req.body = body
  end
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 600
  res = http.request(req)
  puts "HTTP #{res.code}"
  begin
    puts JSON.pretty_generate(JSON.parse(res.body))
  rescue StandardError
    puts res.body
  end
  exit(res.code.to_i < 300 ? 0 : 1)
end

cmd, path, arg, mime = ARGV
case cmd
when 'token' then puts token
when 'get', 'delete' then call(cmd, path)
when 'post', 'put', 'patch' then call(cmd, path, body: (arg && arg != "/dev/null") ? File.read(arg) : "{}")
when 'upload' then call('post', path, body: File.binread(arg), ctype: mime, upload: true)
else abort "usage: play.rb token|get|post|put|patch|upload|delete <path> [file] [mime]"
end
