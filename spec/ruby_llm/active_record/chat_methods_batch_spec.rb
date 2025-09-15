# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods, type: :model do
  include_context 'with configured RubyLLM'

  let(:model) { 'gpt-4.1-nano' }

  before do
    # Create test models
    stub_const('BatchChat', Class.new(ActiveRecord::Base) do
      self.table_name = 'chats'
      acts_as_chat
    end)
  end

  describe 'acts_as_chat with batch methods' do
    it 'includes batch methods' do
      expect(BatchChat.new).to respond_to(:ask_batch)
      expect(BatchChat.new).to respond_to(:complete_batch)
      expect(BatchChat.new).to respond_to(:get_batch_status)
      expect(BatchChat.new).to respond_to(:get_batch_results)
      expect(BatchChat.new).to respond_to(:process_batch_results)
    end

    it 'delegates ask_batch to to_llm' do
      chat = BatchChat.new(model: model)
      requests = [{ message: 'Hello', custom_id: 'test' }]

      # Mock the to_llm method to return a mock chat
      mock_chat = instance_double(RubyLLM::Chat)
      allow(mock_chat).to receive(:ask_batch).and_return([])

      # Mock the create_user_message method to avoid database operations

      # Mock the complete_batch method to avoid calling to_llm again
      allow(chat).to receive_messages(to_llm: mock_chat, create_user_message: instance_double(ActiveRecord::Base),
                                      complete_batch: { batch_id: 'test', status: 'in_progress' })

      chat.ask_batch(requests)

      expect(chat).to have_received(:complete_batch).with(requests)
    end

    it 'delegates complete_batch to to_llm' do
      chat = BatchChat.new(model: model)
      requests = [{ message: 'Hello', custom_id: 'test' }]

      # Mock the to_llm method to return a mock chat
      mock_chat = instance_double(RubyLLM::Chat)
      allow(chat).to receive(:to_llm).and_return(mock_chat)
      allow(mock_chat).to receive(:complete_batch).and_return({ batch_id: 'test', status: 'in_progress' })

      # Set the @chat instance variable directly
      chat.instance_variable_set(:@chat, mock_chat)

      chat.complete_batch(requests)

      expect(mock_chat).to have_received(:complete_batch).with(requests)
    end

    it 'preserves existing functionality' do
      chat = BatchChat.new(model: model)

      # Test that existing methods still work
      expect(chat).to respond_to(:ask)
      expect(chat).to respond_to(:complete)
      expect(chat).to respond_to(:with_temperature)
      expect(chat).to respond_to(:with_params)
      expect(chat).to respond_to(:with_headers)
      expect(chat).to respond_to(:with_tool)
      expect(chat).to respond_to(:with_tools)
    end
  end

  describe 'legacy acts_as integration' do
    before do
      stub_const('LegacyBatchChat', Class.new(ActiveRecord::Base) do
        self.table_name = 'chats'
        include RubyLLM::ActiveRecord::ActsAsLegacy

        acts_as_chat
      end)
    end

    it 'includes batch methods in legacy integration' do
      expect(LegacyBatchChat.new).to respond_to(:ask_batch)
      expect(LegacyBatchChat.new).to respond_to(:complete_batch)
      expect(LegacyBatchChat.new).to respond_to(:get_batch_status)
      expect(LegacyBatchChat.new).to respond_to(:get_batch_results)
      expect(LegacyBatchChat.new).to respond_to(:process_batch_results)
    end

    it 'preserves existing legacy functionality' do
      chat = LegacyBatchChat.new

      # Test that existing methods still work
      expect(chat).to respond_to(:ask)
      expect(chat).to respond_to(:complete)
      expect(chat).to respond_to(:with_temperature)
      expect(chat).to respond_to(:with_params)
      expect(chat).to respond_to(:with_headers)
      expect(chat).to respond_to(:with_tool)
      expect(chat).to respond_to(:with_tools)
    end
  end
end
