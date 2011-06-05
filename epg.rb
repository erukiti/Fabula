#! /usr/bin/env ruby -Ku
# 
# ひとまず epgdump のはき出す XML を parse して、プログラムの一覧を取るところまで実験
# 


require 'rexml/document'

class EPGFromEpgdump
  def initialize(epgxml)
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
        'title' => programme.elements['title'].text,
        'desc' => programme.elements['desc'].text,
        'category' => programme.elements["category[@lang='en']"].text,
        'start' => EPGFromEpgdump.time_from_epgdump(programme.attribute('start').to_s),
        'stop' => EPGFromEpgdump.time_from_epgdump(programme.attribute('stop').to_s),
      }
    }
  end

  def channel
    @channel
  end
  
  def program
    @program
    
  end

  def EPGFromEpgdump.time_from_epgdump(epgdump_time)
    #ひとまずタイムゾーンは +9000 に決めうち
    #2011060302400 +0900
    Time.mktime(epgdump_time[0..3], epgdump_time[4..5], epgdump_time[6..7], epgdump_time[8..9], epgdump_time[10..11], epgdump_time[12..13])
    
  end

end

class EPG
  def initialize(initializer, opt)
    init = initializer.new(opt)
    @program = init.program
    @channel = init.channel
  end

  def program
    @program
  end

  def channel
    @channel
  end

end

class ControlList
  def initialize
    @control_list = []
  end

  def add(title, desc, category, time_range, channel, priority)
    @control_list << {'title' => title, 'desc' => desc, 'category' => category, 'time_range' => time_range, 'channel' => channel, 'priority' => priority}
  end

  def match(program_original)
    program = program_original.dup

    program['priority'] = 0
    @control_list.each { |control|
      next if control['title'] != nil && Regexp.new(control['title']) !~ program['title']
      next if control['desc'] != nil && Regexp.new(control['desc']) !~ program['desc']
      next if control['category'] != nil && control['category'] != program['category']

      if control['time_range'] != nil
        next if control['time_range'].last <= program['start']
        program['start'] = control['time_range'].first if program['start'] < control['time_range'].first
        program['stop'] = control['time_range'].last if program['stop'] > control['time_range'].last
      end

      next if control['channel'] != nil && control['channel'] != program['channel']

      # すべてマッチしたので、priority を変更

      # 一度ブラックリスト(優先度:-1)のチェックがついてしまった場合、優先度は変更できなくなる
      next if program['priority'] < 0

      # blacklist or 優先度上昇
      program['priority'] = control['priority'] if control['priority'] < 0 || control['priority'] > program['priority']
  }
    program
    
  end

end

# FIXME: 配列で表現してるprogram をすべてこれのオブジェクトに置き換える
class Program
  def initialize(program_list) # FIXME: 暫定的。
    @program_list = program_list
  end

  def check(channel_number)
    channel = {}

    @program_list.sort! { |a, b| a['start'] <=> b['start'] }
    @conflict = []
    @conflict_cnt = 0
    may_conflict_cnt = 0

    i = 0
    begin
#print "====\n#{i}: #{@program_list[i]['title']}\n"
#print "#{@program_list[i]['stop']},  #{@program_list[i + 1]['start']}\n"
      next if @program_list[i]['stop'] <= @program_list[i + 1]['start']

# FIXME: conflict してなおかつチャンネルが矛盾してるデータがないか調べる
      # confilict している可能性のある塊の検出
#print "conflict #{i + 1}\n"
      @conflict[may_conflict_cnt] = [@program_list[i], @program_list[i + 1]]
      mark = @program_list[i]['stop'] >= @program_list[i + 1]['stop'] ? @program_list[i]['stop'] : @program_list[i + 1]['stop'] 
      j = i + 2
      while j <= @program_list.size - 1
#print "#{j}: #{@program_list[j]['title']}\n"
#print "#{mark}, #{@program_list[j]['start']}\n"
        break if mark <= @program_list[j]['start']
#print "conflict #{j}\n"
        @conflict[may_conflict_cnt] << @program_list[j]
        mark = mark >= @program_list[j]['stop'] ? mark : @program_list[j]['stop']
        j += 1
      end
      may_conflict_cnt += 1
#print "#{j}\n<<<<\n";
      i = j - 1
    ensure 
      i += 1
    end while i < @program_list.size - 2

    return if may_conflict_cnt == 0

#p @conflict
    # conflict 解決
    @conflict.each { |conflict|
      slot = []
      conflict.each { |program|
        is_conflict = true
#print "++++\n"
#p program['start']
        for i in 0 ... channel_number
#print "ch: #{i}\n"
#print "slot: #{slot[i].inspect}\n"
          if slot[i] == nil || slot[i] <= program['start']
#print "into: #{i}\n"
            slot[i] = program['stop']
#print "*slot: #{slot[i].inspect}\n"
            is_conflict = false
            program['slot'] = i
            break
          end
        end
        if is_conflict
#print "conflict: #{program['title']}\n"
          @conflict_cnt += 1 
          program['conflicted'] = true
        end
      }
    }

  end

  def conflict?
#p @conflict
    @conflict_cnt > 0

  end

  # FIXME: ひとまず確認用。もっといい名前に書き換えるべき
  def resolved
    @program_list
  end


end
