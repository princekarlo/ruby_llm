# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#ask_batch' do
    it 'validates requests array' do
      chat = described_class.new

      expect { chat.ask_batch('not an array') }.to raise_error(ArgumentError, 'Requests must be an array')
      expect { chat.ask_batch([]) }.to raise_error(ArgumentError, 'Requests array cannot be empty')
    end

    it 'validates each request structure' do
      chat = described_class.new

      expect do
        chat.ask_batch([{ invalid: 'request' }])
      end.to raise_error(ArgumentError,
                         /Request at index 0 must be a hash with :message key/)
    end

    it 'calls complete_batch with validated requests' do
      chat = described_class.new
      requests = [{ message: 'Hello', custom_id: '1' }, { message: 'World', custom_id: '2' }]

      allow(chat).to receive(:complete_batch).and_return({ batch_id: 'test_batch', status: 'in_progress' })

      result = chat.ask_batch(requests)

      expect(chat).to have_received(:complete_batch).with(requests)
      expect(result).to eq({ batch_id: 'test_batch', status: 'in_progress' })
    end
  end

  describe '#complete_batch' do
    it 'raises error for unsupported providers' do
      chat = described_class.new(provider: 'openai')
      requests = [{ message: 'Hello' }]

      expect { chat.complete_batch(requests) }.to raise_error(NotImplementedError, /Batch processing not implemented/)
    end

    it 'calls provider complete_batch method' do
      chat = described_class.new(model: 'claude-3-5-sonnet-20241022', provider: 'anthropic')
      requests = [{ message: 'Hello' }]

      allow(chat.instance_variable_get(:@provider)).to receive(:complete_batch)
        .and_return({ batch_id: 'test_batch', status: 'in_progress' })

      result = chat.complete_batch(requests)

      expect(chat.instance_variable_get(:@provider)).to have_received(:complete_batch).with(
        requests,
        tools: {},
        temperature: nil,
        model: chat.model,
        params: {},
        headers: {},
        schema: nil
      )
      expect(result).to eq({ batch_id: 'test_batch', status: 'in_progress' })
    end
  end

  describe '#get_batch_status' do
    it 'raises error for unsupported providers' do
      chat = described_class.new(provider: 'openai')

      expect do
        chat.get_batch_status('test_batch')
      end.to raise_error(NotImplementedError, /Batch status checking not supported/)
    end

    it 'calls provider get_batch_status method' do
      chat = described_class.new(model: 'claude-3-5-sonnet-20241022', provider: 'anthropic')
      batch_id = 'test_batch'

      allow(chat.instance_variable_get(:@provider)).to receive(:get_batch_status)
        .and_return({ 'processing_status' => 'completed' })

      result = chat.get_batch_status(batch_id)

      expect(chat.instance_variable_get(:@provider)).to have_received(:get_batch_status).with(batch_id)
      expect(result).to eq({ 'processing_status' => 'completed' })
    end
  end

  describe '#get_batch_results' do
    it 'raises error for unsupported providers' do
      chat = described_class.new(provider: 'openai')

      expect do
        chat.get_batch_results('test_batch')
      end.to raise_error(NotImplementedError, /Batch results retrieval not supported/)
    end

    it 'calls provider get_batch_results method' do
      chat = described_class.new(model: 'claude-3-5-sonnet-20241022', provider: 'anthropic')
      batch_id = 'test_batch'

      allow(chat.instance_variable_get(:@provider)).to receive(:get_batch_results)
        .and_return([{ 'response' => { 'content' => 'Hello' } }])

      result = chat.get_batch_results(batch_id)

      expect(chat.instance_variable_get(:@provider)).to have_received(:get_batch_results).with(batch_id)
      expect(result).to eq([{ 'response' => { 'content' => 'Hello' } }])
    end
  end
end
