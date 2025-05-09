# frozen_string_literal: true

# Performs transformation from source metadata to Solr documents and loading into Solr for a single dataset
class DatasetTransformerLoader
  # These providers are ordered by preference for mapping.
  PROVIDERS = %w[sdr datacite local searchworks dryad redivis zenodo].freeze

  def self.call(...)
    new(...).call
  end

  def initialize(dataset_records:, load_id:, solr: SolrService.new)
    @dataset_records = dataset_records
    @solr = solr
    @load_id = load_id
  end

  def call
    # Reloading because the provided DatasetRecord missing the source
    dataset_record = dataset_records.first.reload
    solr_doc = solr_doc_for(dataset_record:)
    solr.add(solr_doc:) if solr_doc
  end

  private

  attr_reader :solr, :load_id

  # @return [Array<DatasetRecord>] dataset records ordered by provider preference
  def dataset_records
    @dataset_records.sort_by do |dataset_record|
      PROVIDERS.index(dataset_record.provider)
    end
  end

  def mapper_for(dataset_record:)
    "DataworksMappers::#{dataset_record.provider.camelize}".constantize
  end

  def solr_doc_for(dataset_record:) # rubocop:disable Metrics/AbcSize
    Honeybadger.context(dataset_record_id: dataset_record.id, provider: dataset_record.provider,
                        dataset_id: dataset_record.dataset_id)
    metadata = mapper_for(dataset_record:).call(source: dataset_record.source)
    check_mapping_success(dataset_record:)

    SolrMapper.call(metadata:, doi: dataset_record.doi, id: dataset_record.external_dataset_id, load_id:)
  rescue DataworksMappers::MappingError => e
    return if ignore?(dataset_record:)

    Rails.logger.error "Mapping error for dataset_record_id #{dataset_record.id}: #{e.message}"
    Honeybadger.notify(e)
    raise
  end

  def ignore?(dataset_record:)
    ignore_dataset_ids(provider: dataset_record.provider).include?(dataset_record.dataset_id)
  end

  def ignore_dataset_ids(provider:)
    @ignore_dataset_ids ||= Settings[provider]&.ignore || []
  end

  def check_mapping_success(dataset_record:)
    return unless ignore?(dataset_record:)

    msg = "Dataset #{dataset_record.dataset_id} (#{dataset_record.provider}) is ignored but mapping succeeded"
    Rails.logger.info(msg)
    Honeybadger.notify(msg)
  end
end
