# frozen_string_literal: true

require 'faraday'
require 'fileutils'
require 'marc'
require 'nokogiri'
require 'thor'
require 'uri'

require 'pry-byebug'

class EtdProcessor < Thor
  DEFAULT_DSPACE_URL = 'https://dataspace.princeton.edu'
  DEFAULT_REPORT_FORMAT = 'text/plain'
  HTML_TABLE_CSS_SELECTOR = '#content > div:nth-child(2) > div > div.col-md-9 > div.discovery-result-results > div > table'

  attr_reader :file_path, :output_file_path, :dspace_uri, :original_marc_file_path

  desc 'insert_arks', 'insert ARKs into a MARC file'
  option :file_path, aliases: :f, required: true
  option :output_file_path, aliases: :o, required: true
  option :dspace_url, aliases: '-d', default: DEFAULT_DSPACE_URL
  option :original_marc_file_path, aliases: '-m'
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def insert_arks(input_file_path = nil, output_file_path = nil, dspace_url = DEFAULT_DSPACE_URL, original_marc_file_path = nil)
    @file_path = input_file_path || options[:file_path]
    @output_file_path = output_file_path || options[:output_file_path]
    @dspace_url = dspace_url || options[:dspace_url]
    @dspace_uri = URI.parse(@dspace_url)
    @original_marc_file_path = original_marc_file_path || options[:original_marc_file_path]

    marc_reader.each_with_index do |record, _index|
      current245 = record['245']
      raise(ArgumentError, 'Failed to find the title field 245 for record {index}') unless current245

      title = current245['a']
      raise(ArgumentError, 'Failed to find the title subfield 245$a for record {index}') unless title

      arks = query_for_dspace_item(title:)

      record_hash = record.to_hash

      if arks.empty?
        say("No ARKs found for record \"#{title}\"", :yellow)
        if original_marc_writer
          new_record = MARC::Record.new_from_hash(record_hash)
          original_marc_writer.write(new_record)
        end
      else
        ark = arks.first
        say("Resolved ARK #{ark} for record \"#{title}\"", :green)

        new_field = {
          '856' => {
            'ind1' => ' ',
            'ind2' => ' ',
            'subfields' => [
              {
                'u' => ark
              }
            ]
          }
        }

        record_hash['fields'] << new_field

        new_record = MARC::Record.new_from_hash(record_hash)
        marc_writer.write(new_record)
      end
    end

    close_original_marc_writer unless original_marc_writer.nil?
    close_marc_writer
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  desc 'inspect_marc', 'provide a summary report for MARC records within a file'
  option :file_path, aliases: :f, required: true
  option :format, aliases: :F, default: DEFAULT_REPORT_FORMAT
  def inspect_marc(input_file_path = nil, input_format = nil)
    @file_path = input_file_path || options[:file_path]
    # This is for any cases where this must be extended
    @format = input_format || options[:format]

    say("\n# MARC Record Summary Report", :green)
    say("## Record Summary", :green)
    say("| leader | title | URL |", :green)
    say("| ------ | ----- | --- |", :green)

    records.each do |record|
      title = record["245"]["a"]
      url_fields = record.fields.select { |f| f.tag == "856" }
      url_field = url_fields.last
      url = url_field["u"]

      say("| #{record.leader} | #{title} | #{url} |", :green)
    end

    say("\n ## File Summary", :green)
    say("| file path | total number of MARC records |", :green)
    say("| --------- | ---------------------------- |", :green)

    say("| #{file_path} | #{records.length} |", :green)
  end

  # rubocop:disable Metrics/BlockLength
  no_commands do
    def marc_reader
      @marc_reader = MARC::Reader.new(file_path)
    end

    def records
      @records ||= marc_reader.to_a
    end

    def marc_writer
      @marc_writer ||= MARC::Writer.new(output_file_path)
    end

    def close_marc_writer
      marc_writer.close
      @marc_writer = nil
    end

    def original_marc_writer
      return unless original_marc_file_path

      @original_marc_writer ||= MARC::Writer.new(original_marc_file_path)
    end

    def close_original_marc_writer
      original_marc_writer.close
      @original_marc_writer = nil
    end

    def dspace_search_uri
      @dspace_search_uri ||= begin
        built = dspace_uri.dup
        built.path = '/simple-search'
        built
      end
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def query_for_dspace_item(title:)
      query_uri = dspace_search_uri.dup

      search_title = title.gsub('Philosophizing against Hegemons: Humanities Studies and the Politics of Reading in South Korea, Volume I.', 'Philosophizing against Hegemons: Humanities Studies and the Politics of Reading in South Korea')
      search_title = search_title.gsub("\\uD835\\uDCA9 = ", 'N=')
      search_title = search_title.gsub(/ =$/, '')
      search_title = search_title.gsub(/[[:punct:]]$/, '')
      query_title = search_title

      params = {
        query: "\"#{query_title}\""
      }

      response = Faraday.get(query_uri.to_s, params)
      unless response.success?
        raise(ArgumentError,
              "Failed to receive a response from the DSpace URI: #{query_uri}")
      end

      response_document = Nokogiri::HTML.parse(response.body)
      # #content > div:nth-child(2) > div > div.col-md-9 > div.discovery-result-results > div > table > tbody
      search_table = response_document.at_css(HTML_TABLE_CSS_SELECTOR)
      matches = []

      return matches if search_table.nil?
      compare_title = search_title.gsub(/[[:punct:]]/, '')
      compare_title = compare_title.downcase

      search_table_rows = search_table.css('tr')
      search_result_rows = search_table_rows[1..]

      search_result_rows.each do |tr|
        td_element = tr.at_css("td[headers='t2']")

        handle_element = td_element.at_css('a')
        handle = handle_element['href']
        ark_segments = handle.gsub('/handle', '')
        # https://library.princeton.edu/resolve/lookup?url=http://arks.princeton.edu/ark:/88435/dsp01xp68kg239
        ark = "http://arks.princeton.edu/ark:#{ark_segments}"

        result_title = td_element.text
        result_title_stripped = result_title.gsub(/[[:punct:]]/, '')
        result_title_downcased = result_title_stripped.downcase
        result_title_single_space = result_title_downcased.gsub(/\s{2,}/, ' ')

        result_title_ascii = result_title_single_space
        result_title_ascii = result_title_ascii.gsub(/[áâ]/, 'a')
        result_title_ascii = result_title_ascii.gsub(/[ç]/, 'c')
        result_title_ascii = result_title_ascii.gsub(/[èé]/, 'e')
        result_title_ascii = result_title_ascii.gsub(/[í]/, 'i')
        result_title_ascii = result_title_ascii.gsub(/[õ]/, 'o')

        result_title_normalized = result_title_ascii.gsub(/[[:cntrl:]]/, '')

        # Encoding bugs
        ascii_bytes = [160, 194]

        u_bytes = compare_title.force_encoding('utf-8').bytes.sort.uniq
        v_bytes = result_title_normalized.force_encoding('utf-8').bytes.sort.uniq
        v_bytes = v_bytes.reject { |v| ascii_bytes.include?(v) }

        matches << ark if u_bytes == v_bytes
      end

      matches
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
  end
  # rubocop:enable Metrics/BlockLength
end
