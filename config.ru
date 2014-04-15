require 'bundler/setup'
Bundler.require :default
require 'sinatra'

class FaxFinderOverrideApp < Sinatra::Base

  def self.match(*args, &block)
    [:get, :put, :post, :patch, :delete, :options].each do |verb|
      send(verb, *args, &block)
    end
  end

  get '/images/top.jpg' do
    send_file 'assets/logo.png'
  end

  get '/images/FF130_230.gif' do
    send_file 'assets/entry.png'
  end

  get '/css/stylesheet.css' do
    send_file 'assets/stylesheet.css'
  end

  match /(.*)/ do |path|
    proxy_request path
  end

  private

  def proxy_request(path, request_method = request_method)
    response = client.send(request_method) do |request|
      request.path    = path
      request.params  = params
      request.body    = request.body.read if request.body.present?
      request.headers = request_headers
    end
    status response.status
    headers normalize_location(response.headers)
    body response.body
  end

  def request_headers
    raw_headers = request.env.select do |key, value|
      key =~ /^HTTP_/i
    end
    headers     = raw_headers.reduce({}) do |hash, (key, value)|
      hash.merge key.sub(/^HTTP_/, '').downcase.camelize => value
    end
    Rack::Utils::HeaderHash.new headers
  end

  def normalize_location(headers)
    headers.tap do |hash|
      if hash['location']
        uri              = URI.parse(hash['location'])
        uri.scheme       = request.scheme
        hash['location'] = uri.to_s
      end
    end
  end

  def request_method
    request.request_method.downcase.to_sym
  end

  def client
    Faraday.new(ENV['FAX_FINDER_BACKEND'], ssl: { verify: false })
  end

end

run FaxFinderOverrideApp
