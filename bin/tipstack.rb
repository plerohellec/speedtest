#!/usr/bin/env ruby

require 'httparty'

def find_lat_long_from_ipstack(ip)
  page = HTTParty.get("http://api.ipstack.com/#{ip}?access_key=#{ENV['IPSTACK_KEY']}")
  puts page.code
  if page.code.to_s != '200'
    puts "ipstack failed with code #{page.code}"
    return
  end

  data = JSON.load(page.body)
  return data['latitude'], data['longitude']
end

puts find_lat_long_from_ipstack(ARGV[0])

