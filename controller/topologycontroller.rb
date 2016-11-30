
require 'trema'
require 'topology'

class TopologyController

  attr_reader :topology
  attr_reader :level_sws
  
  def initialize switch_number
    @topology = Topology.new()
    @switch_number = switch_number
    @path = {}        # [dpid1][dpid2] -> { :intermediate_dpid => dpid, :link_weight => weight }
    @level_sws = {}   # { 0=> [dpid,], }
  end

  def ready?
    (@topology.switch_number == @switch_number)
  end

  # calculate paths between every switches
  # write results to @path
  def calculate_paths
    @topology.each_switch do | swi |
      @path[swi] = {}
      @topology.each_switch do | swj |
        @path[swi][swj] = {:intermediate_dpid => nil, :link_weight => nil}
      end
      @path[swi][swi] = {:intermediate_dpid => nil, :link_weight => 0}
    end

    @topology.adjacency.each do | swi, swjs |
      swjs.each do | swj, port_number |
        puts "ERROR" unless @path.include?(swi)
        @path[swi] = {} unless @path.include?(swi) # add by morimoto
        #puts "path[#{swi}] = #{@path[swi]}"
        #puts "path[#{swi}][#{swj}] = #{@path[swi][swj]}"
        @path[swi][swj] = {:intermediate_dpid => nil, :link_weight => 1}
      end
    end
    @topology.each_switch do | swk |
      @topology.each_switch do | swi |
        @topology.each_switch do | swj |
          # puts "swk=#{swk}  swi=#{swi} swj=#{swj} swk=#{swj}"
          if @path[swi][swk][:link_weight]  
            if @path[swk][swj][:link_weight]
              ikj_weight = @path[swi][swk][:link_weight] + @path[swk][swj][:link_weight]
              if !@path[swi][swj][:link_weight]\
                or ikj_weight < @path[swi][swj][:link_weight]
               # puts "swk=#{swk}  swi=#{swi} swj=#{swj} swk=#{swj} !!!"
               # puts "pat = #{@path[swi][swj][:link_weight]}"
               # puts "ikj = #{ikj_weight}"
                puts ""
                @path[swi][swj] = {:intermediate_dpid => swk, :link_weight => ikj_weight}
               # puts "#{swi} to #{swj} -> #{@path[swi][swj]}"
                elsif ikj_weight == @path[swi][swj][:link_weight]\
                 and @path[swi][swj][:link_weight] != 0\
                 and @path[swi][swj][:link_weight] != 1\
                 and @path[swi][swj][:intermediate_dpid] != swk \
                 and swi != swk and swj != swk
                 # puts "intermidiate = #{@path[swi][swj][:intermediate_dpid]}"
                 #number_path = 2 unless @path[swi][swj][:path_number]
                 #number_path = @path[swi][swj][:path_number] + 1 if @path[swi][swj][:path_number]
                 #number_switch = "no." + number_path.to_s  + "switch"
                # puts "#{number_path}"
                 #@path[swi][swj] = {:intermediate_dpid => swk, :link_weight => ikj_weight, :path_number => number_path}
                 #@path[swi][swj][:path_number] = number_path
                 #@path[swi][swj][number_switch] = swk
                  if swi == 17 and swj == 21
                   @path[swi][swj] = {:intermediate_dpid => 18, :link_weight => ikj_weight}
                  elsif swi == 17 and swj == 16
                   @path[swi][swj] = {:intermediate_dpid => 20, :link_weight => ikj_weight}
                  end
              end
            end
          end
        end
      end
    end
   # self.topology.display
   # puts " "
    display_path
   # puts "count !"
  end

  def calculate_levels
    unused_sws = @topology.switches.dup
    i = 0
    @level_sws[i] = []
    @topology.mac_map.each do | mac, sw |
      @level_sws[i] << sw[:dpid] unless @level_sws[i].include?(sw[:dpid])
      unused_sws.delete(sw[:dpid])
    end
    
    begin
      @level_sws[i+1] = []
      @level_sws[i].each do | swi |
        @topology.adjacency[swi].each do | swj, port |
          if unused_sws.include?(swj)
            @level_sws[i+1] << swj unless @level_sws[i+1].include?(swj)
            unused_sws.delete(swj)
          end
        end
      end
      i = i + 1
    end while not unused_sws.empty?
  end
  
  # get switch and port list between src_switch and dst_switch
  # src_switch, dst_switch -> dpid
  # return [{:dpid=>dpid, :out_port=>port},]
  def get_path src_switch, dst_switch, final_port
    if src_switch == dst_switch
      p = [src_switch]
    else
      p = get_raw_path(src_switch, dst_switch)
      return nil unless p
      p = [src_switch] + p + [dst_switch]
    end
    r = []
    p[0..-1].each_cons(2) do | s1,s2 |
      port = @topology.adjacency[s1][s2]
      r.push({:dpid => s1, :out_port => port})
    end
    r.push({:dpid => dst_switch, :out_port => final_port})
    return r
  end
  
  def display_path
    @topology.each_switch do | swi |
      @topology.each_switch do | swj |
        puts swi.to_s + " to " + swj.to_s + " "\
        + @path[swi][swj].to_s if @path[swi][swj] unless swi == swj
      end
    end
  end
  
  def read_file
    File.open("topology-info").each_line do | each |
      if /(\d+)\s(\d+)\s(\d+)\s(\d+)/ =~ each
        @topology.add_switch $1
        @topology.add_switch $4
        @topology.add_link($1, $2, $3, $4)
      end
    end
    #File.open("node-info").each_line do | each |
     # ipaddr, macaddr, dpid, port_number = each.split(" ")
     # @ip_mac[ipaddr] = macaddr
     # @mac_map[macaddr] = {:dpid => dpid, :in_port => port_number.to_i}
    #end
  end

  private
  
  # get switches through path between src_switch and dst_switch
  # src_switch, dst_switch -> dpid
  # return [src_switch, dpid1,..., dpidi, dst_switch]
  def get_raw_path src_switch, dst_switch
    if src_switch == dst_switch
      return []
    elsif !@path[src_switch][dst_switch][:link_weight]
      return nil
    end
  #  if @path[src_switch][dst_switch][:path_number] != nil
#      if src_switch == 16 and src_switch =="17"
 #        puts "AAA===#{src_switch}"
  #     end
      intermediate = @path[src_switch][dst_switch]["no.2switch"]
  #  elsif
      intermediate = @path[src_switch][dst_switch][:intermediate_dpid]
    #puts "src = #{src_switch}, dst =#{dst_switch}, inter = #{@path[src_switch][dst_switch][:intermediate_dpid]}"
  #  end
    return [] unless intermediate
    return get_raw_path(src_switch, intermediate)\
    + [intermediate]\
    + get_raw_path(intermediate, dst_switch)
  end

end
