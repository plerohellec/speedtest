module Speedtest
  class Manager
    SPEEDTEST_SERVER_LIST_URL = "https://c.speedtest.net/speedtest-servers-static.php"
    GLOBAL_SERVER_LIST_PATH = File.expand_path('../../../data/global_servers.yml', __FILE__)
    DYNAMIC_SERVER_LIST_URL = "https://www.speedtest.net/api/js/servers?engine=js&https_functional=1"

    def initialize
      @logger = Speedtest.logger
      @error_servers = []
    end

    def load_server_list(list_name, data=nil)
      list = list_name.to_sym
      ll = case list
        when :speedtest
          Speedtest::Loaders::ServerList.new(SPEEDTEST_SERVER_LIST_URL, list)
        when :global
          Speedtest::Loaders::ServerList.new(GLOBAL_SERVER_LIST_PATH, list)
        when :dynamic
          Speedtest::Loaders::ServerList.new(DYNAMIC_SERVER_LIST_URL, list)
        when :vpsb
          Speedtest::Loaders::ServerList.new(data, list)
        end
      ll.download
      ll.parse
    end

    def load_speedtest_server_list
      load_server_list(:speedtest)
    end

    def load_global_server_list
      load_server_list(:global)
    end

    def load_dynamic_server_list
      load_server_list(:dynamic)
    end

    def load_vpsb_server_list(data)
      load_server_list(:vpsb, data)
    end

    def load_single_server(url)
      list = Speedtest::Servers::List.new
      list << Speedtest::Servers::Server.new(url)
    end

    def sort_and_filter_server_list(list, geopoint, options={})
      options.slice(:keep_num_servers, :min_latency, :skip_fqdns)

      distance_sorted = list.sort_by_distance(geopoint, options[:keep_num_servers])
      latency_sorted = distance_sorted.sort_by_latency

      latency_sorted.filter(options)
    end

    def merge_server_lists(list1, list2, sort_by: :latency)
      merged = list1.merge(list2)
      case sort_by
      when :graded_latency
        merged.sort_by_graded_latency
      when :latency
        merged.sort_by_latency
      else
        raise "Invalid sort_by: #{sort_by}"
      end
    end

    def prepend_with_server!(list, server, size=4)
      return list unless server
      return list if list[0..size].include?(server)

      list.delete(server)
      list.prepend(server)
      list
    end

    def run_each_transfer(list, num_transfers, options={}, &block)
      list.each do |server|
        @logger.info "Starting transfers for #{server.url}"
        mover = Speedtest::Transfers::Mover.new(server, options)
        unless mover.validate_server_transfer
          @logger.warn "Rejecting #{server.fqdn}"
          @error_servers << server
          next
        end

        if options[:min_latency]
          if ((ml = server.calc_min_latency) < options[:min_latency])
            @logger.warn "Skipping #{server.fqdn} because of runtime min_latency: #{ml}"
            next
          end
        end

        transfer = mover.run
        if transfer.failed?
          @logger.warn "Transfer for #{server.fqdn} failed: dl=#{transfer.download_size_bytes} ul=#{transfer.upload_size_bytes}"
          @error_servers << server
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

    def error_servers
      @error_servers.map(&:fqdn)
    end
  end
end
