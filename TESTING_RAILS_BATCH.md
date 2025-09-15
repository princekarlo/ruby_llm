# Testing Batch Processing in Ruby on Rails

This guide shows how to test the batch processing feature in a local Ruby on Rails environment.

## Prerequisites

1. **Ruby 3.1.2** (as specified in `.tool-versions`)
2. **Rails 7.0+** (for ActiveRecord integration)
3. **Anthropic API Key** (for testing with real API)

## Setup Steps

### 1. Install the Gem Locally

```bash
# Build the gem
gem build ruby_llm.gemspec

# Install locally
gem install ruby_llm-*.gem

# Or use bundler with local path
bundle config local.ruby_llm .
```

### 2. Create a Test Rails Application

```bash
# Create new Rails app
rails new batch_test_app --api --database=sqlite3
cd batch_test_app

# Add to Gemfile
echo "gem 'ruby_llm', path: '../ruby_llm'" >> Gemfile
echo "gem 'dotenv-rails'" >> Gemfile

# Install gems
bundle install
```

### 3. Configure Environment

Create `.env` file:
```bash
# .env
ANTHROPIC_API_KEY=your_anthropic_api_key_here
```

### 4. Generate Models

```bash
# Generate Chat model
rails generate model Chat model_id:string provider:string

# Generate Message model
rails generate model Message chat:references role:string content:text input_tokens:integer output_tokens:integer

# Run migrations
rails db:migrate
```

### 5. Configure Models

Update `app/models/chat.rb`:
```ruby
class Chat < ApplicationRecord
  has_many :messages, dependent: :destroy

  # Add RubyLLM integration
  acts_as_chat
end
```

Update `app/models/message.rb`:
```ruby
class Message < ApplicationRecord
  belongs_to :chat

  # Add RubyLLM integration
  acts_as_message
end
```

### 6. Configure RubyLLM

Create `config/initializers/ruby_llm.rb`:
```ruby
RubyLLM.configure do |config|
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.default_model = 'claude-3-5-sonnet-20241022'
end
```

## Testing Examples

### 1. Basic Batch Processing Test

Create `test_batch_basic.rb`:
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

puts "🧪 Testing Basic Batch Processing"
puts "=" * 50

# Create a chat
chat = Chat.create!(model: 'claude-3-5-sonnet-20241022')

# Prepare batch requests
requests = [
  { message: 'What is Ruby?', custom_id: 'ruby_question' },
  { message: 'What is Rails?', custom_id: 'rails_question' },
  { message: 'What is AI?', custom_id: 'ai_question' }
]

puts "📝 Creating batch with #{requests.length} requests..."

begin
  # Create batch (returns batch info, not results)
  batch_info = chat.ask_batch(requests)

  puts "✅ Batch created successfully!"
  puts "   Batch ID: #{batch_info[:batch_id]}"
  puts "   Status: #{batch_info[:status]}"
  puts "   Created at: #{batch_info[:created_at]}"
  puts "   User messages saved: #{chat.messages.count}"

  # Check status
  puts "\n⏳ Checking batch status..."
  status = chat.get_batch_status(batch_info[:batch_id])
  puts "   Current status: #{status['processing_status']}"

  if status['processing_status'] == 'completed'
    puts "\n📥 Processing results..."
    saved_messages = chat.process_batch_results(batch_info[:batch_id])
    puts "   Assistant messages saved: #{saved_messages.length}"
    puts "   Total messages: #{chat.messages.count}"

    # Display results
    chat.messages.order(:created_at).each_with_index do |msg, i|
      puts "   #{i + 1}. #{msg.role.capitalize}: #{msg.content[0..100]}..."
    end
  else
    puts "   ⏳ Batch still processing. Check again later."
  end

rescue => e
  puts "❌ Error: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
