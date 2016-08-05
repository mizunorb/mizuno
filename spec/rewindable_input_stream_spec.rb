require 'java'
require 'lib/java/rewindable-input-stream.jar'
require 'support/test_app'

java_import org.jruby.rack.servlet.RewindableInputStream

describe RewindableInputStream do
  include HttpRequests

  before(:all) do
    start_server(TestApp.new, host: '127.0.0.1', port: 9201,
                              embedded: true, rewindable: true)
  end

  after(:all) do
    stop_server
  end

  it 'should read data byte by byte' do
    input = 49.times.to_a
    stream = rewindable_input_stream(input.to_java(:byte), 6, 24)
    49.times { |i| expect(stream.read).to eq i }
    3.times { expect(stream.read).to eq(-1) }
  end

  it 'should read data then rewind and read again (in memory)' do
    @stream = it_should_read_127_bytes(32, 256)
    @stream.rewind
    it_should_read_127_bytes
  end

  it 'should read data then rewind and read again (temp file)' do
    @stream = it_should_read_127_bytes(16, 64)
    @stream.rewind
    it_should_read_127_bytes
  end

  context 'for an input array of byte values 0 to 99' do
    let(:input) { (0..99).to_a }

    it 'should read incomplete data rewind and read until end' do
      stream = rewindable_input_stream(input.to_java(:byte), 10, 50)
      data = new_byte_array(110)

      expect(stream.read(data, 0, 5)).to eq 5
      5.times { |i| expect(data[i]).to eq i }

      stream.rewind
      expect(stream.read(data, 5, 88)).to eq 88
      88.times { |i| expect(data[i + 5]).to eq i }
      expect(stream.read).to eq 88
      expect(stream.read).to eq 89

      stream.rewind
      expect(stream.read(data, 10, 33)).to eq 33
      33.times { |i| expect(data[i + 10]).to eq i }

      stream.rewind
      expect(stream.read(data, 0, 101)).to eq 100
      100.times { |i| expect(data[i]).to eq i }
      expect(stream.read).to eq(-1)
    end

    it 'should rewind unread data' do
      stream = rewindable_input_stream(input.to_java(:byte), 10, 50)
      stream.rewind

      data = new_byte_array(120)
      expect(stream.read(data, 10, 110)).to eq 100

      100.times do |i|
        expect(data[i + 10]).to eq i
      end
    end

    it 'should mark and reset' do
      stream = rewindable_input_stream(input.to_java(:byte), 5, 20)

      15.times { stream.read }
      expect(stream.mark_supported).to eq true
      stream.mark(50)

      35.times { |i| expect(stream.read).to eq 15 + i }

      stream.reset

      50.times { |i| expect(stream.read).to eq 15 + i }
      35.times { |i| expect(stream.read).to eq 65 + i }

      expect(stream.read).to eq(-1)
    end
  end

  it 'should read data then rewind and read again (server)' do
    body = 'Mizuno is a set of Jetty-powered running shoes for JRuby/Rack.'
    response = post('/repeat_body', nil, {}, body)
    expect(response.code).to eq '200'
    expect(response.body).to eq body * 2
  end

  def rewindable_input_stream(input, buffer_size = nil, max_buffer_size = nil)
    input = to_input_stream(input) unless input.is_a?(java.io.InputStream)
    buffer_size ||= RewindableInputStream::INI_BUFFER_SIZE
    max_buffer_size ||= RewindableInputStream::MAX_BUFFER_SIZE
    RewindableInputStream.new(input, buffer_size, max_buffer_size)
  end

  def to_input_stream(content = @content)
    bytes = content.respond_to?(:to_java_bytes) ? content.to_java_bytes : content
    java.io.ByteArrayInputStream.new(bytes)
  end

  def new_byte_array(length)
    java.lang.reflect.Array.newInstance(java.lang.Byte::TYPE, length)
  end

  def it_should_read_127_bytes(init_size = nil, max_size = nil)
    input = 127.times.to_a
    stream = @stream || rewindable_input_stream(input.to_java(:byte), init_size, max_size)

    # read 7 bytes
    data = new_byte_array(7)
    expect(stream.read(data, 0, 7)).to eq 7
    7.times { |i| expect(data[i]).to eq i }

    # read 20 bytes
    data = new_byte_array(42)
    expect(stream.read(data, 10, 20)).to eq 20
    10.times { |i| expect(data[i]).to eq 0 }
    20.times { |i| expect(data[i + 10]).to eq i + 7 }
    10.times { |i| expect(data[i + 30]).to eq 0 }

    # read 100 bytes
    data = new_byte_array(200)
    expect(stream.read(data, 0, 200)).to eq 100
    100.times { |i| expect(data[i]).to eq i + 20 + 7 }
    100.times { |i| expect(data[i + 100]).to eq 0 }

    stream
  end
end
