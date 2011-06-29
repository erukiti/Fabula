#! /usr/bin/env ruby

$KCODE = 'UTF8'

require 'rexml/document'
require 'yaml'
require 'fileutils'

class Array
  def inspect(indent = 0)
    buf = "[\n"
    indent += 2
    self.each { |node|
      if node.is_a? Array
        buf += " " * indent + node.inspect(indent) + "\n"
      else
        buf += " " * indent + node.inspect + "\n"
      end 
    }
    indent -= 2
    buf += " " * indent + "]\n"
  end
end


class EPG
  attr_reader :program_list
  attr_reader :channel_list
  attr_reader :last_fresh
  attr_accessor :fresh

  def injection_fresh(ch, time)
    @last_fresh[ch] = time
  end

  def initialize(initializer, opt = nil)
    init = initializer.new(opt)
    @program_list = init.program_list
    @channel_list = init.channel_list
    @fresh = init.fresh
    @last_fresh = {}
  end

  def update(epg_updater)
    channel = {}
    @program_list.each { |program|
      channel[program.channel] = true unless channel[program.channel]
    }
    epg_updater.program_list.each { |program|
      unless channel[program.channel]
        channel[program.channel] = true
        @fresh[program.channel] = epg_updater.fresh[program.channel]

        @last_fresh[program.channel] = Time.now
      end
    }

    new_program_list = []
	channel.each { |ch, name|
      new_program_list += update_ch(@program_list.find_all{|program| program.channel == ch} , epg_updater.program_list.find_all{|program| program.channel == ch})
    }
    @program_list = new_program_list
  end

  def update_ch(master, updater)
    # epg_updater に含まれている時間の範囲を算出する

    cnt_master = 0
    cnt_updater = 0
    new_program_list = []

    while master.size > cnt_master || updater.size > cnt_updater

      # アップデータ側にしかない
      if master.size == cnt_master || (updater.size > cnt_updater && updater[cnt_updater].stop <= master[cnt_master].start)
        d "++#{updater[cnt_updater].start} - #{updater[cnt_updater].stop} 「#{updater[cnt_updater].title}」"

        new_program_list << updater[cnt_updater]
        cnt_updater += 1
        next
      end

      # マスター側にしかない
      if updater.size == cnt_updater || (master.size > cnt_master && master[cnt_master].stop <= updater[cnt_updater].start)
        new_program_list << master[cnt_master]

        
        cnt_master += 1
        next
      end

      # 同一
      if master[cnt_master].start == updater[cnt_updater].start &&
         master[cnt_master].stop == updater[cnt_updater].stop
        new_program_list << master[cnt_master]
        
        cnt_master += 1
        cnt_updater += 1
        next
      end

      replaced_start = cnt_master

      cnt_start = cnt_updater
      stop = master[cnt_master].stop > updater[cnt_updater].stop ? master[cnt_master].stop : updater[cnt_updater].stop
      cnt_master += 1
      cnt_updater += 1
      while master.size > cnt_master && updater.size > cnt_updater && 
            (stop > master[cnt_master].start || stop > updater[cnt_updater].start)
        if stop > updater[cnt_updater].start
          stop = updater[cnt_updater].stop if stop < updater[cnt_updater].stop
          cnt_updater += 1
        end
        if stop > master[cnt_master].start
          stop = master[cnt_master].stop if stop < master[cnt_master].stop
          cnt_master += 1
        end
      end

      #replace されるので alert を出す
      (replaced_start...cnt_master).each { |cnt|
        d "- #{master[cnt].start} - #{master[cnt].stop} 「#{master[cnt].title}」"
      }

      #replace を行いつつ、上書き側の alert を出す
      (cnt_start...cnt_updater).each { |cnt|
        d "+ #{updater[cnt].start} - #{updater[cnt].stop} 「#{updater[cnt].title}」"
        new_program_list << updater[cnt]
      }

      #FIXME: alert をもっとまともな形式にするならば、テストを書く
      #       例えば、@alert << {:start => master[cnt].start, :stop => master[cnt].stop, :title => master[cnt].title}


      # FIXME: タイトルなどデータが変わった場合なんかも更新するようにする

    end

    new_program_list
  end

  def conflict_chunk_list
    @program_list.sort! { |a, b| a.start <=> b.start }
    conflict = []

    i = 0
    begin
      next if @program_list[i].stop <= @program_list[i + 1].start

      conflict << [@program_list[i], @program_list[i + 1]]
      stop_mark = @program_list[i].stop >= @program_list[i + 1].stop ? @program_list[i].stop : @program_list[i + 1].stop 
      j = i + 2
      while j <= @program_list.size - 1
        break if stop_mark <= @program_list[j].start
        conflict.last << @program_list[j]
        stop_mark = stop_mark >= @program_list[j].stop ? stop_mark : @program_list[j].stop
        j += 1
      end
      conflict.last.sort! { |a, b| a.priority == b.priority ? a.start <=> b.start : b.priority <=> a.priority}
      i = j - 1
    ensure 
      i += 1
    end while i < @program_list.size - 2

    conflict
  end

  def resolve_conflict(device_number)
    channel = {}
    @conflict_cnt = 0

    # conflict_chunk をそれぞれ解決する
    conflict_chunk_list.each { |conflict_chunk|
      conflict_thread = []
      conflict_chunk.each { |program|
        program.conflict = true
        i = 0
        begin
          if conflict_thread[i] == nil
            conflict_thread[i] = [program]
            program.slot = i
            program.conflict = false
            break
          elsif program.stop <= conflict_thread[i].first.start
            conflict_thread[i].unshift(program)
            program.slot = i
            program.conflict = false
            break
          else
            for j in 0 ... conflict_thread[i].size
              if conflict_thread[i][j].stop <= program.start && (j >= conflict_thread[i].size - 1 || program.stop < conflict_thread[i][j+1].start)
                conflict_thread[i].insert(j + 1, program)
                program.slot = i
                program.conflict = false
                break
              end
            end
          end
          i += 1
        end while i < device_number && program.conflict
        @conflict_cnt += 1 if program.conflict
      }
    }

  end

  def conflict?
    @conflict_cnt > 0
  end
