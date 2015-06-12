#!/usr/bin/env ruby

require 'bundler/setup'
require 'twitter'



client.filter(locations: "-122.75,36.8,-121.75,37.8") do |tweet|
  puts tweet.text
end


