
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
          # puts "#{dpida} (#{porta}) -> #{dpidb}"
        end
      end
    end

    @ip_mac.each_pair do | ip, mac |
      mac_map = @mac_map[mac]
      puts "#{ip} -> #{@ip_mac[ip]} => #{mac_map[:dpid]}, #{mac_map[:in_port]}"
    end if @ip_mac
  end
  
end
