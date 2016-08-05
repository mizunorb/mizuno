require 'mizuno/client_response'

module Mizuno
  java_import 'org.eclipse.jetty.client.util.FutureResponseListener'
  java_import 'org.eclipse.jetty.client.HttpContentResponse'

  class ClientResponseListener < FutureResponseListener
    def initialize(request, &block)
      super(request)

      @callback = block
    end

    def onComplete(result) # rubocop:disable MethodName
      super

      req = result.request
      resp = result.response

      response = ClientResponse.new(req.URI)
      response.ssl = (req.scheme == 'https')
      response.status = resp.status
      response.body = content

      @callback.call(response)
    end
  end
end
