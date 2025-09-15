# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM do
  include_context 'with configured RubyLLM'

  describe '.batch' do
    it 'creates a new Chat instance' do
      chat = described_class.batch(model: 'claude-3-5-sonnet-20241022')

      expect(chat).to be_a(RubyLLM::Chat)
      expect(chat.model.id).to eq('claude-3-5-sonnet-20241022')
    end

    it 'accepts provider parameter' do
      chat = described_class.batch(model: 'claude-3-5-sonnet-20241022', provider: 'anthropic')

      expect(chat).to be_a(RubyLLM::Chat)
      expect(chat.instance_variable_get(:@provider).slug).to eq('anthropic')
    end

    it 'accepts context parameter' do
      context = described_class.context
      chat = described_class.batch(context: context)

      expect(chat).to be_a(RubyLLM::Chat)
      expect(chat.instance_variable_get(:@context)).to eq(context)
    end
  end
end
