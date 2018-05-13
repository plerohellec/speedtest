require 'celluloid/current'

module Speedtest
  class TransferWorker
    include Celluloid

    def initialize(url, logger)
      @url = url
      @logger = logger
    end

    def log(msg)
      return unless @logger
      @logger.debug msg
    end

    def download
      log "  downloading: #{@url}"
      status = ThreadStatus.new(false, 0)

      page = HTTParty.get(@url, timeout: 10)
      unless page.code / 100 == 2
        error "GET #{@url} failed with code #{page.code}"
        status.error = true
      end
      status.size = page.body.length
      status
    end

    def upload(content)
      log "  uploading: #{@url}"
      status = ThreadStatus.new(false, 0)

      page = HTTParty.post(@url, :body => { "content" => content }, timeout: 10)
      log "upload response body = [#{page.body}]"
      unless page.code / 100 == 2
        error "GET #{@url} failed with code #{page.code}"
        status.error = true
      end
      status.size = page.body.split('=')[1].to_i
      status
    end
  end
end
