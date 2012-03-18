#! /usr/bin/env ruby
# coding: utf-8

$KCODE = 'UTF8' if RUBY_VERSION < '1.9.0'

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

  def injection_lastfresh(ch, time)
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
    epg_updater.program_list.each { |program|
      unless channel[program.channel]
        channel[program.channel] = true

        if !@fresh[program.channel] || (epg_updater.fresh[program.channel] && @fresh[program.channel] < epg_updater.fresh[program.channel]) 
          @fresh[program.channel] = epg_updater.fresh[program.channel] 
        end
d "  #{program.channel}: @fresh = #{@fresh[program.channel]}"
      @last_fresh[program.channel] = Time.now
      end
    }
    @program_list.each { |program|
      unless channel[program.channel]
        channel[program.channel] = true 
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

    cnt_update = 0

    cnt_master = 0
    cnt_updater = 0
    new_program_list = []

    while master.size > cnt_master || updater.size > cnt_updater

      # アップデータ側にしかない
      if master.size == cnt_master || (updater.size > cnt_updater && updater[cnt_updater].stop <= master[cnt_master].start)
#        d "++#{updater[cnt_updater].start} - #{updater[cnt_updater].stop} 「#{updater[cnt_updater].title}」"

        new_program_list << updater[cnt_updater]
        cnt_update += 1
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
        info_log "#{master[cnt].channel}:#{master[cnt].start} - #{master[cnt].stop} 「#{master[cnt].title}」が削除されました"

      }

      #replace を行いつつ、上書き側の alert を出す
      (cnt_start...cnt_updater).each { |cnt|
d "+ #{updater[cnt].start} - #{updater[cnt].stop} 「#{updater[cnt].title}」"
        info_log "#{updater[cnt].channel}:#{updater[cnt].start} - #{updater[cnt].stop} 「#{updater[cnt].title}」にリプレイスされました"
        new_program_list << updater[cnt]
      }

      #FIXME: alert をもっとまともな形式にするならば、テストを書く
      #       例えば、@alert << {:start => master[cnt].start, :stop => master[cnt].stop, :title => master[cnt].title}


      # FIXME: タイトルなどデータが変わった場合なんかも更新するようにする

