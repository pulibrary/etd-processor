# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EtdProcessor do
  subject(:etd_processor) { described_class.new }
  let(:file_path) { File.join('spec', 'fixtures', '28545254.mrc') }
  let(:output_file_path) { File.join('spec', 'tmp', 'output.mrc') }
  let(:file_path_invalid) { File.join('spec', 'fixtures', '28545254_invalid.mrk') }
  let(:output_file_path_invalid) { File.join('spec', 'tmp', 'output_invalid.json') }
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

        expect(output_records.length).to eq(186)

        original_reader = MARC::Reader.new(original_marc_file_path)
        original_records = original_reader.to_a

        expect(original_records.length).to eq(0)
      end
    end

    context "when trying to read from a non-standard file format" do
      it 'raises an error' do
        expect { etd_processor.insert_arks(file_path_invalid, output_file_path, dspace_uri) }.to raise_error(ArgumentError, 'Could not create marc reader, only XML and MRC files are supported for read')
      end
    end

    context "when trying to write to a non-standard file format" do
      it 'raises an error' do
        expect { etd_processor.insert_arks(file_path, output_file_path_invalid, dspace_uri) }.to raise_error(ArgumentError, 'Could not create marc writer, only XML and MRC files are supported for writing')
      end
    end
  end

  describe '#inspect_marc' do
    let(:output_file_path) { File.join('spec', 'tmp', 'output_inspect.mrc') }

    before do
      etd_processor.insert_arks(file_path, output_file_path, dspace_uri)
    end

    it 'prints to STDOUT a summart report for a given MARC record' do
      out = capture(:stdout) do
        etd_processor.inspect_marc(file_path)
      end

      expect(out.chomp).to include("# MARC Record Summary Report")
      expect(out.chomp).to include("## Record Summary")
      expect(out.chomp).to include("| leader | title | URL |")
      expect(out.chomp).to include("| ------ | ----- | --- |")
      expect(out.chomp).to include("| 03491nam a2200457   4500 | Slaves of God: Augustine and Other Romans on Religion and Politics. | http://gateway.proquest.com/openurl?url_ver=Z39.88-2004&rft_val_fmt=info:ofi/fmt:kev:mtx:dissertation&res_dat=xri:pqm&rft_dat=xri:pqdiss:28545254 |")
      expect(out.chomp).to include("## File Summary")
      expect(out.chomp).to include("| file path | total number of MARC records |")
      expect(out.chomp).to include("| --------- | ---------------------------- |")
      expect(out.chomp).to include("| spec/fixtures/28545254.mrc | 1 |")
    end

    context "when inspecting a file with ARKs inserted" do
      before do
        etd_processor.insert_arks(file_path, output_file_path, dspace_uri)
      end

      it 'prints to STDOUT a summart report' do
        out = capture(:stdout) do
          etd_processor.inspect_marc(output_file_path)
        end

        expect(out.chomp).to include("# MARC Record Summary Report")
        expect(out.chomp).to include("## Record Summary")
        expect(out.chomp).to include("| leader | title | URL |")
        expect(out.chomp).to include("| ------ | ----- | --- |")
        expect(out.chomp).to include("| 03559nam a2200469   4500 | Slaves of God: Augustine and Other Romans on Religion and Politics. | http://arks.princeton.edu/ark:/88435/dsp01bc386n34x |")
        expect(out.chomp).to include("## File Summary")
        expect(out.chomp).to include("| file path | total number of MARC records |")
        expect(out.chomp).to include("| --------- | ---------------------------- |")
        expect(out.chomp).to include("| spec/tmp/output_inspect.mrc | 1 |")
      end
    end
  end
end
