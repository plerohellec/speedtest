require 'net/ping'

class PingLocator
  SPEED_OF_LIGHT = 299_792_458 # meters per second
  PING_COUNT = 3
  EARTH_RADIUS = 6_371_000 # meters

  def initialize(servers)
    @servers = servers
    @logger = Speedtest.logger
  end

  def locate
    ping_results = measure_ping_distances
    @logger.debug ping_results.ai
    return nil if ping_results.size < 3

    # Select 3 servers that are geometrically diverse for better trilateration
    selected_servers = select_diverse_servers(ping_results)
    if selected_servers.size < 3
      @logger.warn "Not enough diverse servers for trilateration"
      return nil
    end

    trilaterate(selected_servers)
  end

  private

  def measure_ping_distances
    results = []

    @servers.take(20).each do |server|
      rtt = ping_server(server)
      next unless rtt

      # Convert RTT to estimated distance (divide by 2 for round trip)
      # RTT is in milliseconds, convert to seconds, then to distance
      distance = (rtt / 2000.0) * SPEED_OF_LIGHT

      results << {
        server: server,
        distance: distance,
        rtt: rtt
      }
    end

    # Sort by RTT (lowest first)
    results.sort_by { |result| result[:rtt] }
  end

  def ping_server(server)
    @logger.info "Pinging #{server.fqdn}..."
    begin
      ping = Net::Ping::External.new(server.fqdn)
      rtt = ping.ping? ? ping.duration * 1000 : nil # Convert to milliseconds
      @logger.info "Pinged #{server.fqdn}: #{rtt ? "#{rtt.round(2)} ms" : 'no response'}"
      rtt
    rescue => e
      @logger.warn "Failed to ping #{server.fqdn}: #{e.message}"
      nil
    end
  end

  def trilaterate(server_data)
    # Extract coordinates and distances
    points = server_data.map do |data|
      server = data[:server]
      {
        lat: server.geopoint.lat,
        lon: server.geopoint.lon,
        distance: data[:distance]
      }
    end

    # Simple trilateration using first three points
    result = calculate_trilateration(points[0], points[1], points[2])

    if result
      @logger.info "Trilateration result: lat=#{result[:lat]}, lon=#{result[:lon]}"
      Speedtest::GeoPoint.new(result[:lat], result[:lon])
    else
      @logger.warn "Trilateration failed"
      nil
    end
  end

  def calculate_trilateration(p1, p2, p3)
    # Convert to Cartesian coordinates
    x1, y1 = lat_lon_to_cartesian(p1[:lat], p1[:lon])
    x2, y2 = lat_lon_to_cartesian(p2[:lat], p2[:lon])
    x3, y3 = lat_lon_to_cartesian(p3[:lat], p3[:lon])

    r1, r2, r3 = p1[:distance], p2[:distance], p3[:distance]

    # Trilateration calculations
    a = 2 * (x2 - x1)
    b = 2 * (y2 - y1)
    c = r1**2 - r2**2 - x1**2 + x2**2 - y1**2 + y2**2
    d = 2 * (x3 - x2)
    e = 2 * (y3 - y2)
    f = r2**2 - r3**2 - x2**2 + x3**2 - y2**2 + y3**2

    # Solve system of equations
    denominator = a * e - b * d
    return nil if denominator.abs < 1e-10 # Avoid division by zero

    x = (c * e - f * b) / denominator
    y = (a * f - d * c) / denominator

    # Convert back to lat/lon
    cartesian_to_lat_lon(x, y)
  end

  def lat_lon_to_cartesian(lat, lon)
    # Simple projection for small areas
    x = lon * Math.cos(lat * Math::PI / 180) * 111_320
    y = lat * 110_540
    [x, y]
  end

  def cartesian_to_lat_lon(x, y)
    lat = y / 110_540
    lon = x / (Math.cos(lat * Math::PI / 180) * 111_320)
    { lat: lat, lon: lon }
  end

  def select_diverse_servers(ping_results)
    return ping_results.first(3) if ping_results.size <= 5

    # Start with the closest server as anchor
    selected = [ping_results.first]
    remaining = ping_results[1..-1]

    # Find the server that's farthest from the first one
    farthest = remaining.max_by do |result|
      angular_distance(selected.first[:server], result[:server])
    end
    selected << farthest
    remaining.delete(farthest)

    # Find the third server that maximizes the triangle area
    best_third = remaining.max_by do |result|
      triangle_quality(selected[0][:server], selected[1][:server], result[:server])
    end
    selected << best_third if best_third

    @logger.info "Selected servers for trilateration:"
    selected.each_with_index do |result, i|
      server = result[:server]
      @logger.info "  #{i+1}. #{server.url} (lat: #{server.geopoint.lat}, lon: #{server.geopoint.lon})"
      @logger.info "distance: #{'%.1f' % (result[:distance]/1000)}km)"
    end

    selected
  end

  def angular_distance(server1, server2)
    lat1 = server1.geopoint.lat * Math::PI / 180
    lon1 = server1.geopoint.lon * Math::PI / 180
    lat2 = server2.geopoint.lat * Math::PI / 180
    lon2 = server2.geopoint.lon * Math::PI / 180

    # Haversine formula for angular distance
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = Math.sin(dlat/2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlon/2)**2
    Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
  end

  def triangle_quality(server1, server2, server3)
    # Calculate the area of the triangle formed by the three servers
    # Larger area indicates better geometric diversity
    lat1 = server1.geopoint.lat
    lon1 = server1.geopoint.lon
    lat2 = server2.geopoint.lat
    lon2 = server2.geopoint.lon
    lat3 = server3.geopoint.lat
    lon3 = server3.geopoint.lon

    # Use the shoelace formula for triangle area
    area = ((lat1 * (lon2 - lon3) + lat2 * (lon3 - lon1) + lat3 * (lon1 - lon2)) / 2.0).abs

    # Also consider the minimum angle to avoid near-collinear points
    angles = calculate_triangle_angles(server1, server2, server3)
    min_angle = angles.min

    # Penalize triangles with very small angles (near-collinear)
    return 0 if min_angle < 10 * Math::PI / 180 # Less than 10 degrees

    # Return area weighted by minimum angle quality
    area * min_angle
  end

  def calculate_triangle_angles(server1, server2, server3)
    # Calculate the three angles of the triangle
    points = [
      [server1.geopoint.lat, server1.geopoint.lon],
      [server2.geopoint.lat, server2.geopoint.lon],
      [server3.geopoint.lat, server3.geopoint.lon]
    ]

    angles = []
    3.times do |i|
      p1 = points[i]
      p2 = points[(i + 1) % 3]
      p3 = points[(i + 2) % 3]

      # Calculate vectors
      v1 = [p2[0] - p1[0], p2[1] - p1[1]]
      v2 = [p3[0] - p1[0], p3[1] - p1[1]]

      # Calculate angle using dot product
      dot_product = v1[0] * v2[0] + v1[1] * v2[1]
      magnitude1 = Math.sqrt(v1[0]**2 + v1[1]**2)
      magnitude2 = Math.sqrt(v2[0]**2 + v2[1]**2)

      next if magnitude1 == 0 || magnitude2 == 0

      cos_angle = dot_product / (magnitude1 * magnitude2)
      cos_angle = [[-1, cos_angle].max, 1].min # Clamp to [-1, 1]
      angles << Math.acos(cos_angle)
    end

    angles
  end
end