d "++ #{cnt_update}" if cnt_update > 0
    end

    new_program_list
  end

  def conflict_chunk_list
    program_list = @program_list.find_all{ |a| a.priority > 0}.sort { |a, b| a.start <=> b.start }
    return [program_list] if program_list.size < 2
    conflict = []

    i = 0
    begin
      if program_list[i].stop < program_list[i + 1].start
        conflict << [program_list[i]]
        next 
      end

      conflict << [program_list[i], program_list[i + 1]]
      stop_mark = program_list[i].stop >= program_list[i + 1].stop ? program_list[i].stop : program_list[i + 1].stop 
      j = i + 2
      while j <= program_list.size - 1
        break if stop_mark <= program_list[j].start
        conflict.last << program_list[j]
        stop_mark = stop_mark >= program_list[j].stop ? stop_mark : program_list[j].stop
        j += 1
      end
      conflict.last.sort! { |a, b| a.priority == b.priority ? a.start <=> b.start : b.priority <=> a.priority}
      i = j - 1
    ensure 
      i += 1
    end while i < program_list.size - 2

    while i < program_list.size
      conflict << [program_list[i]]
      i += 1
    end

    conflict
  end

  def resolve_conflict(device_number)
    channel = {}
    @conflict_cnt = 0

    return if @program_list.size == 0

    program_list = []


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

        if program.conflict
          @conflict_cnt += 1 
          program.slot = nil
        end

        program_list << program
      }
    }

    @program_list.each { |program|
      program_update = program_list.find{ |a| program.start == a.start && program.stop == a.stop && program.channel == a.channel}
      unless program_update
        program_update = program.dup
        program_update.slot = nil
        program_update.conflict = false
      end

      if program.conflict && !program_update.conflict
        info_log "録画の衝突が回避された為、録画できるようになりました #{program.channel}: #{program.title}"
        program.slot = program_update.slot
        program.conflict = program_update.conflict
      elsif !program.conflict && program_update.conflict
        info_log "録画の衝突があった為、録画できません #{program.channel}: #{program.title}"
        program.slot = nil
        program.conflict = program_update.conflict
      end
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
#      @channel_list = epgdata[:channel]
#      @fresh = epgdata[:fresh]
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

    {:channel => epg.channel_list, :program => program_a}.to_yaml
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
        next if ch != program.channel || program.stop < Time.now

        unless fresh_start 
          break if program.start > Time.now
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
    @priority = data[:priority] || 0
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
    @cl = nil
  end

  def set_watchdog(watchdog)
    @watchdog = watchdog
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

  def load_control
    @cl = ControlList.new
    @cl.load_control_list
  end

  def map_control
    @epg.program_list.map! { |program| @cl.program_mapper(program)}
  end

  def load_order
    #begin
    filename = ".order.yaml"
    FileUtils.touch(filename)

    @epg = EPG.new(EPGFromFile, IO.read(filename))
    #rescue
    #  print "-------- error\n"
    #  p $!
    #  print "-------- error\n"
    #end
  end

  def save_order
    File.open(".order.yaml", "w") { |f|
      f << EPGToFile.to_yaml(@epg)
    }
  end

  def save_queue(epg)
    epg
  end

  def load_queue
  end

  def load_epgdump
    Dir.glob("#{@accessor.temporary}/epg_*.ts") { |ts_name|
      /epg_([^_]+)_([^_]+)_([^_]+).ts/ =~ ts_name
      ch = $1
      sec = $3.to_i

      dump = `epgdump #{ch} #{ts_name} -`
      File.unlink ts_name

      epg = EPG.new(EPGFromEpgdump, dump)
      if epg.program_list.size == 0
d "! EPG broken"
        next
      end

      if sec < 30
        epg.fresh[ch] = nil
      elsif epg.fresh[ch] && epg.fresh[ch] > Time.now + (60 * 60 * 4)
        epg.fresh[ch] = Time.now + (60 * 60 * 4)
      end
d "  load_epgdump #{ch} #{sec} : #{epg.fresh[ch]}"
      @epg.update(epg)
    }
  end

  def main_loop
#d "**start"
	fabula_start = Time.now
    is_record_near = true
#d Time.now
    while @accessor.waitall_non_blocking || is_record_near || Time.now < fabula_start + 60 * 60 * 24
#d "main_loop: #{Time.now}"
      load_epgdump
      map_control
      @epg.resolve_conflict(@accessor.number_slot)
      save_order
      is_record_near = main

      @watchdog.update
      sleep(3)
    end

#d "end"
  end

  def main

#d "---- main"
    # EPG プログラムリストが空ならば、3秒リフレッシュの準備
    if @epg.program_list.size == 0
      @channel.each { |ch, name|
        @epg.fresh[ch] = Time.now + 60
        @epg.last_fresh[ch] = Time.now - 60 * 10
      }
    end

    # まず切羽詰ってる順に割り出す
    ch_neartime = {}
    @channel.each { |ch, name|
      ch_neartime[ch] = Time.now + (60 * 60 * 4)
    }
	is_record_near = false

    @epg.program_list.sort { |a,b| a.start <=> b.start} .each { |program|
      next unless program.slot
      if Time.now >= program.start - 60 * 3 && Time.now < program.stop - 60 * 1
        # 3分前～録画中なので録画モードに入る (開始前ならsleep で準備される)

        @accessor.record(program)
        ch_neartime.delete(program.channel)
        is_record_near = true
      elsif Time.now >= program.start - 60 * 5 && Time.now < program.stop
        # 5分以内の場合でも安全の為に EPG 取得モードには入らないようにする
        ch_neartime.delete(program.channel)
        @accessor.reserve_slot(program.slot)
        is_record_near = true
      else
        ch_neartime[program.channel] = program.start if ch_neartime[program.channel] == nil || program.start < ch_neartime[program.channel]
        is_record_near = true if Time.now >= program.start - 60 * 30 && Time.now < program.stop
      end
    }

    ch_neartime.sort{|a, b| a <=> b }.each { |ch, next_at|
      # 切羽詰まってる順で EPG 取得処理を行う

      # そもそも録画スロットに空きがなければ処理しない
      break if @accessor.available_slot.size <= 0

      if !@epg.fresh[ch] || @epg.fresh[ch] < Time.now
        @accessor.get_epg(ch, 60)
      elsif Time.now > @epg.last_fresh[ch] + 60 * 5
        @accessor.get_epg(ch, 3)
      end
    }

#d "---- main end"
  
    is_record_near
  end
end

class FabulaAccessor
  attr_reader :temporary

  def initialize
    @device = []
    @slot = []
    @pid = []
    @temporary = "./tmp"
  end

  def set_config(config_data)
    @temporary = config_data[:temporary]
    @recording = config_data[:recording]
    @device = config_data[:slot]
    @slot = Array.new(@device.size)
  end

  def number_slot
    @slot.size
  end


  def available_slot
    slots = []
    num = 0
    @slot.each { |status|
      slots << num unless status
      num += 1
    }
#d "available_slot #{slots.size}"
    slots
  end

  def waitall_non_blocking
#d "waitall"
    is_need_wait = false
    (0...@device.size).each { |slot_num|
#d "waitpid: #{slot_num}, #{@pid[slot_num]}"
      next unless @pid[slot_num]

      begin 
        if Process.waitpid(@pid[slot_num], Process::WNOHANG | Process::WUNTRACED) == nil
          is_need_wait = true
        else
d "-#{@pid[slot_num]} #{slot_num}, #{@slot[slot_num]} end"
          @pid[slot_num] = nil
          @slot[slot_num] = nil
        end
      rescue Errno::ECHILD
d "-#{@pid[slot_num]}: #{slot_num}, #{@slot[slot_num]} is not found"
        @pid[slot_num] = nil
        @slot[slot_num] = nil
      end
    }
    is_need_wait
  end

  def reserve_slot(slot)
    unless @slot[slot]
      @slot[slot] = :reserve 
    end
  end

  def fork(slot_num, using, &proc)
    return if @slot.find { |u| u == using}

    if @pid[slot_num]
d "! #{@pid[slot_num]} is stil running  / #{slot_num} '#{using}'"
      return
    end

    @slot[slot_num] = using
    pid = Process::fork
    if pid
d "+#{pid} #{slot_num} '#{using}' fork"
      @pid[slot_num] = pid
    else
      proc.call
      exit
    end
  end

  def execute(cmd)
    lockdir = "#{@temporary}/ptxlock"
    begin 
      Dir.mkdir lockdir
    rescue Errno::EEXIST
      sleep 1
      cnt += 1
      if cnt > 15
        d "! lock failed"
        if Time.now > File.mtime(lockdir) + 15 && Dir.rmdir(lockdir)
          d "! delete lockdir"
        end
      end
      retry
    end

    sleep 3
    begin
      Dir.rmdir lockdir
    rescue Errno::EXXX
      d "! already lockdir deleted"
    end
    cnt = 0
  end

  def wait_channel(slot_num)
    roundsec = @device.size * 2

    tm = Time.now
    next_sec = tm.sec + roundsec - (tm.sec+ slot_num * 2) % roundsec
    sleep(next_sec.to_f - (tm.sec + tm.usec.to_f / (1000 * 1000)))
  end

  def record(program)
#d "rec"
    slot_num = program.slot
    device = @device[program.slot]
    ch = program.channel

    fork(slot_num, "rec_#{program.channel}") {
      starttime = program.start.strftime("%Y%m%d%H%M")

      if Time.now > program.start
        # 既に録画時間が始まってしまっている
        ts_name = "#{@recording}/#{starttime}_#{ch}_#{program.title}_※.ts"
        info_log "#{program.start} - #{program.stop} 「#{program.title}」録画開始(部分録画)"
d "!partial"
      else
        ts_name = "#{@recording}/#{starttime}_#{ch}_#{program.title}.ts"
        info_log "#{program.start} - #{program.stop} 「#{program.title}」録画開始"
        sleep(program.start - Time.now - 15) if Time.now < program.start - 15
      end
    wait_channel(slot_num) # slot_num と時間による排他制御 (2秒間隔)
    recsec = Integer(program.stop - Time.now - 15)

d " #{Process.pid} ++++recording #{slot_num} #{ch}, #{recsec} use #{device} #{program.start} - #{program.stop} 「#{program.title}」"
      cmd = "recpt1 --b25 --strip --sid hd --device #{device} #{ch} #{recsec} #{ts_name} 2>&1"
#d cmd
      log = `#{cmd}`
      if /pid = (\d+)\nC\/N = (\d+.\d+)dB\nRecording...\nRecorded (\d+)sec/ =~ log
        d " succeeded"
        d " pid: #{$1}"
        d " #{$2} dB"
        d " #{$3} sec"
      else
        d log.inspect
      end

      # "using device: /dev/ptx0.t0\npid = 15485\nC/N = 27.299331dB\nRecording...\nRecorded 3sec\n"
d " #{Process.pid} ---- recording end #{slot_num} #{ch}, #{recsec}  use #{device}"
        info_log "#{program.start} - #{program.stop} 「#{program.title}」録画終了"
      exit
    }
  end

  def get_epg(ch, sec)
    slots = available_slot

    if slots.size == 0
d "! slot が取得できなかった"
      return
    end

    slot_num = slots[0]
    fork(slot_num, "epg_#{ch}") {
      device = @device[slot_num]

      starttime = Time.now.strftime("%Y%m%d%H%M%S")
      ts_name = "#{@temporary}/epg_#{ch}_#{starttime}_#{sec}.ts"

      wait_channel(slot_num) # slot_num と時間による排他制御 (2秒間隔)

d " #{Process.pid} ++++ get_epg #{slot_num}, #{ch}, #{sec}  use #{device}"
      log = `recpt1 --device #{device} #{ch} #{sec} #{ts_name}_now 2>&1`
      if /Cannot tune to the specified channel/ =~ log
#        d "この時間帯はEPGを取得できません"
        exit
      elsif /pid = (\d+)\nC\/N = (\d+.\d+)dB\nRecording...\nRecorded (\d+)sec/ =~ log
        d " succeeded"
        d " pid: #{$1}"
        d " #{$2} dB"
        d " #{$3} sec"
      else
        d log.inspect
      end
#d log
      # "using device: /dev/ptx0.t0\npid = 15485\nC/N = 27.299331dB\nRecording...\nRecorded 3sec\n"
      # "using device: dev/ptx0.t0\npid = 3000\nCannot open tuner device: dev/ptx0.t0\n"

      File.rename("#{ts_name}_now", ts_name)
d " #{Process.pid} ---- get_epg end #{slot_num} #{ch}, #{sec}  use #{device}"
      exit
    }
  end
end

class ControlList
  def initialize
    @control_list = []
  end

  def load_control_list
    @control_list = YAML.load(IO.read('.control.yaml'))
  end

  def program_mapper(program_old)
    program = program_old.dup
    @control_list.each {|control|
      next if control[:title] != nil && Regexp.new(control[:title]) !~ program.title
      next if control[:desc] != nil && Regexp.new(control[:desc]) !~ program.desc
      next if control[:category] != nil && control[:category] != program.category
      next if control[:channel] != nil && control[:channel] != program.channel

      if control[:time_range] != nil
        next if control[:time_range].last <= program.start
        # FIXME: 前後両方が完全に収まってる事をチェックする


        #program.start = control['time_range'].first if program.start < control['time_range'].first
        #program.stop = control['time_range'].last if program.stop > control['time_range'].last
        # もし中途半端な時間の録画を行う場合、別アトリビュートを用意すべき
      end

      # すべてマッチしたので、priority を変更

      # 一度ブラックリスト(優先度:-1)のチェックがついてしまった場合、優先度は変更できなくなる
      next if program.priority < 0 || program.priority == control[:priority]

      # blacklist or 優先度上昇
      program.priority = control[:priority] if control[:priority] < 0 || control[:priority] > program.priority
#d "#{program.channel}: #{program.start} - #{program.stop}: #{program.title} priority: #{program.priority}"
    }

#    if (program_old.priority == nil || program_old.priority <= 0) && program.priority > 0
#      info_log " +#{program.channel}: 「#{program.title}」を録画します"
#    elsif (program_old.priority != nil && program_old.priority > 0 && program.priority <= 0
#      info_log " -#{program.channel}: 「#{program.title}」を録画解除します"
#      d "!! 現状の仕組みでは発生しないはず？番組が何かデータ更新された？"
#    end
    if program_old.priority <= 0 && program.priority > 0
      info_log " +#{program.channel}: #{program.start}-#{program.stop}「#{program.title}」を録画します"
    elsif program_old.priority > 0 && program.priority <= 0
      info_log " -#{program.channel}: 「#{program.title}」を録画解除します"
      d "!! 現状の仕組みでは発生しないはず？番組が何かデータ更新された？"
    end

    program
  end

  def add(title, desc, category, time_range, channel, priority)
    @control_list << {:title => title, :desc => desc, :category => category, :time_range => time_range, :channel => channel, :priority => priority || 0}
    self
  end

end

class FabulaLoggerFile
  def output(message, level = :debug)
    File.open("fabula.log", "a") { |f|
      tm = Time.now
      f << sprintf("%s.%08d  ", tm.strftime('%Y/%m/%d %H:%M:%S'), tm.usec)

      if message.is_a? String
        f << "#{message}\n"
      else
        f << "#{message.inspect}\n"
      end
      #f << "#{caller[0]}\n"
      f.flush
    }

    if level == :info
      File.open("fabula_user.log", "a") { |f|
      tm = Time.now
      f << sprintf("%s.%08d  ", tm.strftime('%Y/%m/%d %H:%M:%S'), tm.usec)

        if message.is_a? String
          f << "#{message}\n"
        else
          f << "#{message.inspect}\n"
        end
        #f << "#{caller[0]}\n"
        f.flush
      }
    end

  end
end

class FabulaLoggerFluent
  def initialize
    require 'fluent-logger'

    @log = Fluent::Logger::FluentLogger.new('Fabula')
  end

  def output(message, level = :debug)
    @log.post(level.to_s, message)
  end
end


class Logger
  @@logger = nil

  def Logger::config(option)
    if option[:is_fluent]
      @@logger = FabulaLoggerFluent.new
    else
      @@logger = FabulaLoggerFile.new
    end
  end

  def Logger::output(message, level = :debug)
    @@logger.output(message, level)
  end
end

def d(message, level = :debug)
  Logger::output(message, level)
end

def info_log(message)
  Logger::output(message, :info)
end

class WatchDog
  def initialize(tmpdir)
    @tmpdir = tmpdir
    begin
      Dir.mkdir tmpdir
    rescue Errno::EEXIST
      mtime = File.mtime tmpdir
      if Time.now <= mtime + 60
        # まだ実行中
        exit
      else
        Dir.glob("#{tmpdir}/*.pid") { |f|
          /(\d+).pid$/ =~ f
          begin 
            Process.kill(:KILL, $1.to_i)
          rescue Errno::ESRCH
            # 既にそのプロセスは無かった
          end

          File.unlink(f)
        }
      end

      Dir.rmdir tmpdir
      puts "retry"
      retry
    end
  end

  def update
    FileUtils.touch [@tmpdir, "#{@tmpdir}/#{Process.pid}.pid"]
  end

  def fin
    unlink("#{@tmpdir}/#{Process.pid}.pid")
    unlink(@tmpdir)
  end
end

# program_list = epg.program_list.map { |program| cl.program_mapper(program)}
# FIXME map! に動作をかえる？

if $0 == __FILE__
  require 'optparse'
  option = {:interface => :yaml}
  OptionParser.new do |op|
    op.on('-L', '--fluent-logger') {|v| option[:is_fluent] = true}
    #op.on('-y', '--yaml') {|v| option[:interface] = :yaml}
    #op.on('-m', '--mongodb') {|v| option[:interface] = :mongodb}
    op.parse!(ARGV)
  end

  watchdog = WatchDog.new("tmp/fabula")
  Logger.config(option)

  info_log "fabula start #{Time.now}"

  fabula = Fabula.new
  fabula.set_watchdog(watchdog)
  fabula.load_config
  fabula.load_order
  fabula.load_control
  fabula.main_loop
  info_log "fabula end #{Time.now}"
end


