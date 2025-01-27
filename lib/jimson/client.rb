require 'blankslate'
require 'multi_json'
require 'rest-client'
require 'jimson/request'
require 'jimson/response'

module Jimson
  class ClientHelper
    JSON_RPC_VERSION = '2.0'

    def self.make_id
      rand(10 ** 12)
    end

    def initialize(url, opts = {}, namespace = nil, client_opts = {})
      URI.parse(url) # for the sake of validating the url
      @url = url
      @opts = opts
      @opts[:id_type] ||= :int # Possible id types: :int, :string
      @namespace = namespace
      @client_opts = client_opts

      @batch = []
      @headers = opts.slice(* opts.keys - [:id_type])
      @headers[:content_type] ||= 'application/json'
    end

    def process_call(sym, args)
      resp = send_single_request(sym.to_s, args)

      begin
        data = MultiJson.decode(resp)
      rescue
        raise Client::Error::InvalidJSON.new(resp)
      end

      return process_single_response(data)

    rescue Exception, StandardError => e
      e.extend(Client::Error) unless e.is_a?(Client::Error)
      raise e
    end

    def send_single_request(method, args)
      namespaced_method = @namespace.nil? ? method : "#@namespace#{method}"
      post_data = MultiJson.encode({
                                     'jsonrpc' => JSON_RPC_VERSION,
                                     'method' => namespaced_method,
                                     'params' => args,
                                     'id' => format_post_id(self.class.make_id)
                                   })
      resp = RestClient::Request.execute(@client_opts.merge(:method => :post, :url => @url, :payload => post_data, :headers => @headers))
      if resp.nil? || resp.body.nil? || resp.body.empty?
        raise Client::Error::InvalidResponse.new(resp)
      end

      return resp.body
    end

    def send_batch_request(batch)
      post_data = MultiJson.encode(batch)
      resp = RestClient::Request.execute(@client_opts.merge(:method => :post, :url => @url, :payload => post_data, :headers => @headers))
      if resp.nil? || resp.body.nil? || resp.body.empty?
        raise Client::Error::InvalidResponse.new(resp)
      end

      resp.body
    end

    def process_batch_response(responses)
      responses.each do |resp|
        saved_response = @batch.map { |r| r[1] }.select { |r| r.id == resp['id'] }.first
        raise Client::Error::InvalidResponse.new if saved_response.nil?
        saved_response.populate!(resp)
      end
    end

    def process_single_response(data)
      raise Client::Error::InvalidResponse.new(data) if !valid_response?(data)

      if !!data['error']
        code = data['error']['code']
        msg = data['error']['message']
        raise Client::Error::ServerError.new(code, msg)
      end

      data['result']
    end

    def valid_response?(data)
      return false unless data.is_a?(Hash)

      # return false if data['jsonrpc'] != JSON_RPC_VERSION

      return false unless data.has_key?('id')

      unless data['error'].nil?
        return true if data['error'].nil?
        if !data['error'].is_a?(Hash) || !data['error'].has_key?('code') || !data['error'].has_key?('message')
          return false
        end
        if !data['error']['code'].is_a?(Integer) || !data['error']['message'].is_a?(String)
          return false
        end
      end

      true

    rescue
      return false
    end

    def push_batch_request(request)
      request.id = self.class.make_id
      response = Response.new(request.id)
      @batch << [request, response]
      return response
    end

    def send_batch
      batch = @batch.map(&:first) # get the requests
      response = send_batch_request(batch)

      begin
        responses = MultiJson.decode(response)
      rescue
        raise Client::Error::InvalidJSON.new(response)
      end

      process_batch_response(responses)
      @batch = []
    end

    def format_post_id(id)
      if @opts[:id_type] == :string
        id.to_s
      else
        id
      end
    end

  end

  class BatchClient < BlankSlate

    def initialize(helper)
      @helper = helper
    end

    def method_missing(sym, *args, &block)
      args = args.first if args.size == 1 && args.first.is_a?(Hash)
      request = Jimson::Request.new(sym.to_s, args)
      @helper.push_batch_request(request)
    end

  end

  class Client < BlankSlate
    reveal :instance_variable_get
    reveal :inspect
    reveal :to_s

    def self.batch(client)
      helper = client.instance_variable_get(:@helper)
      batch_client = BatchClient.new(helper)
      yield batch_client
      helper.send_batch
    end

    def initialize(url, opts = {}, namespace = nil, client_opts = {})
      @url, @opts, @namespace, @client_opts = url, opts, namespace, client_opts
      @helper = ClientHelper.new(url, opts, namespace, client_opts)
    end

    def method_missing(sym, *args, &block)
      args = args.first if args.size == 1 && args.first.is_a?(Hash)
      @helper.process_call(sym, args)
    end

    def [](method, *args)
      if method.is_a?(Symbol)
        # namespace requested
        new_ns = @namespace.nil? ? "#{method}." : "#@namespace#{method}."
        return Client.new(@url, @opts, new_ns)
      end
      args = args.first if args.size == 1 && args.first.is_a?(Hash)
      @helper.process_call(method, args)
    end

  end
end

require 'jimson/client/error'
