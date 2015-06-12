#!/usr/bin/env ruby

require 'bundler/setup'
require 'yaml'
require 'twitter'

module Makermap

  class Twitter
    CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), 'creds.yml'))[:twitter].freeze

    def client
      @client ||= Twitter::REST::Client.new CONFIG
    end

    def get_geo_info(tweet)
      t = client.status tweet.to_i
      t.geo
    end
  end

  class Spreadsheet
    CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), 'creds.yml'))[:google].freeze

  end
end


