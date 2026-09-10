#!/usr/bin/env ruby
# A minimal App Store Connect API client.
#
# Ruby rather than Python because macOS ships it with OpenSSL bound in, and the
# one hard part here is ES256: JWT wants the raw r‖s pair, while OpenSSL signs
# into DER. Getting that conversion wrong fails as a flat 401 with no hint.
require 'openssl'
require 'base64'
require 'json'
require 'net/http'
require 'uri'

KEY_ID    = ENV.fetch('ASC_KEY_ID')
ISSUER_ID = ENV.fetch('ASC_ISSUER_ID')
KEY_PATH  = ENV.fetch('ASC_KEY_PATH')

def b64(data)
  Base64.urlsafe_encode64(data).delete('=')
end

def token
  header  = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' }
  payload = { iss: ISSUER_ID, iat: Time.now.to_i, exp: Time.now.to_i + 900,
              aud: 'appstoreconnect-v1' }
  signing_input = "#{b64(header.to_json)}.#{b64(payload.to_json)}"

  key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  der = key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(signing_input))
  # DER → raw: two 32-byte big-endian integers, left-padded.
  r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\x00") }
  "#{signing_input}.#{b64(r + s)}"
end

def call(method, path, body = nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  req = case method
        when :get    then Net::HTTP::Get.new(uri)
        when :post   then Net::HTTP::Post.new(uri)
        when :patch  then Net::HTTP::Patch.new(uri)
        when :delete then Net::HTTP::Delete.new(uri)
        end
  req['Authorization'] = "Bearer #{token}"
  req['Content-Type']  = 'application/json'
  req.body = body.to_json if body

  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
  parsed = res.body.to_s.empty? ? {} : JSON.parse(res.body)
  [res.code.to_i, parsed]
end

if __FILE__ == $PROGRAM_NAME
  method = (ARGV[0] || 'get').downcase.to_sym
  path   = ARGV[1]
  body   = ARGV[2] ? JSON.parse(ARGV[2]) : nil
  code, data = call(method, path, body)
  puts "HTTP #{code}"
  puts JSON.pretty_generate(data)
end
