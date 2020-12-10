require 'logger'
require 'curl'
require 'yaml'
require 'json'

require_relative 'speedtest/geo_point'
require_relative 'speedtest/curl_transfer_worker'
require_relative 'speedtest/ring'
require_relative 'speedtest/loaders'
require_relative 'speedtest/manager'
require_relative 'speedtest/servers'
require_relative 'speedtest/transfers'

module Speedtest
  ThreadStatus = Struct.new(:error, :size)

  def self.init_logger(logger)
    @logger = logger
  end

  def self.logger
    raise "You must set the logger instance first." unless @logger
    @logger
  end
end

