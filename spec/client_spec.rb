require 'thread'
require 'spec_helper'
require 'mizuno/client'

describe Mizuno::Client do
  pending "times out when the server doesn't respond" do
    called = false
    client = Mizuno::Client.new(timeout: 1)
    client.request('http://127.0.0.1:9293/') do |response|
      response.should be_timeout
      called = true
    end
    client.stop
    expect(called).to be true
  end

  pending 'makes http requests to google' do
    called = false
    client = Mizuno::Client.new(timeout: 30)
    client.request('http://google.com/') do |response|
      response.should_not be_timeout
      response.should_not be_ssl
      response.should be_success
      called = true
    end
    client.stop
    expect(called).to be true
  end

  pending 'makes multiple requests' do
    queue = Queue.new
    client = Mizuno::Client.new(timeout: 30)
    client.request('http://google.com/') do |response|
      response.should be_success
      queue.push(true)
    end
    client.request('http://yahoo.com/') do |response|
      response.should be_success
      queue.push(true)
    end
    client.stop
    expect(queue.size).to eq 2
  end

  #
  # https://developer.salesforce.com/page/JavaClientExample.java
  # http://wiki.eclipse.org/Jetty/Tutorial/HttpClient#SSL_Connections
  #
  pending 'makes https requests to google' do
    called = false
    client = Mizuno::Client.new(timeout: 30)
    client.request('https://google.com/') do |response|
      response.should_not be_timeout
      response.should be_ssl
      response.should be_success
      called = true
    end
    client.stop
    expect(called).to be true
  end

  pending 'has a root exchange' do
    called = false
    Mizuno::Client.request('http://google.com/') do |response|
      called = true
      response.should be_success
    end
    Mizuno::Client.stop
    expect(called).to be true
  end
end
