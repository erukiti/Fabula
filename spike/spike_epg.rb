#! /usr/bin/env ruby -Ku
# 
# ひとまず epgdump のはき出す XML を parse して、プログラムの一覧を取るところまで実験
# 

$KCODE = 'UTF8'

require 'rexml/document'

class EPG
  def initialize(xml)
    epgxml = IO.read xml
    epgdata = REXML::Document.new epgxml

    @channel = {}
    epgdata.elements.each('tv/channel') { |ch|
      @channel[ch.attribute('id').to_s] = ch.elements['display-name'].text
    }

    @program = {}
    epgdata.elements.each('tv/programme') { |programme|
      channel = programme.attribute('channel').to_s

      @program[channel] = [] if @program[channel] == nil

      @program[channel] << {
        'start' => programme.attribute('start').to_s,
        'stop' => programme.attribute('stop').to_s,
        'title' => programme.elements['title'].text,
        'desc' => programme.elements['desc'].text,
        'category' => programme.elements["category[@lang='en']"].text,
      }
    }
    p @channel
    p @program
  end
end

epg = EPG.new('c39.xml')