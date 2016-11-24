
require 'topologycontroller'
require 'utilities'

class BcastController < Controller # (1)
  # periodic_timer_event :flood_lldp_frames, 5
  # periodic_timer_event :test_duplication_rule, 2

  def start # (2)
    #include Trema::Port
    puts "Hello, Trema!"
    @network = TopologyController.new(3)
    @controller_ip = "192.168.10.106"
    @controller_port = 50000
    self.get_information_from_mpi
    @outPorts    # {dpid => [], }
    @mpi_id_mac = ""  # string
    @mpi_id_ip  = ""  # string

    @installed = 0
  end

  def switch_ready dpid
    # send request for features to switch
    info "switch connected, #{dpid}"
    # for skipping switch with no active ports
    begin
      puts "sending feature request to #{dpid}"
      send_message dpid, FeaturesRequest.new
    end unless skip_switch? dpid
  end

  def features_reply dpid, features_reply
    # add switch to topology instance
    @network.topology.add_switch dpid
    features_reply.physical_ports.select(&:up?).each do | port |
      @network.topology.add_port dpid, port
    end
    puts "Flooding lldp.."
    flood_lldp_frames

    # this method is for when lldp is not working
    #if @network.ready?
    # read_topology
    #end
  end

  # temporary def for testing
  # not using now
  def test_duplication_rule
    if @network.topology.ip_mac.length < 7
      puts "ip_mac length is #{@network.topology.ip_mac.length}"
    end
    if @network.topology.ip_mac.length == 7 and @installed == 0
      ipstring = "10.0.0.1 10.0.0.2 10.0.0.3 10.0.0.4 10.0.0.5 10.0.0.6 10.0.0.7"
      ips = ipstring.split(" ")
      master = ips.shift
      slaves = ips
      puts "master is : " + master.to_s
      puts "slaves are : " + slaves.to_s
      @outPorts = {}
      generate_mpi_id
      install_duplication_rules master, slaves
      puts "Ready to broadcast data"
      @installed = 1
    end
  end

  def packet_in dpid, packet_in
    # checking for whether duplication rules on switch or not
    # if not, it means duplication rules not installed or erased
    begin 
      if mpi_bcast_packet? packet_in
        puts "++++++++++++++++++++++++++++ duplication rule erased on #{dpid}"
      end
    end

    # for debuggin show all new packets
     mac = Util.get_mac_address(packet_in)
     ip = Util.get_ip_address(packet_in)
    #  puts "new packet arrived... on #{dpid}: #{mac[:source]},"\
     "#{ip[:source]} -> #{mac[:target]}, #{ip[:target]}" unless packet_in.lldp?
      
    if packet_in.lldp?
      # puts "Lldp packet came to #{dpid}"

      lldp = Util.read_lldp_packet_data(packet_in)
      @network.topology.add_link lldp.dpid, lldp.port_number,\
      packet_in.in_port, dpid unless skip_switch? lldp.dpid
      @network.calculate_paths

    else
      mac = Util.get_mac_address(packet_in)
      ip = Util.get_ip_address(packet_in)
      @network.topology.update_node_info(packet_in, dpid)
      if @network.topology.check_mac_map?(mac[:target])
        src_mac_map = @network.topology.mac_map[mac[:source]]
        dst_mac_map = @network.topology.mac_map[mac[:target]]
        # puts "installing rules : #{ip[:source]} to #{ip[:target]}"
        # installing path rule for src_mac to dst_mac
        out_port = install_path src_mac_map, dst_mac_map, mac[:source],\
        ip[:source], mac[:target], ip[:target], packet_in
        # installing path rule for dst_mac to src_mac
        install_path dst_mac_map, src_mac_map, mac[:target], ip[:target],\
        mac[:source], ip[:source], packet_in
        packet_out dpid, packet_in, out_port.to_i
      else
        # puts "Dont know this packet. Flooding..."
        packet_out dpid, packet_in, OFPP_FLOOD
      end
    end
  end

  def get_information_from_mpi
    th1 = Thread.new do
      sock = UDPSocket.new
      puts "Binding #{@controller_ip}:#{@controller_port} ..."
      sock.bind(@controller_ip, @controller_port)
      puts "Waiting for the request from MPI application"
      data, addr = sock.recvfrom(1024)
      #data = "10.0.0.1 10.0.0.4 10.0.0.3 10.0.0.2"
      puts "Recieved data from MPI application : " + data.to_s
      ips = data.split(" ")
      ips = create_ring_topology ips
      puts "Created virtual effective ring topology"
      master = ips.shift
      slaves = ips
      puts "master is : " + master.to_s
      puts "slaves are : " + slaves.to_s
      @outPorts = {}
      generate_mpi_id
      install_duplication_rules master, slaves
      data = @mpi_id_mac + " " + @mpi_id_ip + " " + master + " " + ips.join(" ")
      puts "sending data : " + data + " length is : " + data.length.to_s
      sock.send data, 0, addr[3], addr[1]
      sock.close
    end
  end

  private

  def read_topology
    @network.topology.read_topology
    @network.calculate_paths
    @network.display_path
  end
  
  def mpi_bcast_packet? packet_in
    mac = Util.get_mac_address(packet_in)
    if mac[:target].to_s == @mpi_id_mac
      return true
    else
      return false
    end
  end

  def skip_switch? dpid
    skip = false
    dpids = [301, 100]
    dpids.each do | dp |
        skip = true unless dp != dpid
    end
    return skip
  end
  
  # install rules between 2 switches,
  # src_mac_map, dst_mac_map -> {:dpid=>dpid, :in_port=>port}
  def install_path src_mac_map, dst_mac_map, mac_src, ip_src, mac_dst, ip_dst, packet_in
    src_switch = src_mac_map[:dpid]
    dst_switch = dst_mac_map[:dpid]
    final_port = dst_mac_map[:in_port]
    r = @network.get_path(src_switch, dst_switch, final_port)
    r.each do | sw |
      flow_mod(sw[:dpid], mac_src, ip_src, mac_dst, ip_dst, packet_in, sw[:out_port])
    end
    return r[0][:out_port]
  end
  
  def flow_mod dpid, mac_src, ip_src, mac_dst, ip_dst, packet_in, port_number
    # puts "installing #{dpid}: #{mac_src}, #{ip_src} => #{ip_dst}, #{mac_dst}"
    send_flow_mod_add(dpid,
                      :match => Match.new(:dl_src => mac_src,
                                          :nw_src => ip_src,
                                          :dl_dst => mac_dst,
                                          :nw_dst => ip_dst),
                      :actions => SendOutPort.new(port_number))
  end
  
  def packet_out dpid, packet_in, port_number
    data = check_data_size packet_in.data
    send_packet_out(dpid,
                    :packet_in => packet_in,
                    :data => data,
                    :actions => SendOutPort.new(port_number))
  end
  
  def flood_lldp_frames
    @network.topology.each_switch do | dpid |
      #puts "Sending lldp to #{dpid}"
      ports = @network.topology.ports[dpid]
      ports.each do | port |
        port_number = port.number
        #puts "    : port -> #{port_number}"
        send_packet_out(dpid,
                        :actions => SendOutPort.new(port_number),
                        :data => Util.lldp_binary_string(dpid, port_number))
      end unless ports.nil?
    end
  end

  def create_ring_topology ips
    puts "calculating levels"
    @network.calculate_levels
    puts "calculated levels"
    level = @network.level_sws.length-1
    i = 0
    tmp = {}
    tmp_list = []
    ips.each do | ip |
      mac = @network.topology.ip_mac[ip]
      mac_map = @network.topology.mac_map[mac]
      unless tmp.include?(mac_map[:dpid])
        tmp[mac_map[:dpid]] = []
      end
      tmp[mac_map[:dpid]] << ip
      unless tmp_list.include?(mac_map[:dpid])
        tmp_list << mac_map[:dpid]
      end
    end

    (1..level).each do | i |
    tmp_next = {}
      tmp_next_list = []
      tmp_list.each do | swi |
        up_sw = nil
        @network.topology.adjacency[swi].each do | swj, port |
          up_sw = swj
          break if @network.level_sws[i].include?(swj)
        end
        tmp_next[up_sw] = [] unless tmp_next.include?(up_sw)
        tmp_next[up_sw] = tmp_next[up_sw] + tmp[swi]
        tmp_next_list << up_sw unless tmp_next_list.include?(up_sw)
      end
      tmp = tmp_next.dup
      tmp_list = tmp_next_list.dup
    end
    return tmp[tmp_list[0]]
  end
  
  def install_duplication_rules master, slaves
    master_mac = @network.topology.ip_mac[master]
    # master_mac = "00:10:18:27:F4:6C"
    puts "broadcasting node is #{master}, #{master_mac}"
    slaves.each do | s |
      src_sw = @network.topology.mac_map[@network.topology.ip_mac[master]][:dpid]
      in_port = @network.topology.mac_map[@network.topology.ip_mac[master]][:in_port]
      dst_sw = @network.topology.mac_map[@network.topology.ip_mac[s]][:dpid]
      final_port = @network.topology.mac_map[@network.topology.ip_mac[s]][:in_port]
      p = @network.get_path(src_sw, dst_sw, final_port)
      p.each do | map |
        sw = map[:dpid]
        out_port = map[:out_port].to_i
        @outPorts[sw] = [] unless @outPorts.key?(sw)
        @outPorts[sw] << out_port unless @outPorts[sw].include?(out_port)
      end
    end
    @outPorts.each do | dpid, out_ports |
      puts "#{dpid} : #{out_ports} installing."
      puts "installing rule : #{master_mac} -> #{@mpi_id_mac} on #{dpid}..."
      send_flow_mod_add( dpid,
                         :priority => 0xfff2,
                         :match => Match.new(:dl_src => master_mac,
                                             :dl_dst => @mpi_id_mac ),
                         :actions => output_actions(out_ports) )
                         #:actions => SendOutPort.new(OFPP_FLOOD) )
    end
    puts "Installed duplication rules"
  end

  def output_actions ports
    # ActionOutput.new(:port=>each)
    ports.collect do | each |
      SendOutPort.new(each)
    end
  end
  
  def generate_mpi_id
    @mpi_id_mac = "00:e0:81:fa:fa:fa"
    @mpi_id_ip = "192.168.100.100"
  end

end
