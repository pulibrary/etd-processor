# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EtdProcessor do
  subject(:etd_processor) { described_class.new }
  let(:file_path) { File.join('spec', 'fixtures', '28545254.mrc') }
  let(:output_file_path) { File.join('spec', 'tmp', 'test.mrc') }
  let(:dspace_uri) { 'https://dataspace.princeton.edu' }

  describe '#insert_arks' do
    it 'inserts ARK URIs into the desired MARC record fields' do
      etd_processor.insert_arks(file_path, output_file_path, dspace_uri)

      output_reader = MARC::Reader.new(output_file_path)
      output_records = output_reader.to_a

      expect(output_records.length).to eq(1)

      output_record = output_records.first
      fields = output_record.fields.select { |f| f.tag == "856" }
      expect(fields.length).to eq(2)
      field = fields.last

      expect(field).to be_a(MARC::DataField)
      expect(field["u"]).to eq("http://arks.princeton.edu/ark:/88435/dsp01bc386n34x")
    end

    context "when the HTTP request for the DSpace search responds with an error" do
      let(:response) { instance_double(Faraday::Response) }

      before do
        allow(response).to receive(:success?).and_return(false)
        allow(Faraday).to receive(:get).and_return(response)
      end

      it "raises an error" do
        expect { etd_processor.insert_arks(file_path, output_file_path, dspace_uri) }.to raise_error(ArgumentError, "Failed to receive a response from the DSpace URI: https://dataspace.princeton.edu/simple-search")
      end
    end

    context "when writing the original MARC records to a separate file" do
      let(:file_path) { File.join('spec', 'fixtures', 'sept_2021.mrc') }
      let(:original_marc_file_path) { File.join('spec', 'tmp', 'original.mrc') }

      it 'writes the unmodified MARC records to the desired path' do
        etd_processor.insert_arks(file_path, output_file_path, dspace_uri, original_marc_file_path)

        output_reader = MARC::Reader.new(output_file_path)
        output_records = output_reader.to_a

        expect(output_records.length).to eq(166)

        original_reader = MARC::Reader.new(original_marc_file_path)
        original_records = original_reader.to_a

        expect(original_records.length).to eq(20)

        output_record = original_records.first
        fields = output_record.fields.select { |f| f.tag == "856" }
        expect(fields.length).to eq(1)
        field = fields.first

        expect(field).to be_a(MARC::DataField)
        expect(field["u"]).to include("gateway.proquest.com")
        expect(field["u"]).not_to include("arks.princeton.edu")
      end
    end
  end
end
