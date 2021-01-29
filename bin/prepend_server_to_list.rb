#!/usr/bin/env ruby

require 'amazing_print'
require_relative '../lib/speedtest'

logger = Logger.new(STDOUT)
Speedtest.init_logger(logger)

manager = Speedtest::Manager.new

logger.info "Loading servers lists"
servers_dynamic = manager.load_dynamic_server_list
servers_global = manager.load_global_server_list

server = servers_global.first
ap server
puts
list = manager.prepend_with_server!(servers_dynamic, server)
duplicate = servers_dynamic.first.clone
list = manager.prepend_with_server!(servers_dynamic, duplicate)

ap list.map(&:url)


