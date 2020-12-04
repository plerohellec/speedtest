module Speedtest
  class Manager
    def initialize(logger)
      @logger = logger
    end

    def load_speedtest_server_list
      ll = Speedtest::Loaders::ServerList.new("https://c.speedtest.net/speedtest-servers-static.php", @logger)
      ll.download
      ll.parse
    end

    def load_global_server_list
    end

    def sort_and_filter_server_list(list, geopoint, options={})
      options.slice(:keep_num_servers, :min_latency, :skip_fqdns)

      distance_sorted = list.sort_by_distance(geopoint, options[:keep_num_servers])
      # distance_sorted.each { |s| @logger.debug [ s.url, s.geopoint ].ai }
      latency_sorted = distance_sorted.sort_by_latency
      latency_sorted.each { |s| @logger.debug [ s.url, s.geopoint, s.latency ].ai }

      latency_sorted.filter(options)
    end

    def merge_server_lists(list1, list2)
      merged = list1.merge(list2)
      merged.sort_by_latency
    end

    def run_transfers(list, num_transfers)
      transfers = []
      list.each do |server|
        @logger.info "Starting transfers for #{server.fqdn}"
        mover = Speedtest::Transfers::Mover.new(server, @logger, num_threads: 1, download_size: 2000, upload_size: 524288)
        unless mover.validate_server_transfer
          @logger.warn "Rejecting #{server.fqdn}"
          next
        end

        transfer = mover.run
        if transfer.failed?
          @logger.warn "Transfer for #{server.fqdn} failed: dl=#{transfer.download_size} ul=#{transfer.upload_size}"
          next
        end

        transfers << transfer

        num_transfers -= 1
        break if num_transfers == 0
      end
      transfers
    end

    def speedtest_geopoint
      config = Speedtest::Loaders::Config.new
      config.load
      geo = config.ip_geopoint
      @logger.info "geo=#{geo.inspect}"
      geo
    end

  end
end