end

class EPGFromNull
  def initialize(opt)
  end
  
  def channel_list
    []
  end
  
  def program_list
    []
  end
  
  def fresh
    {}
  end
end

class EPGFromFile
  attr_reader :channel_list
  attr_reader :program_list
  attr_reader :fresh

  def initialize(savedata)
    @program_list = []
    @channel_list = []
    @fresh = {}

    epgdata = YAML.load(savedata)
    if epgdata
      @channel_list = epgdata[:channel]
      @fresh = epgdata[:fresh]
      epgdata[:program].each { |program_a|
        @program_list << Program.new(program_a)
      }
    end
  end
end

# FIXME: EPGFromFile と統合できる？
class EPGToFile
  def EPGToFile.to_yaml(epg)
    program_a = []
    epg.program_list.each { |program|
      program_a << program.to_a
    }

    {:channel => epg.channel_list, :program => program_a, :fresh => epg.fresh}.to_yaml
  end
end

class EPGFromEpgdump
  attr_reader :channel_list
  attr_reader :program_list
  attr_reader :fresh

  def initialize(epgxml)
    epgdata = REXML::Document.new epgxml

    @channel_list = {}
    epgdata.elements.each('tv/channel') { |ch|
      @channel_list[ch.attribute('id').to_s] = ch.elements['display-name'].text
    }

    @program_list = []
    epgdata.elements.each('tv/programme') { |programme|
      @program_list << Program.new(
        :channel => programme.attribute('channel').to_s,
        :title => programme.elements['title'].text,
        :desc => programme.elements['desc'].text,
        :category => programme.elements["category[@lang='en']"].text,
        :start => EPGFromEpgdump.time_from_epgdump(programme.attribute('start').to_s),
        :stop => EPGFromEpgdump.time_from_epgdump(programme.attribute('stop').to_s)
      )
    }

    @program_list.sort! { |a, b| a.start <=> b.start}

    @fresh = {}

    @channel_list.each { |ch, name|
      fresh_start = nil
      fresh_end = nil
      @program_list.each { |program|
        next if ch != program.channel || program.start > Time.now || Time.now > program.stop

        unless fresh_start 
          fresh_start = program.start 
          fresh_end = program.stop
        else
          break if fresh_start && program.start > fresh_end
          fresh_end = program.stop
        end
      }

      @fresh[ch] = fresh_end
    }
  end

  def EPGFromEpgdump.time_from_epgdump(epgdump_time)
    #ひとまずタイムゾーンは +9000 に決めうち
    #2011060302400 +0900
    Time.mktime(epgdump_time[0..3], epgdump_time[4..5], epgdump_time[6..7], epgdump_time[8..9], epgdump_time[10..11], epgdump_time[12..13])
    
  end

