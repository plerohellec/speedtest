#!/usr/bin/env ruby

require 'amazing_print'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG
Speedtest.init_logger(logger)

manager = Speedtest::Manager.new
servers_global = manager.load_global_server_list

pl = PingLocator.new(servers_global)
ap pl.locate
