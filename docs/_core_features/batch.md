# Batch Processing

RubyLLM supports asynchronous batch processing for providers that offer this capability, allowing you to process multiple requests efficiently in a single API call.

## Basic Usage

```ruby
# Create a batch chat instance
chat = RubyLLM.batch(model: 'claude-3-5-sonnet-20241022')

# Create batch and get batch information
requests = [
  { message: 'What is the weather?', custom_id: 'weather_1' },
  { message: 'What is the time?', custom_id: 'time_1' }
]

batch_info = chat.ask_batch(requests)
# Returns: { batch_id: "msgbatch_...", status: "in_progress", results_url: "..." }
```

## Asynchronous Processing

Batch processing is **asynchronous** - results are not returned immediately:

1. **Create Batch**: `ask_batch()` returns batch information
2. **Check Status**: Poll `get_batch_status(batch_id)` until complete
3. **Retrieve Results**: Call `get_batch_results(batch_id)` when done
4. **Process Results**: Save results to database

```ruby
# Step 1: Create batch
batch_info = chat.ask_batch(requests)
batch_id = batch_info[:batch_id]

# Step 2: Check status (poll until complete)
loop do
  status = chat.get_batch_status(batch_id)
  break if status['processing_status'] == 'completed'
  sleep 30 # Wait 30 seconds before checking again
end

# Step 3: Retrieve and process results
results = chat.get_batch_results(batch_id)
```

## Request Format

Each request in the batch must be a hash with:
- `:message` (required): The message content
- `:custom_id` (optional): Custom identifier for tracking
- `:with` (optional): Attachments or additional content

## Database Saving (ActiveRecord)

When using ActiveRecord models with `acts_as_chat`, batch processing saves user messages immediately and provides methods to process results:

```ruby
# Create a chat record
chat = Chat.create!(model: 'claude-3-5-sonnet-20241022')

# Step 1: Create batch (saves user messages immediately)
requests = [
  { message: 'Hello', custom_id: 'greeting' },
  { message: 'How are you?', custom_id: 'status' }
]

batch_info = chat.ask_batch(requests)
# User messages are saved immediately
puts chat.messages.count # => 2 (user messages)

# Step 2: Wait for completion and process results
batch_id = batch_info[:batch_id]

# Check status until complete
loop do
  status = chat.get_batch_status(batch_id)
  break if status['processing_status'] == 'completed'
  sleep 30
end

# Step 3: Process and save results
saved_messages = chat.process_batch_results(batch_id)
puts chat.messages.count # => 4 (2 user + 2 assistant messages)
```

### What Gets Saved

1. **User Messages**: Saved immediately when batch is created
2. **Assistant Responses**: Saved when `process_batch_results()` is called
3. **Token Counts**: Input and output token counts are preserved
4. **Model Association**: Messages are linked to the correct model
5. **Custom IDs**: Custom identifiers are preserved for tracking

### Error Handling

Failed requests in a batch are skipped and not saved:

```ruby
results = chat.get_batch_results(batch_id)
# Only successful results are processed and saved
# Failed requests are logged but not persisted
```

## Provider Support

Currently supported providers:
- Anthropic (Message Batches API)

## Error Handling

Batch processing includes comprehensive error handling:
- **Request validation**: Validates array structure and required fields
- **Batch size limits**: Enforces 10,000 request limit and 256MB payload limit
- **Custom ID validation**: Ensures unique custom IDs within each batch
- **HTTP error handling**: Proper error handling for API failures
- **Provider capability checking**: Raises errors for unsupported providers
- **Individual request error handling**: Skips failed requests in results
- **Graceful degradation**: Maintains functionality for unsupported providers

## Examples

### Basic Batch Processing

```ruby
chat = RubyLLM.batch(model: 'claude-3-5-sonnet-20241022')

requests = [
  { message: 'What is Ruby?', custom_id: 'ruby_question' },
  { message: 'What is Rails?', custom_id: 'rails_question' }
]

# Create batch
batch_info = chat.ask_batch(requests)
batch_id = batch_info[:batch_id]

# Wait for completion
loop do
  status = chat.get_batch_status(batch_id)
  break if status['processing_status'] == 'completed'
  sleep 30
end

# Get results
results = chat.get_batch_results(batch_id)
results.each do |result|
  if result['result']['type'] == 'completed'
    puts "#{result['custom_id']}: #{result['result']['response']['content'][0]['text']}"
  else
    puts "#{result['custom_id']}: Error - #{result['result']['error']['error']['message']}"
  end
end
```

### With Custom Parameters

```ruby
chat = RubyLLM.batch(model: 'claude-3-5-sonnet-20241022')
  .with_temperature(0.7)
  .with_params(max_tokens: 1000)

requests = [
  { message: 'Explain AI', custom_id: 'ai_explanation' },
  { message: 'Explain ML', custom_id: 'ml_explanation' }
]

batch_info = chat.ask_batch(requests)
# ... wait for completion and process results
```

### Error Handling

```ruby
begin
  batch_info = chat.ask_batch(requests)
rescue ArgumentError => e
  puts "Invalid request format: #{e.message}"
rescue NotImplementedError => e
  puts "Batch processing not supported: #{e.message}"
end
```
