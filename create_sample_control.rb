# coding: utf-8
$KCODE = 'U'

require 'yaml'
control_list = []

control_list << {:category => "anime",:channel => 'C23', :priority => 8}
control_list << {:category => "anime",:channel => 'C28', :priority => 8}
control_list << {:category => "anime",:channel => 'C32', :priority => 10}
control_list << {:category => "anime",:channel => 'C37', :priority => 10}
control_list << {:category => "anime",:channel => 'C39', :priority => 10}
control_list << {:category => "anime",:channel => 'C31', :priority => 10}
control_list << {:category => "anime",:channel => 'C47', :priority => 10}
control_list << {:category => "anime",:channel => 'C34', :priority => 10}
control_list << {:title => "ノイタミナ", :priority => 12}

File.open('.control.yaml', 'w') { |f|
  f << control_list.to_yaml
}
