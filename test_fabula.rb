#! /usr/bin/env ruby

$KCODE = 'UTF8'

require 'test/unit'
require 'fabula.rb'

class TC_EPGFromEpgdump < Test::Unit::TestCase
  def test_time_from_epgdump
    
    tm = EPGFromEpgdump.time_from_epgdump("20110603024000 +0900")
    assert_equal(tm, Time.mktime(2011, 6, 3, 2, 40, 0))
  end 

  def test_initialize
    dummy_xml = <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">

<tv generator-info-name="tsEPG2xml" generator-info-url="http://localhost/">
  <channel id="C39">
    <display-name lang="ja_JP">テレビ東京１</display-name>
  </channel>
  <programme start="20110603024500 +0900" stop="20110603031500 +0900" channel="C39">
    <title lang="ja_JP">まりあほりっくあらいぶ</title>
    <desc lang="ja_JP">「早熟の婚約者」 ちょっと待って！私が主人公なのよっ！なのに…なのにこんな扱いって無いんじゃないっ！？んっ。しかもこのちんちくりん、私のこと無視しよった！</desc>
    <category lang="ja_JP">アニメ・特撮</category>
    <category lang="en">anime</category>
  </programme>
  <programme start="20110603031500 +0900" stop="20110603033000 +0900" channel="C39">
    <title lang="ja_JP">Ａ×Ａ</title>
    <desc lang="ja_JP">（ダブルエー）「フィギュアスケートＪａｐａｎ　Ｏｐｅｎ２０１１」 国と地域の威信をかけて頂点を目指すチーム戦！「フィギュアスケートＪａｐａｎ　Ｏｐｅｎ２０１１」をご紹介！日本代表の活躍の歴史を名場面とともに振り返ります！</desc>
    <category lang="ja_JP">情報</category>
    <category lang="en">information</category>
  </programme>
  <programme start="20110603033000 +0900" stop="20110603040000 +0900" channel="C39">
    <title lang="ja_JP">続　夏目友人帳第９話</title>
    <desc lang="ja_JP">「桜並木の彼」 妖（あやかし）を見ることができる少年・夏目貴志と、招き猫の姿をした妖・ニャンコ先生が繰り広げる、妖しく、切なく、そして懐かしい物語。</desc>
    <category lang="ja_JP">アニメ・特撮</category>
    <category lang="en">anime</category>
  </programme>
</tv>
EOF
    from_epgdump = EPGFromEpgdump.new(dummy_xml)
    assert_equal(from_epgdump.program_list.size, 3)
  end
end


class DummyEPG
  def initialize(opt)
  end
  def program_list
    [Program.new(
      :category => "anime", 
      :title => "ほげ", 
      :start => Time.local(2011, 6, 3, 2, 45), 
      :stop => Time.local(2011, 6, 3, 3, 15), 
      :desc => "ほげですく", 
      :channel => 'C39'
    ), Program.new(
      :category => "infomation", 
      :title => "ふが", 
      :stop => Time.local(2011, 6, 3, 3, 30), 
      :start => Time.local(2011, 6, 3, 3, 15), 
      :desc => "ふがですく", 
      :channel => 'C39'
    )]
  end

  def channel_list
    {"C39"=>"テレビ東京１"}
  end
end

class DummyEPG2
  def initialize(opt)
  end
  def program_list
    [Program.new(
      :category => "anime", 
      :title => "hoge/1", 
      :start => Time.local(2011, 6, 3, 2, 45), 
      :stop => Time.local(2011, 6, 3, 3, 0), 
      :desc => "hoge1", 
      :channel => 'C39'
    ), Program.new(
      :category => "anime", 
      :title => "hoge/2", 
      :start => Time.local(2011, 6, 3, 3, 0), 
      :stop => Time.local(2011, 6, 3, 3, 15), 
      :desc => "hoge2", 
      :channel => 'C39'
    )]
  end

  def channel_list
    {"C39"=>"テレビ東京１"}
  end
end

class DummyAccessor
  def initialize
    @epg = EPG.new(DummyEPG)
  end
  def get_epg(ch, is_short)
    @epg if ch == 'C39'
  end
  def discovery_epg(channel, is_short)
    channel.each { |ch, name|
      @epg.update(get_epg(ch, is_short))
      # FIXME: epg 取得時に失敗した場合何回かリトライしてみる？
    }

    @epg
  end
end

class DummyAccessor2
  def initialize
    @epg = EPG.new(EPGFromNull)
  end
  def get_epg(ch, is_short)
    @epg
  end
  def discovery_epg(channel, is_short)
    channel.each { |ch, name|
      @epg.update(get_epg(ch, is_short))
      # FIXME: epg 取得時に失敗した場合何回かリトライしてみる？
    }

    @epg
  end
end

