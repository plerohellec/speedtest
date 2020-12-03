require 'logger'
require 'curl'

require_relative 'speedtest/geo_point'
require_relative 'speedtest/logging'
require_relative 'speedtest/curl_transfer_worker'
require_relative 'speedtest/ring'
require_relative 'speedtest/servers'
require_relative 'speedtest/transfers'

module Speedtest
  ThreadStatus = Struct.new(:error, :size)
end

