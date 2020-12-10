module Speedtest
  class Manager
    SPEEDTEST_SERVER_LIST_URL = "https://c.speedtest.net/speedtest-servers-static.php"
    GLOBAL_SERVER_LIST_PATH = File.expand_path('../../../data/global_servers.yml', __FILE__)

    def initialize
      @logger = Speedtest.logger
    end

    def load_speedtest_server_list(url = SPEEDTEST_SERVER_LIST_URL)
      ll = Speedtest::Loaders::ServerList.new(url, :speedtest)
      ll.download
      ll.parse
    end

    def load_global_server_list(path = GLOBAL_SERVER_LIST_PATH)
      ll = Speedtest::Loaders::ServerList.new(path, :global)
      ll.download
      ll.parse
    end

    def load_single_server(url)
      list = Speedtest::Servers::List.new
      list << Speedtest::Servers::Server.new(url, Speedtest::GeoPoint.new(0,0))
    end

    def sort_and_filter_server_list(list, geopoint, options={})
      options.slice(:keep_num_servers, :min_latency, :skip_fqdns)

      distance_sorted = list.sort_by_distance(geopoint, options[:keep_num_servers])
      latency_sorted = distance_sorted.sort_by_latency

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
        mover = Speedtest::Transfers::Mover.new(server, options)
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
