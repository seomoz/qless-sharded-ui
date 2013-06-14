require 'sinatra/base'
require 'qless'

# Much of this is shamelessly poached from the resque web client

module Qless
  class ShardedClient
    attr_reader :name, :client, :path

    def initialize(name, client, path)
      @name = name
      @path = path
      @client = client
    end
  end

  class ShardedUI < Sinatra::Base
    # Path-y-ness
    dir = File.dirname(File.expand_path(__FILE__))
    set :views        , "#{dir}/sharded_ui/views"
    set :public_folder, "#{dir}/sharded_ui/static"

    # For debugging purposes at least, I want this
    set :reload_templates, true

    # I'm not sure what this option is -- I'll look it up later
    # set :static, true

    def initialize(clients)
      @clients = clients
      super
    end

    helpers do
      include Rack::Utils

      def url_path(*path_parts)
        [ path_prefix, path_parts ].join("/").squeeze('/')
      end
      alias_method :u, :url_path

      def path_prefix
        request.env['SCRIPT_NAME']
      end

      def url_with_modified_query
        url = URI(request.url)
        existing_query = Rack::Utils.parse_query(url.query)
        url.query = Rack::Utils.build_query(yield existing_query)
        url.to_s
      end

      def page_url(offset)
        url_with_modified_query do |query|
          query.merge('page' => current_page + offset)
        end
      end

      def next_page_url
        page_url 1
      end

      def prev_page_url
        page_url -1
      end

      def current_page
        @current_page ||= begin
          Integer(params[:page])
        rescue
          1
        end
      end

      def tabs
        # No tabs for now
        return []
      end

      def application_name
        if @clients.length > 0 then
          @clients[0].client.config['application']
        else
          'Qless Sharded UI'
        end
      end

      def queues
        # This will return an array with information about the various queues
        # we have as well as the number of jobs each worker has
        #
        # [{
        #    :name => 'testing',
        #    :clients => [{
        #         :name => 'foo-1',
        #         :path => '/foo-1'
        #         :counts => ...
        #    }, ...],
        #    # The total number of job counts
        #    :counts => {
        #         :stalled => ...,
        #         :waiting => ...,
        #         # The number of clients that have that queue paused
        #         :paused  => 2
        #    }
        # }, ...]
        results = Hash.new
        @clients.each do |client|
          counts = client.client.queues.counts
          counts.each do |obj|
            if results[obj['name']].nil? then
              results[obj['name']] = {
                :name => obj['name'],
                :clients => [],
                :counts => {
                  :paused => 0,
                  :stalled => 0,
                  :waiting => 0,
                  :running => 0,
                  :depends => 0,
                  :recurring => 0,
                  :scheduled => 0,
                }
              }
            end

            results[obj['name']][:clients].push({
              :name => client.name,
              :path => client.path,
              :counts => obj
            })

            [:stalled, :waiting, :running, :depends, :recurring,
              :scheduled].each do |kind|
              results[obj['name']][:counts][kind] += obj[kind.to_s]
            end
            if obj['paused'] then
              results[obj['name']][:counts][:paused] += 1
            end
          end
        end
        results.values.sort_by { |k| k[:name] }
      end

      def workers
        # [{
        #    :name => 'worker',
        #    :clients => [{
        #         :name => 'foo-1',
        #         :path => '/foo-1'
        #         :counts => {
        #             :jobs => ...,
        #             :stalled => ...,
        #         }
        #    }, ...],
        #    # The total number of job counts
        #    :counts => {
        #        :jobs => ...,
        #        :stalled => ...
        #    }
        # }, ...]
        results = Hash.new
        @clients.each do |client|
          counts = client.client.workers.counts
          counts.each do |obj|
            if results[obj['name']].nil? then
              results[obj['name']] = {
                :name => obj['name'],
                :clients => [],
                :counts => {
                  :jobs => 0,
                  :stalled => 0
                }
              }
            end

            results[obj['name']][:clients].push({
              :name => client.name,
              :path => client.path,
              :counts => {
                :jobs => obj['jobs'],
                :stalled => obj['stalled']
              }
            })

            results[obj['name']][:counts][:jobs   ] += obj['jobs']
            results[obj['name']][:counts][:stalled] += obj['stalled']
          end
        end
        results
      end

      def failed
        # Will return stats like this
        #
        # [{
        #    :group => 'foo',
        #    :clients => [{
        #         :name => 'foo-1',
        #         :path => '/foo-1'
        #         :count => ...
        #    }, ...],
        #    # The total number of job counts
        #    :count => ...
        # }, ...]
        results = Hash.new
        @clients.each do |client|
          counts = client.client.jobs.failed
          counts.each do |key, count|
            if results[key].nil? then
              results[key] = {
                :name => key,
                :clients => [],
                :count => 0
              }
            end

            results[key][:clients].push({
              :name => client.name,
              :path => client.path,
              :count => count
            })
            results[key][:count] += count
          end
        end
        results
      end

      # Are all the clients that have this queue pausing them?
      def paused(queue)
        return true
      end

      # Return the supplied object back as JSON
      def json(obj)
        content_type :json
        obj.to_json
      end

      # Make the id acceptable as an id / att in HTML
      def sanitize_attr(attr)
        return attr.gsub(/[^a-zA-Z\:\_]/, '-')
      end
    end

    get '/?' do
      erb :overview, :layout => true, :locals => { :title => "Overview" }
    end

    post "/pause/?" do
      # Expects JSON blob: {'queue': <queue>}
      r = JSON.parse(request.body.read)
      if r['queue']
        return json({
          'queue' => 'paused',
          'clients' => @clients.map { |c| c.client.queues[r['queue']].pause }
        })
      else
        raise 'No queue provided'
      end
    end

    post "/unpause/?" do
      # Expects JSON blob: {'queue': <queue>}
      r = JSON.parse(request.body.read)
      if r['queue']
        return json({
          'queue' => 'unpaused',
          'clients' => @clients.map { |c| c.client.queues[r['queue']].unpause }
        })
      else
        raise 'No queue provided'
      end
    end

    # start the server if ruby file executed directly
    run! if app_file == $0
  end
end

