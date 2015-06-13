#!/usr/bin/env ruby

require 'bundler/setup'
require 'yaml'

require 'twitter'

require "google/api_client"
require "google_drive"

module Makermap

  class Twitter
    CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), 'creds.yml'))[:twitter].freeze

    def client
      @client ||= ::Twitter::REST::Client.new CONFIG
    end

    def get_tweet_by_id(tweet_id)
      tweet = client.status tweet_id.to_i
    end

    def get_geo_info(tweet_id)
      get_tweet_by_id(tweet_id).geo
    end
  end

  class Spreadsheet
    CONFIG = YAML.load_file(File.join(File.dirname(__FILE__), 'creds.yml'))[:google].freeze

    attr_reader :session

    def initialize
      access_token = get_local_access_token
      access_token = setup_access_token if !access_token || access_token == ''
      @session = GoogleDrive.login_with_oauth(access_token)
    end

    def access_token_filename
      File.join(File.dirname(__FILE__), '.access_token')
    end

    def get_local_access_token
      begin
        File.read(access_token_filename).chomp
      rescue Errno::ENOENT
        nil
      end
    end

    def save_local_access_token(access_token)
      File.open(access_token_filename, 'w') do |fh|
        fh.write access_token
      end
    end

    def setup_access_token
      client = ::Google::APIClient.new
      auth = client.authorization
      auth.client_id = CONFIG[:client_id]
      auth.client_secret = CONFIG[:client_secret]
      auth.scope = [
        "https://www.googleapis.com/auth/drive",
        "https://spreadsheets.google.com/feeds/"
      ]
      auth.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
      print("1. Open this page:\n%s\n\n" % auth.authorization_uri)
      print("2. Enter the authorization code shown in the page: ")
      auth.code = $stdin.gets.chomp
      auth.fetch_access_token!
      access_token = auth.access_token

      save_local_access_token access_token
    end
  end

  class SpreadsheetUpdater
    WORKSHEET_KEY = YAML.load_file(File.join(File.dirname(__FILE__), 'creds.yml'))[:google_spreadsheet][:document_key]

    attr_accessor :google_session, :twitter_client, :ws

    def initialize
      @google_session = Makermap::Spreadsheet.new.session
      @twitter_client = Makermap::Twitter.new
      open_google_doc
    end

    def open_google_doc
      @ws = google_session.spreadsheet_by_key(WORKSHEET_KEY).worksheets[0]
    end

    def refresh_google_doc
      ws.reload
    end

    def populate_geo_data(start = 1, finish = nil)
      finish ||= ws.num_rows

      (start..finish).each do |row|
        ## Skip if geo already populated
        if ws[row, 5] != ''
          print "."
          next
        end

        tweet_id = ws[row, 3][/(\d+)\s*$/]
        begin
          t = twitter_client.get_tweet_by_id tweet_id

          ## Skip if retweet -- not likely to have geo data?
          if t.retweet?
            ws[row, 5] = 'rt'
            next
          end

          geo_info = t.geo? ? t.geo : 'no geo'
          ws[row, 5] = geo_info.to_s
        rescue ::Twitter::Error::NotFound
          ws[row, 5] = 'nil'
        rescue ::Twitter::Error::TooManyRequests
          puts "TooManyRequests"
          break
        end

      end
    end

  end
end


su = Makermap::SpreadsheetUpdater.new
su.populate_geo_data(101, 300)
su.ws.save

## Different starting points
# su.populate_geo_data 1000
