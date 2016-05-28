#!/usr/bin/env ruby

require 'net/http'
require 'open3'
require 'openssl'
require 'json'
require 'yaml'
require 'aws-sdk'
require 'securerandom'
require 'uri'

# setting
configfile = "#{ENV['HOME']}/.gyazo.config.yml"
config = {}
if File.exist?(configfile) then
  config = YAML.load_file(configfile)
end

browser_cmd = config['browser_cmd'] || 'xdg-open'
clipboard_cmd = config['clipboard_cmd'] || 'xclip'
clipboard_opt = config['clipboard_opt'] || '-sel clip'
aws_access_key_id = config['aws_access_key_id'] || abort('YOU MUST SET aws_access_key_id')
aws_secret_access_key = config['aws_secret_access_key'] || abort('YOU MUST SET aws_secret_access_key')
aws_s3_region = config['aws_s3_region'] || abort('YOU MUST SET aws_s3_region')
aws_s3_bucket_name = config['aws_s3_bucket_name'] || abort('YOU MUST SET aws_s3_bucket_name')
aws_s3_path = config['aws_s3_path'] || '/'
aws_s3_base_url = config['aws_s3_base_url'] || ''

# get id
idfile = ENV['HOME'] + "/.gyazo.id"

id = ''
if File.exist?(idfile) then
  id = File.read(idfile).chomp
end

# get active window name

active_window_id = `xprop -root | grep "_NET_ACTIVE_WINDOW(WINDOW)" | cut -d ' ' -f 5`.chomp
out, err, status = Open3.capture3 "xwininfo -id #{active_window_id} | grep \"xwininfo: Window id: \"|sed \"s/xwininfo: Window id: #{active_window_id}//\""
active_window_name = out.chomp
out, err, status = Open3.capture3 "xprop -id #{active_window_id} | grep \"_NET_WM_PID(CARDINAL)\" | sed s/_NET_WM_PID\\(CARDINAL\\)\\ =\\ //"

pid = out.chomp

application_name = `ps -p #{pid} -o comm=`.chomp
# capture png file
tmpfile = "/tmp/image_upload#{$$}.png"
imagefile = ARGV[0]

if imagefile && File.exist?(imagefile) then
  system "convert '#{imagefile}' '#{tmpfile}'"
else
  command = (File.exist?(configfile) && YAML.load_file(configfile)['command']) || 'import'
  system "#{command} '#{tmpfile}'"
end

if !File.exist?(tmpfile) then
  exit
end

imagedata = File.read(tmpfile)
File.delete(tmpfile)

xuri = ""
if application_name =~ /(chrom(ium|e)|firefox|iceweasel)/
  xuri = `xdotool windowfocus #{active_window_id}; xdotool key "ctrl+l"; xdotool key "ctrl+c"; xclip -o`
end

def gen_url(raw_url)
  purl = URI.parse(raw_url)
  purl.path.gsub! %r{/+}, '/'
  purl.to_s
end

# upload
key = SecureRandom.hex(4) + '.jpg'
s3 = Aws::S3::Client.new(
  access_key_id: aws_access_key_id,
  secret_access_key: aws_secret_access_key,
  region: aws_s3_region
)
s3.put_object(
  bucket: aws_s3_bucket_name,
  body: imagedata,
  key: key
)
url = gen_url([aws_s3_base_url, aws_s3_path, key].join('/'))
puts url
if system "which #{clipboard_cmd} >/dev/null 2>&1" then
  system "echo -n '#{url}' | #{clipboard_cmd} #{clipboard_opt}"
end
system "#{browser_cmd} '#{url}'"

