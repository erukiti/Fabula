require 'yaml'

control_list = []

control_list << {
  :title => nil,
  :desc => nil,
  :category => "anime",
  :time_range => nil,
  :channel => nil,
  :priority => 10,
}
File.open('.control.yaml', 'w') { |f|
  f << control_list.to_yaml
}
