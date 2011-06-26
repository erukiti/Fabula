#! /usr/bin/env ruby

$KCODE = 'UTF8'

require 'rexml/document'
require 'yaml'
require 'fileutils'

class EPG
  attr_reader :program_list
  attr_reader :channel_list
  attr_accessor :fresh

  def initialize(initializer, opt = nil)
    init = initializer.new(opt)
    @program_list = init.program_list
    @channel_list = init.channel_list
    @fresh = init.fresh
    @alert = []
  end

  def update(epg_updater)
    channel = {}
    @program_list.each { |program|
      channel[program.channel] = true unless channel[program.channel]
    }
    epg_updater.program_list.each { |program|
      unless channel[program.channel]
        channel[program.channel] = true
        @fresh[program.channel] = epg_updater.fresh[program.channel] || @fresh[program.channel]
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
        @alert << "++#{updater[cnt_updater].start} - #{updater[cnt_updater].stop} 「#{updater[cnt_updater].title}」"

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
        @alert << "- #{master[cnt].start} - #{master[cnt].stop} 「#{master[cnt].title}」"
      }

      #replace を行いつつ、上書き側の alert を出す
      (cnt_start...cnt_updater).each { |cnt|
        @alert << "+ #{updater[cnt].start} - #{updater[cnt].stop} 「#{updater[cnt].title}」"
        new_program_list << updater[cnt]
      }

      #FIXME: alert をもっとまともな形式にするならば、テストを書く
      #       例えば、@alert << {:start => master[cnt].start, :stop => master[cnt].stop, :title => master[cnt].title}


      # FIXME: タイトルなどデータが変わった場合なんかも更新するようにする

    end

    new_program_list
  end

  def alert
    @alert
  end

  def alert_clear
    @alert = []
  end

  def resolve_conflict(device_number)
    channel = {}

    @program_list.sort! { |a, b| a.start <=> b.start }
    @conflict = []
    @conflict_cnt = 0
    may_conflict_cnt = 0

    i = 0
    begin
#print "====\n#{i}: #{@program_list[i]['title']}\n"
#print "#{@program_list[i]['stop']},  #{@program_list[i + 1]['start']}\n"
      next if @program_list[i].stop <= @program_list[i + 1].start

# FIXME: conflict してなおかつチャンネルが矛盾してるデータがないか調べる
      # confilict している可能性のある塊の検出
#print "conflict #{i + 1}\n"
      @conflict[may_conflict_cnt] = [@program_list[i], @program_list[i + 1]]
      mark = @program_list[i].stop >= @program_list[i + 1].stop ? @program_list[i].stop : @program_list[i + 1].stop 
      j = i + 2
      while j <= @program_list.size - 1
#print "#{j}: #{@program_list[j]['title']}\n"
#print "#{mark}, #{@program_list[j]['start']}\n"
        break if mark <= @program_list[j].start
#print "conflict #{j}\n"
        @conflict[may_conflict_cnt] << @program_list[j]
        mark = mark >= @program_list[j].stop ? mark : @program_list[j].stop
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
        for i in 0 ... device_number
#print "ch: #{i}\n"
#print "slot: #{slot[i].inspect}\n"
          if slot[i] == nil || slot[i] <= program.start
#print "into: #{i}\n"
            slot[i] = program.stop
#print "*slot: #{slot[i].inspect}\n"
            is_conflict = false
            program.slot = i
            break
          end
        end
        if is_conflict
#print "conflict: #{program['title']}\n"
          @conflict_cnt += 1 
          program.conflict = true
        end
      }
    }
  end

  def conflict?
#p @conflict
    @conflict_cnt > 0

  end

  def auto_discovery
    @channel_list.each { |ch, name|
      next if @fresh[ch] && Time.now < @fresh[ch]
      @program_list << Program.new(:title => "EPG取得", :start => Time.now, :stop => Time.now + 60, :channel => ch, :epgdump => true)
    }
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
        next if ch != program.channel

        unless fresh_start
          fresh_start = program.start 
          fresh_end = program.stop
        else
          break if fresh_start && program.start > fresh_end
          fresh_end = program.stop
        end
      }

      @fresh[ch] = fresh_end if fresh_start < Time.now
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

    @slot = nil
    @conflict = false
  #  @priority = nil
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

  def injection_accessor(accessor, opt)
    @accessor = accessor.new(opt)
  end

  def injection_config(config)
    @channel = config[:channel]
    @temporary = config[:temporary]
    #slot 
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

  def load_epgdump
    Dir.glob("#{@accessor.temporary}/*_epg.xml") { |filename|
print "!epgdump file: #{filename}\n"
    }
  end

  def minutely
    load_config
    load_order
    discovery_epg 3
    @epg.auto_discovery
    save_order
  end

  # EPG クラスに移す？
  def discovery_epg(sec = 3)
    slot_num = 0 # 0固定
    @channel.each { |ch, name|
      @epg.update(@accessor.discovery_epg(slot_num, ch, sec)) # discovery して update を行う
    }

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

  def in_slot(num)
p "-- in slot #{num}"

    lock_name = "#{@temporary}/slot_#{num}"
    if Dir.mkdir(lock_name)
      @slot[num]
    else
      false
    end
  end

  def out_slot(num)
p "-- out slot #{num}"
    lock_name = "#{@temporary}/slot_#{num}"
    Dir.rmdir lock_name
  end

  def get_epg(slot_num, ch, sec)
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
      epg.fresh[ch] = Time.now - 1
    elsif epg.fresh[ch] > Time.now + (60 * 60 * 24)
      epg.fresh[ch] = Time.now + (60 * 60 * 24)
    end
    
    
p epg.fresh[ch]

    epg
  end

  def discovery_epg(slot_num, ch, sec)
print "----discovery\n"
    epg = EPG.new(EPGFromNull)

    epg.update(get_epg(slot_num, ch, sec))
      # FIXME: epg 取得時に失敗した場合何回かリトライしてみる？

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

# program_list = epg.program_list.map { |program| cl.program_mapper(program)}
# FIXME map! に動作をかえる？

if $0 == __FILE__
  fabula = Fabula.new
  fabula.minutely
end

