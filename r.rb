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
      access_token = self.class.get_local_access_token
      access_token = self.class.setup_access_token if !access_token || access_token == ''
      @session = GoogleDrive.login_with_oauth(access_token)
    end

    def self.access_token_filename
      File.join(File.dirname(__FILE__), '.access_token')
    end

    def self.get_local_access_token
      begin
        File.read(access_token_filename).chomp
      rescue Errno::ENOENT
        nil
      end
    end

    def self.save_local_access_token(access_token)
      File.open(access_token_filename, 'w') do |fh|
        fh.write access_token
      end
    end

    def self.setup_access_token
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
      begin
        open_google_doc
      rescue Google::APIClient::AuthorizationError
        Makermap::Spreadsheet.setup_access_token
        open_google_doc
      end
    end

    def open_google_doc
      @ws = google_session.spreadsheet_by_key(WORKSHEET_KEY).worksheets[0]
    end

    def refresh_google_doc
      ws.reload
    end

    def get_tweet_id_from_row(row)
      ws[row, 3][/(\d+)\s*$/]
    end

    def desc_tag_by_row(row)
      return ws[row, 5] if ws[row, 5] != '' ## Skip if desc tag already populated
      return 'rt' if ws[row, 2] =~ /RT /    ## Skip retweets (and save on twitter api quota)
      return nil
    end

    def desc_tag_by_tweet(row, t)
      return 'rt' if t.retweet? ## Skip retweets
      return t.geo? ? 'geo' : 'none'
    end

    def populate_geo_data(start = 1, finish = nil)
      finish ||= ws.num_rows

      (start..finish).each do |row|
        desc = desc_tag_by_row(row)
        if !desc
          tweet_id = get_tweet_id_from_row(row)
          begin
            t = twitter_client.get_tweet_by_id tweet_id
            desc = desc_tag_by_tweet(row, t)
            ws[row, 6] = t.geo if t.geo?
          rescue ::Twitter::Error::NotFound
            desc = 'deleted'
          rescue ::Twitter::Error::TooManyRequests
            puts "TooManyRequests"
            break
          end

          ws[row, 6] = t.geo if t.geo?
        end

        next if ws[row, 5] == desc ## Not sure if this saves anything
        ws[row, 5] = desc
      end
    end

  end
end


su = Makermap::SpreadsheetUpdater.new
# su.populate_geo_data(101, 300)
su.populate_geo_data
su.ws.save

## Different starting points
# su.populate_geo_data 1000
