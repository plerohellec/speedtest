module Speedtest
  class Manager
    def initialize(logger)
      @logger = logger
    end

    def load_speedtest_server_list
      ll = Speedtest::Loaders::ServerList.new("https://c.speedtest.net/speedtest-servers-static.php", @logger, :speedtest)
      ll.download
      ll.parse
    end

    def load_global_server_list
      ll = Speedtest::Loaders::ServerList.new("https://vpsbenchmarks.s3.amazonaws.com/misc/global_servers.yml", @logger, :global)
      ll.download
      ll.parse
    end

    def sort_and_filter_server_list(list, geopoint, options={})
      options.slice(:keep_num_servers, :min_latency, :skip_fqdns)

      distance_sorted = list.sort_by_distance(geopoint, options[:keep_num_servers])
      latency_sorted = distance_sorted.sort_by_latency
      #latency_sorted.each { |s| @logger.debug [ s.url, s.geopoint, s.latency ].ai }

      latency_sorted.filter(options)
    end

    def merge_server_lists(list1, list2)
      merged = list1.merge(list2)
      merged.uniq! { |server| server.url }
      merged.sort_by_latency
    end

    def run_each_transfer(list, num_transfers, options={}, &block)
      list.each do |server|
        @logger.info "Starting transfers for #{server.url}"
        mover = Speedtest::Transfers::Mover.new(server, @logger, options)
        unless mover.validate_server_transfer
          @logger.warn "Rejecting #{server.fqdn}"
          next
        end

        transfer = mover.run
        if transfer.failed?
          @logger.warn "Transfer for #{server.fqdn} failed: dl=#{transfer.download_size_bytes} ul=#{transfer.upload_size_bytes}"
          next
        end

        yield transfer

        num_transfers -= 1
        break if num_transfers == 0
      end
    end

    def run_transfers(list, num_transfers, options={})
      transfers = []
      run_each_transfer(list, num_transfers, options) do |transfer|
        transfers << transfer
      end
      transfers
    end
  end
end
