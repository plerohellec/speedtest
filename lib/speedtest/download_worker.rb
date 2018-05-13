require 'celluloid/current'

module Speedtest

  class DownloadWorker
    include Celluloid

    def initialize(url, logger)
      @logger = logger
      @url = url
    end

    def download
      @logger.debug "  downloading: #{@url}"
      status = ThreadStatus.new(false, 0)

      page = HTTParty.get(@url, timeout: 10)
      unless page.code / 100 == 2
        error "GET #{url} failed with code #{page.code}"
        status.error = true
      end
      status.size = page.body.length
      status
    end
  end
end
