require "marc"
require "thor"
require "uri"
require "faraday"
require "nokogiri"

class EtdProcessor < Thor
  DEFAULT_DSPACE_URI = "https://dataspace.princeton.edu"

  attr_reader :file_path, :output_file_path, :dspace_uri

  desc "insert_arks", "insert ARKs into a MARC file"
  option :file_path, aliases: "-f", required: true
  option :output_file_path, aliases: "-o", required: true
  option :dspace_uri, default: DEFAULT_DSPACE_URI
  def insert_arks(file_path, output_file_path, dspace_url)
    @file_path = file_path
    @output_file_path = output_file_path
    @dspace_uri = URI.parse(dspace_url)

    marc_reader.each_with_index do |record, index|

      current_245 = record["245"]
      raise(ArgumentError, "Failed to find the title field 245 for record {index}") unless current_245

      title = current_245["a"]
      raise(ArgumentError, "Failed to find the title subfield 245$a for record {index}") unless title

      arks = query_for_dspace_item(title: title)
      next if arks.empty?
      ark = arks.first

      record_hash = record.to_hash
      record_hash_fields = record_hash["fields"]

      new_field = {
        "856" => {
          "ind1" => " ",
          "ind2" => " ",
          "subfields" => [
            {
              "u" => ark
            }
          ]
        }
      }

      record_hash["fields"] << new_field

      new_record = MARC::Record.new_from_hash(record_hash)
      marc_writer.write(new_record)
    end
  end

  no_commands do

    def marc_reader
      @marc_reader ||= MARC::Reader.new(file_path)
    end

    def marc_writer
      @marc_writer = MARC::Writer.new(output_file_path)
    end

    def dspace_search_uri
      @dspace_search_uri ||= begin
                               built = dspace_uri.dup
                               built.path = "/simple-search"
                               built
                             end
    end

    def query_for_dspace_item(title:)
      query_uri = dspace_search_uri.dup
      params = {
        query: title
      }

      response = Faraday.get(query_uri.to_s, params)
      raise(ArgumentError, "Failed to receive a response from the DSpace URI: #{query_uri.to_s}") unless response.success?

      response_document = Nokogiri::HTML.parse(response.body)
      # #content > div:nth-child(2) > div > div.col-md-9 > div.discovery-result-results > div > table > tbody
      search_table = response_document.at_css("#content > div:nth-child(2) > div > div.col-md-9 > div.discovery-result-results > div > table")
      search_table_rows = search_table.css("tr")
      search_result_rows = search_table_rows[1..]

      matches = []
      search_result_rows.each do |tr|
        td_element = tr.at_css("td[headers='t2']")

        handle_element = td_element.at_css('a')
        handle = handle_element['href']
        ark_segments = handle.gsub('/handle', '')
        # https://library.princeton.edu/resolve/lookup?url=http://arks.princeton.edu/ark:/88435/dsp01xp68kg239
        ark = "http://arks.princeton.edu/ark:#{ark_segments}"

        query_title = title.gsub(/[[:punct:]]/, '')

        result_title = td_element.text
        result_title_stripped = result_title.gsub(/[[:punct:]]/, '')
        result_title_normalized = result_title_stripped.downcase

        matches << ark if /#{query_title}/i =~ result_title_normalized
      end

      matches
    end
  end
end
