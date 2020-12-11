# Speedtest
A ruby gem for speedtest.net results

Adapted from https://github.com/lacostej/speedtest.rb

## Installation
```ruby
$ gem install speedtest
```
or put it in your Gemfile
```ruby
gem 'speedtest'
```
and install with
```ruby
$ bundle install
```

## Usage:
Require it in your script:
```ruby
require 'speedtest'
```
### Single Server Transfer test
Initialize server
```ruby
server = Speedtest::Server.new('http://speedgauge2.optonline.net:8080')
```

Run the transfers (downlod + upload) and print results
```ruby
require 'amazing_print'

logger = Logger.new(STDOUT)
Speedtest.init_logger(logger)

options = { num_threads: 2, download_size: 500, upload_size: 524288 }
mover = Speedtest::Transfers::Mover.new(server, options)
transfer = mover.run
ap transfer
```

### Find fastest server in list
```ruby
require 'amazing_print'

logger = Logger.new(STDOUT)
Speedtest.init_logger(logger)

url = "https://c.speedtest.net/speedtest-servers-static.php"
loader = Speedtest::Loaders::ServerList.new(url, :speedtest)
loader.download
server_list = loader.parse

# Find your latitude/longitude from Speedtest/Maxmind
maxmind_geopoint = Speedtest::GeoPoint.speedtest_geopoint

# Sort by distance to your location and only keep the 10 closest (fast)
distance_sorted = list.sort_by_distance(geopoint, 10)

# Ping each server in list and generate new list sorted by ping latency (slow)
latency_sorted = distance_sorted.sort_by_latency

options = { min_latency: 7, skip_fqdns: [ 'bad.speedtest.server' ] }
filtered_list = latency_sorted.filter(options)

# Run transfers for the 2 servers with minimum latency in list
options = { download_size: 500, upload_size: 1_000_000, num_threads: 5, min_transfer_secs }
filtered_list.each do |server|
  mover = Speedtest::Transfers::Mover.new(server, options)
  transfer = mover.run
  ap transfer
end
```

### Use the Manager to sort, filter servers and run the trasnfers
```ruby
require 'amazing_print'

Speedtest.init_logger(Logger.new(STDOUT))

# Load list of servers from Speedtest
manager = Speedtest::Manager.new
servers = manager.load_speedtest_server_list

# Sort by distance, keep 20 servers and sort by latency
maxmind_geopoint = Speedtest::GeoPoint.speedtest_geopoint
filtered_servers = manager.sort_and_filter_server_list(servers, maxmind_geopoint, keep_num_servers: 20)

# Run the transfers using 2 threads for the 2 servers with the lowest latency
manager.run_each_transfer(servers, 2, num_threads: 2, download_size: 500, upload_size: 524288) do |transfer|
  ap transfer
end
```

## Interesting links
* https://github.com/lacostej/speedtest.rb
* http://www.phuket-data-wizards.com/blog/2011/09/17/speedtest-vs-dslreports-analysis/
* https://github.com/fopina/pyspeedtest
* http://tech.ivkin.net/wiki/Run_Speedtest_from_command_line
