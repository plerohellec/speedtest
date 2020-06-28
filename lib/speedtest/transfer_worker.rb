require 'celluloid/current'
require 'curl'

module Speedtest
  class TransferWorker
    include Celluloid
    include Logging

    def initialize(url, logger)
      @url = url
      @logger = logger
    end

    def download
      # log "  downloading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = HTTParty.get(@url, timeout: 10)
        unless page.code / 100 == 2
          error "GET #{@url} failed with code #{page.code}"
          status.error = true
        end
        status.size = page.body.length
      rescue Timeout::Error, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "GET #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end

    def upload(content)
      # log "  uploading: #{@url}"
      status = ThreadStatus.new(false, 0)

      begin
        page = Curl::Easy.new("#{@url}?x=#{(Time.now.to_f * 1000).round}") do |c|
          c.timeout = 15
          c.connect_timeout = 1
          c.headers['User-Agent'] = 'Mozilla/5.0 (Linux-5.4.0-29-generic-x86_64-with-glibc2.29; U; 64bit; en-us) Python/3.8.2 (KHTML, like Gecko) speedtest-cli/2.1.2'
          c.headers['Cache-Control'] = 'no-cache'
          c.headers['Connection'] = 'close'
          c.headers['Accept-Encoding'] = 'identity'
          c.headers['Expect'] = nil
          #c.set(Curl::CURLOPT_BUFFERSIZE, 1_000_000)
          #c.set(Curl::CURLOPT_UPLOAD_BUFFERSIZE, 10_000)
        end
        page.http_post(Curl::PostField.content('content1', content))

        unless page.response_code / 100 == 2
          error "POST #{@url} failed with code #{page.response_code}"
          status.error = true
        end
        status.size = page.body_str.split('=')[1].to_i
      rescue Curl::Err::TimeoutError, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "POST #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end

    def upload_net_http(content)
      log "  uploading (Net::Http): #{@url} size: #{content.size}"
      status = ThreadStatus.new(false, 0)

      begin
        uri = URI(@url)
        page = Net::HTTP.post_form(uri, 'content1' => content)
        unless page.code.to_i / 100 == 2
          error "POST #{@url} failed with code #{page.code}"
          status.error = true
        end
        status.size = page.body.split('=')[1].to_i
        log "upload complete size=#{status.size}"
      rescue Timeout::Error, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "POST #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end

    def upload_http_party(content)
      log "  uploading: #{@url} size: #{content.size}"
      status = ThreadStatus.new(false, 0)

      begin
        page = HTTParty.post(@url, :body => { "content1" => content }, timeout: 10)
        unless page.code / 100 == 2
          error "POST #{@url} failed with code #{page.code}"
          status.error = true
        end
        status.size = page.body.split('=')[1].to_i
        log "upload complete size=#{status.size}"
      rescue Timeout::Error, Net::HTTPNotFound, Net::OpenTimeout, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EPIPE => e
        error "POST #{@url} failed with exception #{e.class}"
        status.error = true
      end
      status
    end
  end
end
