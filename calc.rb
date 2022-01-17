require 'json'

wp = JSON.parse(File.read('WunderNFT.json'))

passes = wp.map {|w| ({id: w['tokenId']['hex'].to_i(16), status: w['status'], pattern: w['pattern'], wonder: w['wonder'], edition: w['edition']})}

distributions = {status: {}, pattern: {}, wonder: {}, edition: {}}

distributions.keys.each do |key|
  passes.each do |pass|
    prop = pass[key]
    distributions[key][prop] = distributions[key][prop].to_i + 1
  end

  distributions[key] = distributions[key].sort_by {|k,v| v}.reverse.to_h
end

data = {distributions: distributions, passes: passes}

File.open('wunder_pass_data.json', 'wb') { |f| f << data.to_json }