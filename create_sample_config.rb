require 'yaml'

config = {
  :channel => {
'C23' => "NHK����",
'C28' => "NHK����",
'C32' => "TBS",
'C37' => "�e���r����",
'C39' => "�e���r����",
'C31' => "���{�e���r",
'C47' => "TOKYO MX",
'C34' => "�t�W�e���r",

   },
  :temporary => './tmp/',
  :recording => '/storage/movie/',
  :slot => ['/dev/ptx0.t0', '/dev/ptx0.t1'],
}

File.open('.config.yaml', 'w') { |f|
  f << config.to_yaml
}
