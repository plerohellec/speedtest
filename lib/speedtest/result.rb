module Speedtest
  class Result
    attr_accessor :server, :latency, :download_size, :upload_size, :download_time, :upload_time, :server_list

    def initialize(values = {})
      @server = values[:server]
      @latency = values[:latency]
      @download_size = values[:download_size]
      @upload_size = values[:upload_size]
      @download_time = values[:download_time]
      @upload_time = values[:upload_time]
      @server_list = values[:server_list]
    end
  end
end
