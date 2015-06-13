#!/usr/bin/env ruby

require 'makermap'

su = Makermap::SpreadsheetUpdater.new
su.populate_geo_data
su.ws.save

## Should have geo data
# t = su.twitter_client.get_tweet_by_id 609535701110157313

