require 'stringio'
require 'mizuno/client_response'

module Mizuno
  java_import 'org.eclipse.jetty.client.ContentExchange'

  # what do I want to happen on a timeout or error?

  class ClientExchange < ContentExchange
    def initialize(client)
      super(false)
      @client = client
    end

    def setup(url, options = {}, &block)
      @callback = block
      @response = ClientResponse.new(url)
      setURL(url)
      @response.ssl = (getScheme == 'https')
      setMethod((options[:method] || 'GET').upcase)
      (headers = options[:headers]) && headers.each_pair { |k, v|
        setRequestHeader(k, v)
      }
      return unless options[:body]
      body = StringIO.new(options[:body].read)
      setRequestContentSource(body.to_inputstream)
    end

    def on_response_header(name, value)
      @response[name.to_s] = value.to_s
    end

    def on_response_complete
      @client.clear(self)
      @response.status = getResponseStatus
      @response.body = getResponseContent
      run_callback
    end

    def on_expire
      @client.clear(self)
      @response.timeout = true
      @response.status = -1
      @response.body = nil
      run_callback
    end

    def on_exception(error)
      @exception ||= error
    end

    def on_connection_failed(error)
      @exception ||= error
    end

    def run_callback
      @callback.call(@response)
    rescue => error
      onException(error)
    end

    def wait_for_done
      super
      throw(@exception) if @exception
    end
    #
    #        def finished?
    #            #FIXME: Implement.
    #        end
  end
end