class TC_EPG < Test::Unit::TestCase
  def test_program
    # 一応 dummy データに問題がない事を確認
    epg = EPG.new(DummyEPG)
    assert_equal(epg.program_list.size, 2)
    assert_equal(epg.program_list[0].category, "anime")
    assert_equal(epg.program_list[0].title, "ほげ")
    assert_equal(epg.program_list[0].start, Time.local(2011, 6, 3, 2, 45))
    assert_equal(epg.program_list[0].stop, Time.local(2011, 6, 3, 3, 15))
    assert_equal(epg.program_list[0].desc, "ほげですく")
    assert_equal(epg.program_list[0].channel, "C39")
    assert_equal(epg.program_list[1].category, "infomation")
    assert_equal(epg.program_list[1].title, "ふが")
    assert_equal(epg.program_list[1].start, Time.local(2011, 6, 3, 3, 15))
    assert_equal(epg.program_list[1].stop, Time.local(2011, 6, 3, 3, 30))
  end

  def test_update
    epg = EPG.new(DummyEPG)
    epg2 = EPG.new(DummyEPG2)
    epg.update(epg2)
    assert_equal(epg.program_list.size, 3)
    assert_equal(epg.program_list[0].category, "anime")
    assert_equal(epg.program_list[0].title, "hoge/1")
    assert_equal(epg.program_list[0].start, Time.local(2011, 6, 3, 2, 45))
    assert_equal(epg.program_list[0].stop, Time.local(2011, 6, 3, 3, 0))
    assert_equal(epg.program_list[1].category, "anime")
    assert_equal(epg.program_list[1].title, "hoge/2")
    assert_equal(epg.program_list[1].start, Time.local(2011, 6, 3, 3, 0))
    assert_equal(epg.program_list[1].stop, Time.local(2011, 6, 3, 3, 15))
    assert_equal(epg.program_list[2].category, "infomation")
    assert_equal(epg.program_list[2].title, "ふが")
    assert_equal(epg.program_list[2].start, Time.local(2011, 6, 3, 3, 15))
    assert_equal(epg.program_list[2].stop, Time.local(2011, 6, 3, 3, 30))
  end

  def test_minutely
    fabula = Fabula.new
    fabula.minutely
  end

  def test_discovery_epg
    fabula = Fabula.new
    fabula.injection_config(:channel => {'C39' => 'テレビ東京'})
    fabula.injection_accessor(DummyAccessor2)
    fabula.discovery_epg(true)
    epg = fabula.epg
    assert_equal(epg.program_list.size, 0)

    fabula = Fabula.new
    fabula.injection_config(:channel => {'C39' => 'テレビ東京'})
    fabula.injection_accessor(DummyAccessor)
    fabula.discovery_epg(true)
    epg = fabula.epg
    assert_equal(epg.program_list.size, 2)
    assert_equal(epg.program_list[0].category, "anime")
    assert_equal(epg.program_list[0].title, "ほげ")
    assert_equal(epg.program_list[0].start, Time.local(2011, 6, 3, 2, 45))
    assert_equal(epg.program_list[0].stop, Time.local(2011, 6, 3, 3, 15))
    assert_equal(epg.program_list[0].desc, "ほげですく")
    assert_equal(epg.program_list[0].channel, "C39")
    assert_equal(epg.program_list[1].category, "infomation")
    assert_equal(epg.program_list[1].title, "ふが")
    assert_equal(epg.program_list[1].start, Time.local(2011, 6, 3, 3, 15))
    assert_equal(epg.program_list[1].stop, Time.local(2011, 6, 3, 3, 30))

  end

  def test_program_map
  
    epg = EPG.new(DummyEPG)

    # タイトル一致 (完全一致)
    cl = ControlList.new.add("ほげ", nil, nil, nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_instance_of(Array, prog)
    assert_instance_of(Program, prog[0])
    assert_equal(prog[0].priority, 1)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # タイトル一致 (正規表現/部分一致)
    cl = ControlList.new.add("ほ", nil, nil, nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 1)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # タイトル一致 (正規表現)
    cl = ControlList.new.add("ふが.*", nil, nil, nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 0)
    assert_equal(prog[1].priority, 1)
    cl = nil

    # タイトル一致 (一致できない)
    cl = ControlList.new.add("ほげぼ", nil, nil, nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 0)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # 説明一致 (完全一致)
    cl = ControlList.new.add(nil, "ほげですく", nil, nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 1)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # 説明一致 (正規表現/部分一致)
    cl = ControlList.new.add(nil, "ですく", nil, nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 1)
    assert_equal(prog[1].priority, 1)
    cl = nil

    # 説明一致 (正規表現)
    cl = ControlList.new.add(nil, "ふ.*で", nil, nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 0)
    assert_equal(prog[1].priority, 1)
    cl = nil

    # カテゴリ一致
    cl = ControlList.new.add(nil, nil, "anime", nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 1)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # 時間指定 (範囲に入ってる | 入ってない)
    cl = ControlList.new.add(nil, nil, nil, Time.local(2011, 6, 3, 2, 45) ... Time.local(2011, 6, 3, 3, 15), nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 1)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # チャンネル不一致
    cl = ControlList.new.add(nil, nil, nil, nil, "C38", 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 0)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # チャンネル一致
    cl = ControlList.new.add(nil, nil, nil, nil, "C39", 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 1)
    assert_equal(prog[1].priority, 1)
    cl = nil

    # 複数指定
    cl = ControlList.new.add("ほげ", nil, nil, nil, nil, 1).add("ふが", nil, nil, nil, nil, 2)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 1)
    assert_equal(prog[1].priority, 2)
    cl = nil

    # 複数指定
    cl = ControlList.new.add("ほげ", nil, nil, nil, nil, 1).add(nil, "ほげ", nil, nil, nil, 2)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 2)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # 複数指定
    cl = ControlList.new.add("ほげ", nil, nil, nil, nil, 2).add(nil, "ほげ", nil, nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, 2)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # 複数指定
    cl = ControlList.new.add("ほげ", nil, nil, nil, nil, -1).add(nil, "ほげ", nil, nil, nil, 1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, -1)
    assert_equal(prog[1].priority, 0)
    cl = nil

    # 複数指定
    cl = ControlList.new.add("ほげ", nil, nil, nil, nil, 2).add(nil, "ほげ", nil, nil, nil, -1)
    prog = epg.program_list.map { |program| cl.program_mapper(program)}
    assert_equal(prog[0].priority, -1)
    assert_equal(prog[1].priority, 0)
    cl = nil

  end


end





















