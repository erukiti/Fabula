#! /usr/bin/env ruby -Ku

$KCODE = 'UTF8'

require 'test/unit'
require 'epg.rb'

class TC_EPGFromEpgdump < Test::Unit::TestCase
  def test_time_from_epgdump
    
    tm = EPGFromEpgdump.time_from_epgdump("20110603024000 +0900")
    assert_equal(tm, Time.mktime(2011, 6, 3, 2, 40, 0))
  end 

  def test_initialize
    # FIXME: 必要になれば、EPGFromEpgdump のテストを書く
  
  end
  

end

class DummyEPG
  def initialize(opt)
  end
  def program
    {"C39" => [
      {"category" => "anime", "title" => "ほげ", "stop" => Time.local(2011, 6, 3, 3, 15), "start" => Time.local(2011,6,3,2,45), "desc" => "ほげですく", 'channel' => 'C39'},
      {"category" => "infomation", "title" => "ふが", "stop" => Time.local(2011, 6, 3, 3, 30), "start" => Time.local(2011,6,3,3,15), "desc" => "ふがですく", 'channel' => 'C39'},
    ]}
  end

  def channel
    {"C39"=>"テレビ東京１"}
  end

end

class TC_EPG < Test::Unit::TestCase
  def test_program
    epg = EPG.new(DummyEPG, "")

    assert_equal(epg.program, 
      {"C39" => [
        {"category" => "anime", "title" => "ほげ", "stop" => Time.local(2011, 6, 3, 3, 15), "start" => Time.local(2011,6,3,2,45), "desc" => "ほげですく", 'channel' => 'C39'},
        {"category" => "infomation", "title" => "ふが", "stop" => Time.local(2011, 6, 3, 3, 30), "start" => Time.local(2011,6,3,3,15), "desc" => "ふがですく", 'channel' => 'C39'},
      ]}
	)
  end

  def test_channel
    epg = EPG.new(DummyEPG, "")

    assert_equal(epg.channel, {"C39"=>"テレビ東京１"})
  end



end


#    - title (正規表現)
#    - desc
#    - チャンネル (数字 or array)
#    - ジャンル
#    - 時間
#    - 優先度

class TC_ControlList < Test::Unit::TestCase
  def test_match
    epg = EPG.new(DummyEPG, "")

    # タイトル一致 (完全一致)
    cl = ControlList.new
    cl.add("ほげ", nil, nil, nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 1)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

    # タイトル一致 (正規表現/部分一致)
    cl = ControlList.new
    cl.add("ほ", nil, nil, nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 1)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

    # タイトル一致 (正規表現)
    cl = ControlList.new
    cl.add("ふが.*", nil, nil, nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 0)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 1)
    cl = nil

    # タイトル一致 (一致できない)
    cl = ControlList.new
    cl.add("ほげぼ", nil, nil, nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 0)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

    # 説明一致 (完全一致)
    cl = ControlList.new
    cl.add(nil, "ほげですく", nil, nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 1)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

    # 説明一致 (正規表現/部分一致)
    cl = ControlList.new
    cl.add(nil, "ですく", nil, nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 1)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 1)
    cl = nil

    # 説明一致 (正規表現)
    cl = ControlList.new
    cl.add(nil, "ふ.*で", nil, nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 0)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 1)
    cl = nil

    # カテゴリ一致
    cl = ControlList.new
    cl.add(nil, nil, "anime", nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 1)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

    # 時間指定 (範囲に入ってる | 入ってない)
    cl = ControlList.new
    cl.add(nil, nil, nil, Time.local(2011, 6, 3, 2, 45) ... Time.local(2011, 6, 3, 3, 15), nil, 1)
    result0 = cl.match(epg.program['C39'][0])
    result1 = cl.match(epg.program['C39'][1])
	assert_equal(result0['priority'], 1)
	assert_equal(result1['priority'], 0)

    # 時間指定 (微妙に入っている) → 時間範囲指定で start/stop の時間を補正する
    cl = ControlList.new
    cl.add(nil, nil, nil, Time.local(2011, 6, 3, 3, 10) ... Time.local(2011, 6, 3, 3, 20), nil, 1)
    result0 = cl.match(epg.program['C39'][0])
    result1 = cl.match(epg.program['C39'][1])
	assert_equal(result0['priority'], 1)
	assert_equal(result1['priority'], 1)
	assert_equal(result0['start'], Time.local(2011,6,3,3,10))
	assert_equal(result0['stop'], Time.local(2011,6,3,3,15))
	assert_equal(result1['start'], Time.local(2011,6,3,3,15))
	assert_equal(result1['stop'], Time.local(2011,6,3,3,20))

    # チャンネル不一致
    cl = ControlList.new
    cl.add(nil, nil, nil, nil, "C38", 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 0)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

    # チャンネル一致
    cl = ControlList.new
    cl.add(nil, nil, nil, nil, "C39", 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 1)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 1)
    cl = nil

    # 複数指定
    cl = ControlList.new
    cl.add("ほげ", nil, nil, nil, nil, 1)
    cl.add("ふが", nil, nil, nil, nil, 2)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 1)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 2)
    cl = nil

    # 複数指定
    cl = ControlList.new
    cl.add("ほげ", nil, nil, nil, nil, 1)
    cl.add(nil, "ほげ", nil, nil, nil, 2)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 2)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

    # 複数指定
    cl = ControlList.new
    cl.add("ほげ", nil, nil, nil, nil, 2)
    cl.add(nil, "ほげ", nil, nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], 2)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

    # 複数指定
    cl = ControlList.new
    cl.add("ほげ", nil, nil, nil, nil, -1)
    cl.add(nil, "ほげ", nil, nil, nil, 1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], -1)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

    # 複数指定
    cl = ControlList.new
    cl.add("ほげ", nil, nil, nil, nil, 2)
    cl.add(nil, "ほげ", nil, nil, nil, -1)
	assert_equal(cl.match(epg.program['C39'][0])['priority'], -1)
	assert_equal(cl.match(epg.program['C39'][1])['priority'], 0)
    cl = nil

  end
