#
# A test app that always returns a HTTP OK.
#
class SuccessApp
  def call(_env)
    message = 'OK'
    [200, { 'Content-Type' => 'text/plain',
            'Content-Length' => message.length.to_s }, [message]]
  end
end
