module Speedtest
  module Logging
    def log(msg)
      @logger.debug msg if @logger
    end

    def error(msg)
      @logger.error msg if @logger
    end
  end
end
