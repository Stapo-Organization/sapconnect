#!/usr/bin/env ruby
# Uploads a folder of PNGs as the App Store screenshots for one localization.
#
#   ruby tool/asc_screenshots.rb <appStoreVersionLocalization id> <dir> [displayType]
#
# Replaces whatever the set holds: screenshots are ordered by filename, so
# name them 01_…, 02_…. Default display type is APP_IPHONE_67, which Apple
# uses for every 6.7"/6.9" iPhone (1290×2796 or 1320×2868).
require_relative 'asc'
require 'digest'

loc_id  = ARGV[0] or abort 'localization id required'
dir     = ARGV[1] or abort 'directory required'
display = ARGV[2] || 'APP_IPHONE_67'

def must(code, data, what)
  return data if code.between?(200, 299)
  abort "#{what}: HTTP #{code}\n#{JSON.pretty_generate(data)[0, 800]}"
end

# 1. The set for this display type — reuse or create.
code, data = call(:get, "/v1/appStoreVersionLocalizations/#{loc_id}/appScreenshotSets?fields%5BappScreenshotSets%5D=screenshotDisplayType")
must(code, data, 'list sets')
set = data['data'].find { |s| s['attributes']['screenshotDisplayType'] == display }
if set.nil?
  code, data = call(:post, '/v1/appScreenshotSets', {
    data: { type: 'appScreenshotSets', attributes: { screenshotDisplayType: display },
            relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: loc_id } } } }
  })
  set = must(code, data, 'create set')['data']
end
set_id = set['id']
puts "set #{display}: #{set_id}"

# 2. Clear what is there — a replaced set, not an appended one.
code, data = call(:get, "/v1/appScreenshotSets/#{set_id}/appScreenshots?fields%5BappScreenshots%5D=fileName")
must(code, data, 'list screenshots')
data['data'].each do |shot|
  c, d = call(:delete, "/v1/appScreenshots/#{shot['id']}")
  puts "  removed #{shot['attributes']['fileName']} (#{c})"
end

# 3. Upload each file: reserve, PUT the bytes where Apple says, commit with md5.
ids = []
Dir.glob(File.join(dir, '*.png')).sort.each do |path|
  bytes = File.binread(path)
  name  = File.basename(path)
  code, data = call(:post, '/v1/appScreenshots', {
    data: { type: 'appScreenshots', attributes: { fileName: name, fileSize: bytes.bytesize },
            relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set_id } } } }
  })
  shot = must(code, data, "reserve #{name}")['data']
  shot['attributes']['uploadOperations'].each do |op|
    uri = URI(op['url'])
    req = Net::HTTP::Put.new(uri)
    op['requestHeaders'].each { |h| req[h['name']] = h['value'] }
    req.body = bytes[op['offset'], op['length']]
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    abort "upload part failed for #{name}: #{res.code}" unless res.code.to_i.between?(200, 299)
  end
  code, data = call(:patch, "/v1/appScreenshots/#{shot['id']}", {
    data: { type: 'appScreenshots', id: shot['id'],
            attributes: { uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(bytes) } }
  })
  must(code, data, "commit #{name}")
  ids << shot['id']
  puts "  uploaded #{name} (#{bytes.bytesize / 1024} KB)"
end

# 4. Order = filename order.
code, data = call(:patch, "/v1/appScreenshotSets/#{set_id}/relationships/appScreenshots", {
  data: ids.map { |id| { type: 'appScreenshots', id: id } }
})
must(code, data, 'order')
puts "done: #{ids.size} screenshots"
