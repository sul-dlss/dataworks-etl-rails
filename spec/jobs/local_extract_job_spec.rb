# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LocalExtractJob do
  let(:job) { described_class }

  let(:dataset_record_set) { create(:dataset_record_set, provider: 'local') }

  before do
    allow(Extractors::Local).to receive(:call).and_return(dataset_record_set)
  end

  it 'performs textract' do
    described_class.perform_now

    expect(dataset_record_set.reload.job_id).not_to be_nil
    expect(Extractors::Local).to have_received(:call)
  end
end
