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

  class ShardedServer < Sinatra::Base
    # Path-y-ness
    dir = File.dirname(File.expand_path(__FILE__))
    set :views        , "#{dir}/server/views"
    set :public_folder, "#{dir}/server/static"

    # For debugging purposes at least, I want this
    set :reload_templates, true

    # I'm not sure what this option is -- I'll look it up later
    # set :static, true

    def initialize()
      @clients = []
      super
    end

    def add_instance(name, client, path)
      @clients.push(ShardedClient.new(name, client, path))
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
        results = Hash.new
        @clients.each do |client|
          results[client.name] = client.client.queues.counts
          results[client.name]['path'] = client.path
        end
        results
      end

      def workers
        results = Hash.new
        @clients.each do |client|
          results[client.name] = client.client.workers.counts
          results[client.name]['path'] = client.path
        end
        results
      end

      def failed
        results = Hash.new
        @clients.each do |client|
          results[client.name] = client.client.jobs.failed
          results[client.name]['path'] = client.path
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
        @client.queues[r['queue']].pause()
        return json({'queue' => 'paused'})
      else
        raise 'No queue provided'
      end
    end

    post "/unpause/?" do
      # Expects JSON blob: {'queue': <queue>}
      r = JSON.parse(request.body.read)
      if r['queue']
        @client.queues[r['queue']].unpause()
        return json({'queue' => 'unpaused'})
      else
        raise 'No queue provided'
      end
    end

    # start the server if ruby file executed directly
    run! if app_file == $0
  end
end
