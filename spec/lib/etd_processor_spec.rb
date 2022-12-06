require 'spec_helper'

RSpec.describe EtdProcessor do
  subject(:etd_processor) { described_class.new }
  let(:file_path) { File.join('spec', 'fixtures', '28545254.mrc') }
  let(:output_file_path) { File.join('tmp', 'test.mrc') }
  # let(:dspace_uri) { 'http://localhost' }
  let(:dspace_uri) { "https://dataspace.princeton.edu" }

  describe '#insert_arks' do
    it 'inserts ARK URIs into the desired MARC record fields' do

      etd_processor.insert_arks(file_path, output_file_path, dspace_uri)
    end
  end
end
