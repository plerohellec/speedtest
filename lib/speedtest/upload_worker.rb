require 'celluloid/current'

module Speedtest
  class UploadWorker
    include Celluloid

    def initialize(url, logger)
      @url = url
      @logger = logger
    end

    def upload(content)
      status = ThreadStatus.new(false, 0)

      page = HTTParty.post(@url, :body => { "content" => content }, timeout: 10)
      @logger.debug "upload response body = [#{page.body}]"
      unless page.code / 100 == 2
        error "GET #{url} failed with code #{page.code}"
        status.error = true
      end
      status.size = page.body.split('=')[1].to_i
      status
    end
  end
end
