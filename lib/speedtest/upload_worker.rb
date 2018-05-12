require 'celluloid/current'

module Speedtest
  class UploadWorker
    include Celluloid

    def initialize(url)
      @url = url
    end

    def upload(content)
      d = Random.rand(5000)
      sleep(d/1000)
      d
    end

  end
end

pool = UploadWorker.pool(size: 2, args: ["https://www.vpsbenchmarks.com"])
futures =  1.upto(20).map do |i|
  pool.future.upload("abc")
end
futures.each do |f|
  puts f.value
end
