
require 'forwardable'

class Topology
  extend Forwardable
  
  def_delegator :@switches, :each, :each_switch

  attr_reader :ports
  attr_reader :adjacency
  attr_reader :mac_map
  attr_reader :switches
  attr_reader :ip_mac
  
  def initialize
    @switches = []    # list of switches, [ dpid1, dpid2, ... ]
    @ports = {}       # physical port number lists { dpid -> [], }
    @adjacency = {}   # [dpid1][dpid2] = port number, dpid1 (port)-> dpid2
    @mac_map = {}     # { mac_addr -> { :dpid => dpid, :in_port => port number }, }
    @ip_mac = {}      # { ip_address => mac address,  }
    @traffic_monitor1 = {} #[dpid1][dpid2] = traffic_total_size
    @traffic_monitor2 = {} #[dpid1][dpid2] = traffic_current_size
  end

  def add_switch dpid
    @switches << dpid unless @switches.include?(dpid)
  end

  def add_port dpid, port
    @ports[dpid] = [] unless @ports.include?(dpid)
    @ports[dpid] << port
  end

  def add_link dpida, porta, portb, dpidb
    @adjacency[dpida] = {} unless @adjacency.key?(dpida)
    @adjacency[dpida][dpidb] = porta.to_i
    @adjacency[dpidb] = {} unless @adjacency.key?(dpidb)
    @adjacency[dpidb][dpida] = portb.to_i
  end

  def update_node_info packet_in, dpid
    mac = Util.get_mac_address(packet_in)
    ip = Util.get_ip_address(packet_in)
    unless check_mac_map?(mac[:source])
      @mac_map[mac[:source]] = {:dpid => dpid, :in_port => packet_in.in_port}
      @ip_mac[ip[:source].to_s] = mac[:source]
      # self.display
    end
  end
  
  def switch_number
    @switches.size
  end

  def check_mac_map? mac
    @mac_map.include?(mac)
  end

  def read_topology
    File.open("topology.data") do | file |
      file.each_line do | line |
        data = line.split(" ")
        self.add_link data[0].to_i, data[1].to_i, data[2].to_i, data[3].to_i
      end
    end
  end
  
  def display
    self.each_switch do | dpida |
      if @adjacency.include?(dpida)
        @adjacency[dpida].each do | dpidb, porta |
            puts "#{dpida} (#{porta}) -> #{dpidb}"
        end
      end
    end

    @ip_mac.each_pair do | ip, mac |
      mac_map = @mac_map[mac]
      puts "#{ip} -> #{@ip_mac[ip]} => #{mac_map[:dpid]}, #{mac_map[:in_port]}"
    end if @ip_mac
  end
  
  def update_traffic_size sw, port, rx_bytes
    @traffic_monitor1[sw] = {}  unless @traffic_monitor1.include?(sw)
    @traffic_monitor2[sw] = {}  unless @traffic_monitor2.include?(sw)
   # if port == 4
   # puts "rx_bytes = #{rx_bytes}"
   # puts "traffic  = #{@traffic_monitor2[sw][port]}"
    @traffic_monitor1[sw][port] = rx_bytes.to_i - @traffic_monitor2[sw][port].to_i
    @traffic_monitor2[sw][port] = rx_bytes
   #  puts "!!!#{sw} (#{port}) have #{@traffic_monitor1[sw][port]}"
  end

  def caluculate_link_packets src_sw, mid_sw, dst_sw
    total = -1
    #puts "port = #{@adjacency[src_sw][mid_sw]}"
    puts "#{@traffic_monitor1[src_sw][@adjacency[src_sw][mid_sw]]}"
    first = @traffic_monitor1[src_sw][@adjacency[src_sw][mid_sw]] # if @traffic_monitor1[src_sw][@adjacency[src_sw][mid_sw]]
    second =@traffic_monitor1[mid_sw][@adjacency[mid_sw][src_sw]] #if @traffic_monitor1[mid_sw][@adjacency[mid_sw][src_sw]]
    third = @traffic_monitor1[dst_sw][@adjacency[dst_sw][mid_sw]] #if @traffic_monitor1[mid_sw][@adjacency[dst_sw][mid_sw]]
    fourth =@traffic_monitor1[mid_sw][@adjacency[mid_sw][dst_sw]] #if @traffic_monitor1[mid_sw][@adjacency[mid_sw][dst_sw]]
    # puts "creturn total #{first}"
    total = first.to_i + second.to_i + third.to_i + fourth.to_i
   return total
  end

end
