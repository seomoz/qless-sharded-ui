# Encoding: utf-8

begin
  require_relative '../bundle/bundler/setup'
rescue LoadError
  require 'bundler'
  Bundler.setup
end

require 'rspec/fire'

module QlessSpecHelpers
  def with_env_vars(vars)
    original = ENV.to_hash
    vars.each { |k, v| ENV[k] = v }

    begin
      yield
    ensure
      ENV.replace(original)
    end
  end

  def clear_qless_memoization
    Qless.instance_eval do
      instance_variables.each do |ivar|
        remove_instance_variable(ivar)
      end
    end
  end
end

require 'yaml'

module RedisHelpers
  extend self

  def redis_configs
    return @redis_configs unless @redis_configs.nil?

    config_filepath = File.join('.', 'spec', 'redis_configs', '*.yml')
    config_files = Dir[config_filepath]

    @redis_configs = config_files.map do |path|
      YAML.load_file(path)
    end
  end

  def redis_urls
    return ['redis://localhost:6390/0', 'redis://localhost:6391/0'] if redis_configs.empty?
    cs = redis_configs
    cs.map { |c| "redis://#{c[:host]}:#{c[:port]}/#{c.fetch(:db, 0)}" }
  end

  def new_clients
    redis_configs.map { |c| Qless::Client.new(c) }
  end

  def new_redises
    redis_configs.map { |c| Redis.new(c) }
  end

  def any_keys?
    new_redises.map { |r| r.keys('*').any? }.any?
  end
end

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.filter_run :f
  c.run_all_when_everything_filtered = true
  c.include RSpec::Fire
  c.include QlessSpecHelpers

  c.before(:each, :js) do
    pending 'Skipping JS test because JS tests have been flaky on Travis.'
  end if ENV['TRAVIS']
end

using_integration_context = false
shared_context 'redis integration', :integration do
  using_integration_context = true
  include RedisHelpers

  # A qless client subject to the redis configuration
  let(:clients) { new_clients }
  # A plain redis client with the same redis configuration
  let(:redises)  { new_redises }

  before(:each) { redises.map { |r| r.script(:flush) } }
  after(:each)  { redises.map { |r| r.flushdb } }
end

RSpec.configure do |c|
  c.before(:suite) do
    if using_integration_context && RedisHelpers.any_keys?
      configs = RedisHelpers.redis_configs

      commands = configs.map do |config|
        "redis-cli -h #{config.fetch(:host, "127.0.0.1")} -p #{config.fetch(:port, 6379)} -n #{config.fetch(:db, 0)} flushdb"
      end.join(', ')
      
      msg = "Aborting since there are keys in your Redis DB(s) and we don't want to accidentally clear data you may care about."
      msg << "  To clear your DB(s), run: `#{commands}`"
      raise msg
    end
  end
end

# This context kills all the non-main threads and ensure they're cleaned up
shared_context 'stops all non-main threads', :uses_threads do
  after(:each) do
    # We're going to kill all the non-main threads
    threads = Thread.list - [Thread.main]
    threads.each(&:kill)
    threads.each(&:join)
  end
end
