#!/usr/bin/env ruby

require 'amazing_print'
require 'debug'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG
Speedtest.init_logger(logger)

# manager = Speedtest::Manager.new
# servers_global = manager.load_global_server_list

servers_list = Speedtest::Loaders::ServerList.new(File.expand_path('../../data/best_vpsb_servers.yml', __FILE__), :global)
servers_list.download
servers_global = servers_list.parse
ap servers_global

pl = PingLocator.new(servers_global)
ap pl.locate
