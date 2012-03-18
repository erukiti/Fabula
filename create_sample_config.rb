# coding: utf-8
require 'yaml'

$KCODE = 'U'

config = {
  :channel => {
'C23' => "NHK総合",
'C28' => "NHK教育",
'C32' => "TBS",
'C37' => "テレビ朝日",
'C39' => "テレビ東京",
'C31' => "日本テレビ",
'C47' => "TOKYO MX",
'C34' => "フジテレビ",

   },
  :temporary => './tmp/',
  :recording => '/storage/movie/',
  :slot => ['/dev/ptx0.t0', '/dev/ptx0.t1'],
}

File.open('.config.yaml', 'w') { |f|
  f << config.to_yaml
}
