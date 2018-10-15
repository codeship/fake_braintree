require 'braintree'
require 'fileutils'
require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'

require 'fake_braintree/version'
require 'fake_braintree/registry'
require 'fake_braintree/server'

module FakeBraintree
  mattr_accessor :registry, :verify_all_cards, :decline_all_cards

  # Public: Prepare FakeBraintree for use and start the API server.
  #
  # options: Hash options to configure (default: {}):
  #          :gateway_port - The port to start the API server on (optional).
  #                          If not given, an ephemeral port will be used.
  #
  def self.activate!(options = {})
    $stdout.puts "Thread info name: #{Thread.current.name}, id: #{Thread.current.__id__}, status: #{Thread.current.status}"

    $stdout.puts 'Start Initialize Registry'
    initialize_registry
    $stdout.puts 'Succeded in Initializing Registry'

    $stdout.puts '----------------------'

    $stdout.puts 'Start verify all cards'
    self.verify_all_cards = false
    $stdout.puts 'Succeded all cards worked!'

    $stdout.puts '----------------------'

    $stdout.puts 'Start clear!'
    clear!
    $stdout.puts 'Succeded all cards worked!'

    $stdout.puts '----------------------'

    $stdout.puts 'Start setting conf!'
    set_configuration
    $stdout.puts 'Succeded setting conf!'

    $stdout.puts '----------------------'

    $stdout.puts 'Start app server!'
    boot_server(port: options.fetch(:gateway_port, nil))
    $stdout.puts 'Succeeded starting app server!'
    $stdout.flush
  end

  def self.log_file_path
    'tmp/log'
  end

  def self.clear!
    self.registry.clear!
    self.decline_all_cards = false
    clear_log!
  end

  def self.clear_log!
    FileUtils.mkdir_p(File.dirname(log_file_path))
    File.new(log_file_path, 'w').close
  end

  def self.failure?(card_number)
    registry.failure?(card_number)
  end

  def self.failure_response(card_number = nil)
    failure = registry.failures[card_number] || {}
    failure['errors'] ||= { 'errors' => [] }

    {
      'message' => failure['message'],
      'verification' => {
        'status' => failure['status'],
        'processor_response_text' => failure['message'],
        'processor_response_code' => failure['code'],
        'gateway_rejection_reason' => 'cvv',
        'cvv_response_code' => failure['code']
      },
      'errors' => failure['errors'],
      'params' => {}
    }
  end

  def self.create_failure
    {
      'message' => 'Do Not Honor',
      'verification' => {
        'status' => 'processor_declined',
        'processor_response_text' => 'Do Not Honor',
        'processor_response_code' => '2000'
      },
      'errors' => { 'errors' => [] },
      'params' => {}
    }
  end

  def self.decline_all_cards!
    self.decline_all_cards = true
  end

  def self.decline_all_cards?
    decline_all_cards
  end

  def self.verify_all_cards!
    self.verify_all_cards = true
  end

  def self.generate_transaction(options = {})
    history_item = {
     'timestamp' => Time.now,
     'amount' => options[:amount],
     'status' => options[:status]
    }
    created_at = options[:created_at] || Time.now
    {
      'status_history' => [history_item],
      'subscription_id' => options[:subscription_id],
      'created_at' => created_at,
      'amount' => options[:amount]
    }
  end

  private

  def self.set_configuration
    Braintree::Configuration.environment = :development
    Braintree::Configuration.merchant_id = 'xxx'
    Braintree::Configuration.public_key  = 'xxx'
    Braintree::Configuration.private_key = 'xxx'
    Braintree::Configuration.logger = Logger.new(log_file_path)
  end

  def self.boot_server(options = {})
    server = Server.new(options)
    server.boot
    ENV['GATEWAY_PORT'] = server.port.to_s
  end

  def self.initialize_registry
    self.registry = Registry.new
  end
end
