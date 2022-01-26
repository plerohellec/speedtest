#!/usr/bin/env ruby

require 'amazing_print'
require 'resolv'
require 'yaml'
require 'curl'
require 'json'
require 'logger'

require_relative '../lib/speedtest'

def logger
  Logger.new(STDOUT)
end

def ipstack_geoip(ip, ipstack_key)
  page = Curl.get("http://api.ipstack.com/#{ip}?access_key=#{ipstack_key}")
  if page.response_code != 200
    puts "ipstack failed with code #{page.response_code}"
    return
  end

  body = JSON.load(page.body_str)
  if body['success'] == false
    puts "ipstask error: #{body}"
    return
  end

  { 'latitude' => body['latitude'], 'longitude' => body['longitude'] }
end

def validate_server(domain)
  url = domain
  url = "http://#{domain}" unless domain =~ /^http/

  server = Speedtest::Servers::Server.new(url)
  mover = Speedtest::Transfers::Mover.new(server, logger)
  mover.validate_server_transfer
end

yml_server_list = ENV.fetch('SERVERS_YML', 'data/input_global_servers.yml')
ipstack_key = ENV.fetch('IPSTACK_KEY')

regions = YAML.load(File.read(yml_server_list))
regions.each do |region, servers|
  servers.each do |server|
    domain = server['url'].gsub(/\:\d+$/, '')
    if validate_server(domain)
      puts "OK: #{domain}"
    else
      puts "KO: #{domain}"
      servers.delete_if { |todel| todel['url'] == server['url'] }
    end
  end
end

regions.each do |region, servers|
  servers.each do |server|
    domain = server['url'].gsub(/\:\d+$/, '')
    server['ip'] = Resolv.getaddress(domain)
    coords = ipstack_geoip(server['ip'], ipstack_key)
    server.merge!(coords)
  end
end

out_filename = if yml_server_list =~ /\.input/
                 yml_server_list.gsub('.input', '')
               else
                 yml_server_list.gsub('.yml', '.output.yml')
               end
File.write(out_filename, YAML.dump(regions))


