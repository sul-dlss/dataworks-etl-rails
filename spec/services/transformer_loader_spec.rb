# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransformerLoader do
  let(:redivis_dataset_record_set) do
    create(:dataset_record_set, :with_dataset_records, complete: true, dataset_records_count: 2)
  end

  let(:datacite_dataset_record_set) do
    create(:dataset_record_set, :with_dataset_records, complete: true, dataset_records_count: 2, provider: 'datacite',
                                                       extractor: 'Extractors::Datacite')
  end

  let(:solr_service) { instance_double(SolrService, commit: true, delete_by_query: true) }

  before do
    allow(SolrService).to receive(:new).and_return(solr_service)
    allow(DatasetTransformerLoader).to receive(:call)

    # Incomplete dataset record set
    create(:dataset_record_set, :with_dataset_records, complete: false)
    # Older dataset record set
    create(:dataset_record_set, :with_dataset_records, complete: true, created_at: 1.month.ago)

    # Same dataset for different providers
    datacite_dataset_record_set.dataset_records.first.update!(doi: redivis_dataset_record_set.dataset_records.first.doi)
  end

  it 'transforms and loads' do
    described_class.call(load_id: 'load123')

    expect(DatasetTransformerLoader).to have_received(:call).exactly(3).times
    expect(DatasetTransformerLoader).to have_received(:call).with(
      dataset_records: [redivis_dataset_record_set.dataset_records.first,
                        datacite_dataset_record_set.dataset_records.first],
      solr: solr_service, load_id: String
    ).once
    expect(DatasetTransformerLoader).to have_received(:call).with(
      dataset_records: [redivis_dataset_record_set.dataset_records.last],
      solr: solr_service, load_id: String
    ).once
    expect(DatasetTransformerLoader).to have_received(:call).with(
      dataset_records: [datacite_dataset_record_set.dataset_records.last],
      solr: solr_service, load_id: String
    ).once
    expect(solr_service).to have_received(:commit).once
    expect(solr_service).to have_received(:delete_by_query).with(query: '-load_id_ssi:"load123"').once
  end

  context 'when there is an error in mapping' do
    before do
      allow(DatasetTransformerLoader).to receive(:call).and_raise(DataworksMappers::MappingError)
    end

    it 'raises an error' do
      expect { described_class.call }.to raise_error(DataworksMappers::MappingError)
    end
  end

  context 'when there is an error in mapping and fail_fast is false' do
    before do
      allow(DataworksMappers::Redivis).to receive(:call).and_raise(DataworksMappers::MappingError)
    end

    it 'does not raise an error' do
      expect { described_class.call(fail_fast: false) }.not_to raise_error
    end
  end
end
