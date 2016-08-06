require 'net/http'
require 'openssl'

require 'support/test_app'

describe Mizuno::Server do
  include HttpRequests

  describe 'http' do
    before(:all) do
      start_server(TestApp.new, host: '127.0.0.1', port: 9201,
                                embedded: true, threads: 10)
    end

    after(:all) do
      stop_server
    end

    it '200 OK' do
      response = get('/ping')
      expect(response.code).to eq '200'
      expect(response.body).to eq 'OK'
    end

    it '403 FORBIDDEN' do
      response = get('/error/403')
      expect(response.code).to eq '403'
    end

    it '404 NOT FOUND' do
      response = get('/jimmy/hoffa')
      expect(response.code).to eq '404'
    end

    it 'rack headers' do
      response = get('/echo')
      expect(response.code).to eq '200'

      content = JSON.parse(response.body)
      expect(content['rack.version']).to eq [1, 3]
      expect(content['rack.multithread']).to be true
      expect(content['rack.multiprocess']).to be false
      expect(content['rack.run_once']).to be false
    end

    it 'form variables via GET' do
      response = get('/echo?answer=42')
      expect(response.code).to eq '200'

      content = JSON.parse(response.body)
      expect(content['request.params']['answer']).to eq '42'
    end

    it 'form variables via POST' do
      question = 'What is the answer to life?'
      response = post('/echo', 'question' => question)
      expect(response.code).to eq '200'

      content = JSON.parse(response.body)
      expect(content['request.params']['question']).to eq question
    end

    it 'custom headers' do
      response = get('/echo', 'X-My-Header' => 'Pancakes')
      expect(response.code).to eq '200'

      content = JSON.parse(response.body)
      expect(content['HTTP_X_MY_HEADER']).to eq 'Pancakes'
    end

    it 'rack.java.servlet' do
      response = get('/echo', 'answer' => '42')
      expect(response.code).to eq '200'

      content = JSON.parse(response.body)
      expect(content['rack.java.servlet']).to be true
    end

    it 'hides server version' do
      response = get('/ping')
      expect(response['server']).to be_nil
    end

    it 'server port and hostname' do
      response = get('/echo')
      content = JSON.parse(response.body)
      expect(content['SERVER_PORT']).to eq '9201'
      expect(content['SERVER_NAME']).to eq '127.0.0.1'
    end

    it 'uri scheme' do
      response = get('/echo')
      content = JSON.parse(response.body)
      expect(content['rack.url_scheme']).to eq 'http'
    end

    it 'file downloads' do
      response = get('/download')
      expect(response.code).to eq '200'
      expect(response['Content-Type']).to eq 'image/png'
      expect(response['Content-Disposition']).to eq \
        'attachment; filename=reddit-icon.png'

      checksum = Digest::MD5.hexdigest(response.body)
      expect(checksum).to eq '8da4b60a9bbe205d4d3699985470627e'
    end

    it 'file uploads' do
      boundary = '349832898984244898448024464570528145'
      content = []
      content << "--#{boundary}"
      content << 'Content-Disposition: form-data; name="file"; ' \
          + 'filename="reddit-icon.png"'
      content << 'Content-Type: image/png'
      content << 'Content-Transfer-Encoding: base64'
      content << ''
      content << Base64.encode64( \
        File.read('spec/data/reddit-icon.png')
      ).strip
      content << "--#{boundary}--"
      body = content.map { |l| l + "\r\n" }.join('')
      headers = { 'Content-Type' => \
          "multipart/form-data; boundary=#{boundary}" }
      response = post('/upload', nil, headers, body)

      expect(response.code).to eq '200'
      expect(response.body).to eq '8da4b60a9bbe205d4d3699985470627e'
    end

    # This fails me on Jetty 9 & JRuby 9k.
    xit 'async requests' do
      lock = Mutex.new
      buffer = []

      clients = Array.new(20) do |index|
        Thread.new do
          Net::HTTP.start(@options[:host], @options[:port]) do |http|
            http.read_timeout = 1
            http.get('/pull') do |chunk|
              break(http.finish) if chunk == 'eof'
              lock.synchronize { buffer << "#{index}: #{chunk}" }
            end
          end
        end
      end

      lock.synchronize { expect(buffer).to be_empty }
      post('/push', 'message' => 'one') && sleep(0.2)
      lock.synchronize { expect(buffer.count).to eq 20 }

      post('/push', 'message' => 'two') && sleep(0.2)
      lock.synchronize { expect(buffer.count).to eq 40 }

      post('/push', 'message' => 'three') && sleep(0.2)
      lock.synchronize { expect(buffer.count).to eq 60 }

      post('/push', 'message' => 'eof') && sleep(0.5)
      clients.each(&:join)
    end

    it 'streaming response' do
      timings = []
      chunks = []

      Net::HTTP.start(@options[:host], @options[:port]) do |http|
        http.get('/stream') do |chunk|
          timings << Time.now
          chunks << chunk
        end
      end

      expect(chunks).to eq %w(one two)
      expect(timings.last - timings.first).to be_within(0.01).of(0.1)
    end

    it "doesn't double-chunk content" do
      response = get('/chunked')
      expect(response).to be_chunked
      expect(response.body).to eq 'chunked'
    end

    it "doesn't double-chunk rails-like content" do
      response = get('/rails_like_chunked')
      expect(response).to be_chunked
      expect(response.body).to eq 'chunked'
    end

    it 'sets multiple cookies correctly' do
      response = get('/cookied')
      expect(response['set-cookie']).to eq 'first=one+fish, second=two+fish'
    end
  end

  # FIXME: https is broken in Jetty 9. Quite easily fixable, we just haven't gotten around to doing it yet.
  xit 'https' do
    start_server(TestApp.new, host: '127.0.0.1', port: 9201,
                              ssl_port: 9202, keystore: 'spec/support/localhost.keystore',
                              keystore_password: 'password',
                              embedded: true, threads: 10)
    uri = URI.parse('https://localhost:9202/ping')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.get(uri.request_uri)

    expect(response).to be_a Net::HTTPOK
    expect(response.body).to eq 'OK'
    stop_server
  end
end
