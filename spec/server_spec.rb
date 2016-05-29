require 'support/test_app'
require 'net/http'

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
      response.code.should eq '200'
      response.body.should eq 'OK'
    end

    it '403 FORBIDDEN' do
      response = get('/error/403')
      response.code.should eq '403'
    end

    it '404 NOT FOUND' do
      response = get('/jimmy/hoffa')
      response.code.should eq '404'
    end

    it 'rack headers' do
      response = get('/echo')
      response.code.should eq '200'
      content = JSON.parse(response.body)
      content['rack.version'].should eq [1, 2]
      content['rack.multithread'].should be_true
      content['rack.multiprocess'].should be_false
      content['rack.run_once'].should be_false
    end

    it 'form variables via GET' do
      response = get('/echo?answer=42')
      response.code.should eq '200'
      content = JSON.parse(response.body)
      content['request.params']['answer'].should eq '42'
    end

    it 'form variables via POST' do
      question = 'What is the answer to life?'
      response = post('/echo', 'question' => question)
      response.code.should eq '200'
      content = JSON.parse(response.body)
      content['request.params']['question'].should eq question
    end

    it 'custom headers' do
      response = get('/echo', 'X-My-Header' => 'Pancakes')
      response.code.should eq '200'
      content = JSON.parse(response.body)
      content['HTTP_X_MY_HEADER'].should eq 'Pancakes'
    end

    it 'rack.java.servlet' do
      response = get('/echo', 'answer' => '42')
      response.code.should eq '200'
      content = JSON.parse(response.body)
      content['rack.java.servlet'].should be_true
    end

    it 'hides server version' do
      response = get('/ping')
      response['server'].should be_nil
    end

    it 'server port and hostname' do
      response = get('/echo')
      content = JSON.parse(response.body)
      content['SERVER_PORT'].should eq '9201'
      content['SERVER_NAME'].should eq '127.0.0.1'
    end

    it 'uri scheme' do
      response = get('/echo')
      content = JSON.parse(response.body)
      content['rack.url_scheme'].should eq 'http'
    end

    it 'file downloads' do
      response = get('/download')
      response.code.should eq '200'
      response['Content-Type'].should eq 'image/png'
      response['Content-Disposition'].should eq \
        'attachment; filename=reddit-icon.png'
      checksum = Digest::MD5.hexdigest(response.body)
      checksum.should == '8da4b60a9bbe205d4d3699985470627e'
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
      response.code.should eq '200'
      response.body.should eq '8da4b60a9bbe205d4d3699985470627e'
    end

    it 'async requests' do
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

      lock.synchronize { buffer.should be_empty }
      post('/push', 'message' => 'one') && sleep(0.2)
      lock.synchronize { buffer.count.should eq 20 }

      post('/push', 'message' => 'two') && sleep(0.2)
      lock.synchronize { buffer.count.should eq 40 }

      post('/push', 'message' => 'three') && sleep(0.2)
      lock.synchronize { buffer.count.should eq 60 }

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

      chunks.should eq %w(one two)
      (timings.last - timings.first).should be_within(0.01).of(0.1)
    end

    it "doesn't double-chunk content" do
      response = get('/chunked')
      response.should be_chunked
      response.body.should eq 'chunked'
    end

    it "doesn't double-chunk rails-like content" do
      response = get('/rails_like_chunked')
      response.should be_chunked
      response.body.should eq 'chunked'
    end

    it 'sets multiple cookies correctly' do
      response = get('/cookied')
      response['set-cookie'].should eq 'first=one+fish, second=two+fish'
    end
  end

  it 'https' do
    start_server(TestApp.new, host: '127.0.0.1', port: 9201,
                              ssl_port: 9202, keystore: 'spec/support/localhost.keystore',
                              keystore_password: 'password',
                              embedded: true, threads: 10)
    uri = URI.parse('https://localhost:9202/ping')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.get(uri.request_uri)
    response.should be_a(Net::HTTPOK)
    response.body.should eq 'OK'
    stop_server
  end
end
