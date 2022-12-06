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
  end
end
