require 'yaml'

config = {
  :channel => { 'C39' => 'TV“Œ‹ž', 'C47' => '“Œ‹žMX' },
  :temporary => './tmp/',
  :recording => '/storage/movie/',
  :slot => ['/dev/ptx0.t0', '/dev/ptx0.t1'],
}

File.open('.config.yaml', 'w') { |f|
  f << config.to_yaml
}
