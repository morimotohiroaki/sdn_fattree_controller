
@path = {}

@path[0] = {}

a = [10, 20]
a.push(30)
@path[0][1] = {:inter => a}
@path[0][2] = {:inter => 20}

puts "#{@path[0][1]}"
puts "#{@path[0][2]}"

@path[0][1][:inter].each do | b |
  puts "#{b}"
end
