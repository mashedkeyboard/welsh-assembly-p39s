#!/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata/fetcher'

class Results < Scraped::JSON
  field :memberships do
    json[:results][:bindings].map { |result| fragment(result => Membership).to_h }
  end
end

class Membership < Scraped::JSON
  field :statement do
    json.dig(:ps, :value).to_s.split('/').last
  end

  field :id do
    json.dig(:item, :value).to_s.split('/').last
  end

  field :name do
    json.dig(:itemLabel, :value)
  end

  field :constituency_id do
    json.dig(:district, :value).to_s.split('/').last
  end

  field :constituency do
    json.dig(:districtLabel, :value)
  end

  field :party_id do
    json.dig(:group, :value).to_s.split('/').last
  end

  field :party do
    json.dig(:groupLabel, :value)
  end

  field :start_date do
    json.dig(:start, :value).to_s[0..9]
  end

  field :end_date do
    json.dig(:end, :value).to_s[0..9]
  end

  field :term do
    json.dig(:termOrdinal, :value).to_i
  end
end

WIKIDATA_SPARQL_URL = 'https://query.wikidata.org/sparql?format=json&query=%s'

memberships_query = <<SPARQL
  SELECT ?ps ?item ?itemLabel ?group ?groupLabel ?district ?districtLabel ?start ?end ?term ?termLabel ?termOrdinal
  {
    ?item p:P39 ?ps .
    ?ps ps:P39/wdt:P279* wd:Q3406079 .
    ?ps pq:P2937 ?term .
    ?term p:P31/pq:P1545 ?termOrdinal .
    OPTIONAL { ?ps pq:P580 ?start }
    OPTIONAL { ?ps pq:P582 ?end }
    OPTIONAL { ?ps pq:P4100 ?group }
    OPTIONAL { ?ps pq:P768 ?district }
    SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . }
  }
SPARQL

url = WIKIDATA_SPARQL_URL % CGI.escape(memberships_query)
data = Results.new(response: Scraped::Request.new(url: url,
                                                  headers: { "User-Agent" => "welsh-assembly-p39s morph scraper - curtis [at] loudspeek [dot] cc" }).response).memberships
puts data.map(&:compact).map(&:sort).map(&:to_h) if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[statement], data)