end

# FIXME:
# カテゴリやチャンネルで、複数指定可能にする
# 文字列マッチングを、複数指定できるようにする
# 時間レンジを ... でやってるけど、これどうしよう？

class TC_Program < Test::Unit::TestCase
  def test_check

    # 非衝突 (時間連続)
    prog = Program.new([
      {"title" => "1", "start" => Time.local(2011,6, 3, 2, 45), "stop" => Time.local(2011, 6, 3, 3, 15), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "2", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 45), 'channel' => 'C39' ,'priority' => 1},
    ])
    prog.check 1
    assert_equal(prog.conflict?, false)

    resolved = prog.resolved
    assert_equal(resolved.find{|a| a['title'] == "1"}['conflicted'], nil)
    assert_equal(resolved.find{|a| a['title'] == "2"}['conflicted'], nil)

    prog = Program.new([
      {"title" => "1", "start" => Time.local(2011,6, 3, 2, 45), "stop" => Time.local(2011, 6, 3, 3, 15), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "2", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 45), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "3", "start" => Time.local(2011,6, 3, 3,  5), "stop" => Time.local(2011, 6, 3, 3, 20), 'channel' => 'C38' ,'priority' => 1},
#      {"title" => "2", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 30), 'channel' => 'C37' ,'priority' => 1},
    ])
    prog.check 1
    assert_equal(prog.conflict?, true)

    resolved = prog.resolved
    assert_equal(resolved.find{|a| a['title'] == "1"}['conflicted'], nil)
    assert_equal(resolved.find{|a| a['title'] == "2"}['conflicted'], nil)
    assert_equal(resolved.find{|a| a['title'] == "3"}['conflicted'], true)

    prog = Program.new([
      {"title" => "1", "start" => Time.local(2011,6, 3, 2, 45), "stop" => Time.local(2011, 6, 3, 3, 15), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "2", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 45), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "3", "start" => Time.local(2011,6, 3, 3,  5), "stop" => Time.local(2011, 6, 3, 3, 20), 'channel' => 'C38' ,'priority' => 1},
      {"title" => "4", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 30), 'channel' => 'C37' ,'priority' => 1},
    ])
    prog.check 1
    assert_equal(prog.conflict?, true)

    resolved = prog.resolved
    assert_equal(resolved.find{|a| a['title'] == "1"}['conflicted'], nil)
    assert_equal(resolved.find{|a| a['title'] == "2"}['conflicted'], nil)
    assert_equal(resolved.find{|a| a['title'] == "3"}['conflicted'], true)
    assert_equal(resolved.find{|a| a['title'] == "4"}['conflicted'], true)

    prog = Program.new([
      {"title" => "1", "start" => Time.local(2011,6, 3, 2, 45), "stop" => Time.local(2011, 6, 3, 3, 15), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "2", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 45), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "3", "start" => Time.local(2011,6, 3, 3,  5), "stop" => Time.local(2011, 6, 3, 3, 20), 'channel' => 'C38' ,'priority' => 1},
#      {"title" => "2", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 30), 'channel' => 'C37' ,'priority' => 1},
    ])
    prog.check 2
    assert_equal(prog.conflict?, false)

    prog = Program.new([
      {"title" => "1", "start" => Time.local(2011,6, 3, 2, 45), "stop" => Time.local(2011, 6, 3, 3, 15), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "2", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 45), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "3", "start" => Time.local(2011,6, 3, 3,  5), "stop" => Time.local(2011, 6, 3, 3, 20), 'channel' => 'C38' ,'priority' => 1},
      {"title" => "4", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 30), 'channel' => 'C37' ,'priority' => 1},
    ])
    prog.check 2
    assert_equal(prog.conflict?, true)

    resolved = prog.resolved
    assert_equal(resolved.find{|a| a['title'] == "1"}['conflicted'], nil)
    assert_equal(resolved.find{|a| a['title'] == "2"}['conflicted'], nil)
    assert_equal(resolved.find{|a| a['title'] == "3"}['conflicted'], nil)
    assert_equal(resolved.find{|a| a['title'] == "4"}['conflicted'], true)

    prog = Program.new([
      {"title" => "1", "start" => Time.local(2011,6, 3, 2, 45), "stop" => Time.local(2011, 6, 3, 3, 15), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "2", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 45), 'channel' => 'C39' ,'priority' => 1},
      {"title" => "3", "start" => Time.local(2011,6, 3, 3,  5), "stop" => Time.local(2011, 6, 3, 3, 20), 'channel' => 'C38' ,'priority' => 1},
      {"title" => "2", "start" => Time.local(2011,6, 3, 3, 15), "stop" => Time.local(2011, 6, 3, 3, 30), 'channel' => 'C37' ,'priority' => 1},
    ])
    prog.check 3
    assert_equal(prog.conflict?, false)

  end

end



