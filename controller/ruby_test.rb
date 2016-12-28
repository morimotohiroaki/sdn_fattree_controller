
 path = {}

 for num in 1..5 do
   path[num] = {:intermediate => num *2}
 #  puts "#{path[num]}"
 end

 for num in 1..3 do
    #path[num] = {:intemediate => num* 2, num => num *3}
   number = 'happy_' + num.to_s
 #  puts "#{number}"
   path[num][number] = num *3 
 #  puts "#{path[num]}"
 end

 for num in 1..5 do
  if path[num][:intermediate2]
 #  puts "i have a pen"
  end
 end

 inter = []

 if inter[0] == nil
  puts "nilnil!："
 end
 puts "#{inter}"

 inter.push(10)

 puts "#{inter}"

 inter.push(20)
 
 puts "#{inter[1]}"

 if inter.include?(inter[1])
  a = inter.index(20)
  puts "a = #{a}"
  inter[a] =30
  puts "#{inter}"
  inter.delete(inter[a])
  puts "#{inter}"
 end

 