end
```

### 2. Advanced Batch Processing Test

Create `test_batch_advanced.rb`:
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

puts "🧪 Testing Advanced Batch Processing"
puts "=" * 50

# Create a chat with tools
chat = Chat.create!(model: 'claude-3-5-sonnet-20241022')
  .with_temperature(0.7)
  .with_params(max_tokens: 1000)

# Define a simple tool
class WeatherTool
  def self.name
    'get_weather'
  end

  def self.description
    'Get current weather for a location'
  end

  def self.parameters
    {
      location: {
        type: 'string',
        description: 'The city name',
        required: true
      }
    }
  end

  def call(args)
    "The weather in #{args['location']} is sunny and 72°F"
  end
end

# Add tool to chat
chat.with_tool(WeatherTool)

# Prepare batch requests with tools
requests = [
  { message: 'What is the weather in New York?', custom_id: 'weather_ny' },
  { message: 'What is the weather in London?', custom_id: 'weather_london' },
  { message: 'Explain quantum computing', custom_id: 'quantum_explanation' }
]

puts "📝 Creating batch with tools and #{requests.length} requests..."

begin
  # Create batch
  batch_info = chat.ask_batch(requests)

  puts "✅ Batch created successfully!"
  puts "   Batch ID: #{batch_info[:batch_id]}"
  puts "   Status: #{batch_info[:status]}"
  puts "   User messages saved: #{chat.messages.count}"

  # Poll for completion
  puts "\n⏳ Polling for completion..."
  max_attempts = 10
  attempt = 0

  loop do
    attempt += 1
    status = chat.get_batch_status(batch_info[:batch_id])
    current_status = status['processing_status']

    puts "   Attempt #{attempt}/#{max_attempts}: #{current_status}"

    if current_status == 'completed'
      puts "\n📥 Processing results..."
      saved_messages = chat.process_batch_results(batch_info[:batch_id])
      puts "   Assistant messages saved: #{saved_messages.length}"
      puts "   Total messages: #{chat.messages.count}"

      # Display results
      chat.messages.order(:created_at).each_with_index do |msg, i|
        puts "\n   #{i + 1}. #{msg.role.capitalize}:"
        puts "      #{msg.content[0..200]}..."
        if msg.input_tokens
          puts "      Tokens: #{msg.input_tokens} in, #{msg.output_tokens} out"
        end
      end
      break
    elsif current_status == 'failed'
      puts "   ❌ Batch failed!"
      break
    elsif attempt >= max_attempts
      puts "   ⏰ Timeout after #{max_attempts} attempts"
      break
    else
      sleep 30 # Wait 30 seconds before next check
    end
  end

rescue => e
  puts "❌ Error: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
end
```

### 3. Error Handling Test

Create `test_batch_errors.rb`:
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

puts "🧪 Testing Batch Error Handling"
puts "=" * 50

chat = Chat.create!(model: 'claude-3-5-sonnet-20241022')

# Test 1: Invalid requests array
puts "\n1. Testing invalid requests array..."
begin
  chat.ask_batch("not an array")
rescue ArgumentError => e
  puts "   ✅ Caught expected error: #{e.message}"
end

# Test 2: Empty requests array
puts "\n2. Testing empty requests array..."
begin
  chat.ask_batch([])
rescue ArgumentError => e
  puts "   ✅ Caught expected error: #{e.message}"
end

# Test 3: Invalid request structure
puts "\n3. Testing invalid request structure..."
begin
  chat.ask_batch([{ invalid: 'request' }])
rescue ArgumentError => e
  puts "   ✅ Caught expected error: #{e.message}"
end

# Test 4: Large batch (should fail validation)
puts "\n4. Testing large batch..."
large_requests = Array.new(10001) { |i| { message: "Test message #{i}" } }
begin
  chat.ask_batch(large_requests)
rescue ArgumentError => e
  puts "   ✅ Caught expected error: #{e.message}"
end

puts "\n✅ All error handling tests passed!"
```

## Running the Tests

```bash
# Make scripts executable
chmod +x test_batch_*.rb

# Run basic test
ruby test_batch_basic.rb

# Run advanced test
ruby test_batch_advanced.rb

# Run error handling test
ruby test_batch_errors.rb
```

## Rails Console Testing

You can also test interactively in Rails console:

```bash
rails console
```

```ruby
# Create a chat
chat = Chat.create!(model: 'claude-3-5-sonnet-20241022')

# Test basic functionality
requests = [
  { message: 'Hello', custom_id: 'test1' },
  { message: 'World', custom_id: 'test2' }
]

# Create batch
batch_info = chat.ask_batch(requests)
puts batch_info

# Check status
status = chat.get_batch_status(batch_info[:batch_id])
puts status

# Process results when complete
if status['processing_status'] == 'completed'
  results = chat.process_batch_results(batch_info[:batch_id])
  puts "Saved #{results.length} messages"
end
```

## Expected Output

When working correctly, you should see:

1. **Batch Creation**: Success message with batch ID and status
2. **User Messages**: Immediately saved to database
3. **Status Polling**: Shows processing status updates
4. **Results Processing**: Assistant messages saved when complete
5. **Error Handling**: Proper error messages for invalid inputs

## Troubleshooting

### Common Issues

1. **API Key Missing**: Ensure `ANTHROPIC_API_KEY` is set in `.env`
2. **Model Not Found**: Check if model ID is correct
3. **Network Issues**: Check internet connection
4. **Rate Limits**: Wait between requests if hitting limits

### Debug Mode

Add to `config/initializers/ruby_llm.rb`:
```ruby
RubyLLM.configure do |config|
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.default_model = 'claude-3-5-sonnet-20241022'
  config.logger = Rails.logger
  config.log_level = :debug
end
```

This will provide detailed logging of API calls and responses.