end

class Program
  attr_reader :channel
  attr_reader :title
  attr_reader :desc
  attr_reader :category
  attr_reader :start
  attr_reader :stop
  attr_reader :epgdump

  attr_accessor :slot
  attr_accessor :conflict
  attr_accessor :priority

  def initialize(data)
    @channel = data[:channel]
    @title = data[:title]
    @desc = data[:desc]
    @category = data[:category]
    @start = data[:start]
    @stop = data[:stop]
    @epgdump = data[:epgdump]

    @slot = data[:slot] # ひとまずデバッグ用途以外では使わない
    @conflict = false
    @priority = data[:priority]
  end

  def to_a
    {
      :channel => @channel,
      :title => @title,
      :desc => @desc,
      :category => @category,
      :start => @start,
      :stop => @stop,
      :slot => @slot,
      :conflict => @conflict,
      :priority => @priority
    }
  end
end



class Fabula
  attr_reader :epg

  def initialize()
    @channel = {}
    @epg = EPG.new(EPGFromNull)
    @accessor = FabulaAccessor.new
    @temporary = nil
    @order_file = nil
  end

  def injection_accessor(accessor, opt = nil)
    @accessor = accessor.new(opt)
  end

  def injection_config(config)
    @channel = config[:channel]
    @temporary = config[:temporary]
    #slot 
  end

  def injection_epg(epg)
    @epg = epg
  end

  def load_config
    # FIXME: ファイルがないときの処理
    config_data = YAML.load(IO.read('.config.yaml'))
    @channel = config_data[:channel]
    @accessor.set_config(config_data)
    # FIXME: temporary directory 処理
  end

  def load_order
    #begin
    filename = ".order.yaml"
    FileUtils.touch(filename)

    @order_file = File.open(filename, 'r+')
    unless @order_file.flock(File::LOCK_EX | File::LOCK_NB)
      # ロックを取得できないので今回の実行は諦める
      # FIXME: alert
      return false
    end

    @epg = EPG.new(EPGFromFile, @order_file.read)
    #rescue
    #  print "-------- error\n"
    #  p $!
    #  print "-------- error\n"
    #end
  end

  def save_order
    @order_file.rewind
    @order_file << EPGToFile.to_yaml(@epg)
    @order_file.close
    @order_file = nil
  end

  def save_queue(epg)
    epg
  end

  def load_queue
  end

  def load_epgdump
    Dir.glob("#{@accessor.temporary}/*_epg.xml") { |filename|
print "!epgdump file: #{filename}\n"
    }
  end

  def main
    # キューを抜き出す
    # まず切羽詰ってる順にチャンネルを並べる
    slot_order = []

    slots = @accessor.available_slot
    ch_queue = {}
    @channel.each { |ch, name|
      ch_queue[ch] = Time.now + (60 * 60 * 4)
    }
    @epg.program_list.sort { |a,b| a.start <=> b.start} .each { |program|
      next unless program.slot
      ch_queue[program.channel] = program.start if program.start < ch_queue[program.channel]
      slots = slots.delete_if { |item| program.slot == item && Time.now + (60 * 5) >= program.start }
    }

    is_force_3secmode = (@epg.program_list.size == 0)

    ch_queue.sort{|a, b| a <=> b }.each { |ch, next_at|
      break if slots.size <= 0

      if is_force_3secmode
        @accessor.fork() {
          save_queue(@accessor.get_epg(slots.shift, ch, 60))
        }
        next
      end

      if !@epg.fresh[ch] || @epg.fresh[ch] < Time.now
        @accessor.fork() {
          save_queue(@accessor.get_epg(slots.shift, ch, 60))
        }
#      elsif (Time.now + 60 * 4 < next_at  && Time.now + 30 > @epg.last_fresh[ch])
#        @epg.update(@accessor.get_epg(slots.shift, ch, 3))
      end

    }

#p    Process.waitall

return

#          elsif (Time.now + 30 < next_at      && Time.now + 5 >  @epg.last_fresh[ch]) ||
#                 ||
#                                                 Time.now + 60 * 4 > @epg.last_fresh[ch]
#            @epg.update(@accessor.get_epg(slots.shift, ch, 3))
#    @epg.auto_discovery
  end

