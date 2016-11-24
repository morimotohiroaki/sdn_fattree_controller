
require 'trema'


module Util
  MIN_PACKET_DATA_LEN = 60

  def lldp_binary_string dpid, port_number
    Pio::Lldp.new(dpid: dpid, port_number: port_number).to_binary
  end
  
  def get_mac_address packet_in
    mac = {}
    if packet_in.arp?
      mac[:source] = packet_in.arp_sha
      mac[:target] = packet_in.arp_tha
    elsif
      mac[:source] = packet_in.macsa
      mac[:target] = packet_in.macda
    end
    mac
  end

  def get_ip_address packet_in
    ip = {}
    if packet_in.arp?
      ip[:source] = packet_in.arp_spa
      ip[:target] = packet_in.arp_tpa
    elsif
      ip[:source] = packet_in.ipv4_saddr
      ip[:target] = packet_in.ipv4_daddr
    end
    ip
  end
  
  def read_lldp_packet_data packet_in
    lldp = Pio::Lldp.read(packet_in.data)
  end
  
  def check_packet data
    if data.length < 64
      data = data + "\000"*(64-data.length)
    end
    data
  end

  def check_data_size data
    data_length = data.length
    if (data_length < MIN_PACKET_DATA_LEN)
      data = data + "\x00" * (MIN_PACKET_DATA_LEN - data_length)
    end
    data
  end

  def multicast? mac
    puts "target mac is #{mac}"
    (mac == 'ff:ff:ff:ff:ff:ff')
  end
end