end

class FabulaAccessor
  def initialize
    @slot = []
    @temporary = "./tmp"

  end

  def set_config(config_data)
    @temporary = config_data[:temporary]
    @slot = config_data[:slot]
  end

  def get_filename(ch)
    # ch が被ってて、かつ同時アクセスがあるとアウト
    # デバイスの排他制御でなんとかなるはず

    time = Time.now.strftime("%Y%m%d%H%M%S")
    ["#{@temporary}/#{ch}_#{time}.ts", "#{@temporary}/#{ch}_#{time}_epg.xml"]
  end

  def available_slot
    slots = []
    num = 0
    @slot.each { |dev|
      lock_name = "#{@temporary}/slot_#{num}"
      slots << num unless File.exists?(lock_name)
      num += 1
    }
    slots
  end


  def in_slot(num)
p "-- in slot #{num}"

    lock_name = "#{@temporary}/slot_#{num}"
    Dir.mkdir(lock_name) ? @slot[num] : false
  end

  def out_slot(num)
p "-- out slot #{num}"
    lock_name = "#{@temporary}/slot_#{num}"
    Dir.rmdir lock_name
  end

  def get_epg(slot_num, ch, sec)
print "----get_epg #{slot_num}, #{ch}, #{sec}\n"
    device = in_slot(slot_num)
p device
    unless device
      p "device busy"
      return EPG.new(EPGFromNull)
    end

    ts_name, epg_name = get_filename(ch)
    epgtemp_name = "#{epg_name}_progress"

    log = `recpt1 --device #{device} #{ch} #{sec} #{ts_name} 2>&1`
    # "using device: /dev/ptx0.t0\npid = 15485\nC/N = 27.299331dB\nRecording...\nRecorded 3sec\n"
    
    out_slot(slot_num)
    dump = `epgdump #{ch} #{ts_name} -`
    File.unlink ts_name

    # FIXME: stderr からログを取得するようにする (特に recpt1)
    # FIXME: それぞれのコマンドが失敗したら false を返すようにする

    epg = EPG.new(EPGFromEpgdump, dump)
    if sec < 30
      epg.fresh[ch] = nil
    elsif epg.fresh[ch] > Time.now + (60 * 60 * 24)
      epg.fresh[ch] = Time.now + (60 * 60 * 24)
    end

    epg
  end
end

class ControlList
  def initialize
    @control_list = []
  end

  def load_control_list
  end

  def program_mapper(program)
    program.priority = 0
    @control_list.each {|control|
      next if control['title'] != nil && Regexp.new(control['title']) !~ program.title
      next if control['desc'] != nil && Regexp.new(control['desc']) !~ program.desc
      next if control['category'] != nil && control['category'] != program.category
      next if control['channel'] != nil && control['channel'] != program.channel

      if control['time_range'] != nil
        next if control['time_range'].last <= program.start
        # FIXME: 前後両方が完全に収まってる事をチェックする


        #program.start = control['time_range'].first if program.start < control['time_range'].first
        #program.stop = control['time_range'].last if program.stop > control['time_range'].last
        # もし中途半端な時間の録画を行う場合、別アトリビュートを用意すべき
      end

      # すべてマッチしたので、priority を変更

      # 一度ブラックリスト(優先度:-1)のチェックがついてしまった場合、優先度は変更できなくなる
      next if program.priority < 0

      # blacklist or 優先度上昇
      program.priority = control['priority'] if control['priority'] < 0 || control['priority'] > program.priority
    }

    program
  end

  def add(title, desc, category, time_range, channel, priority)
    @control_list << {'title' => title, 'desc' => desc, 'category' => category, 'time_range' => time_range, 'channel' => channel, 'priority' => priority}
    self
  end

end

class Log
  def Log::output(message, level = "debug")
    File.open("fabula.log", "a") { |f|
      if message.is_a? String
        f << "#{message}\n"
      else
        f << "#{message.inspect}\n"
      end
      f.flush
    }
  end
end

def d(message, level = "debug")
  Log::output(message, level)
end





# program_list = epg.program_list.map { |program| cl.program_mapper(program)}
# FIXME map! に動作をかえる？

if $0 == __FILE__
  fabula = Fabula.new
  fabula.load_config
  fabula.load_order
  fabula.main
  fabula.save_order
end


