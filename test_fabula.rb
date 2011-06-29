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
    # 実時間よりもはるかに前のデータの場合
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
    assert_nil(from_epgdump.fresh['C39'])

    # 期間中。fresh が正常な場合

    y2 = Time.now.year + 1

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
  <programme start="20110603031500 +0900" stop="#{y2}0703033000 +0900" channel="C39">
    <title lang="ja_JP">Ａ×Ａ</title>
    <desc lang="ja_JP">（ダブルエー）「フィギュアスケートＪａｐａｎ　Ｏｐｅｎ２０１１」 国と地域の威信をかけて頂点を目指すチーム戦！「フィギュアスケートＪａｐａｎ　Ｏｐｅｎ２０１１」をご紹介！日本代表の活躍の歴史を名場面とともに振り返ります！</desc>
    <category lang="ja_JP">情報</category>
    <category lang="en">information</category>
  </programme>
  <programme start="#{y2}0703033030 +0900" stop="#{y2}0703040000 +0900" channel="C39">
    <title lang="ja_JP">続　夏目友人帳第９話</title>
    <desc lang="ja_JP">「桜並木の彼」 妖（あやかし）を見ることができる少年・夏目貴志と、招き猫の姿をした妖・ニャンコ先生が繰り広げる、妖しく、切なく、そして懐かしい物語。</desc>
    <category lang="ja_JP">アニメ・特撮</category>
    <category lang="en">anime</category>
  </programme>
</tv>
EOF
    # 一つ目と二つ目は連続していて、一つ目は現在よりも過去。二つ目は現在よりも未来
    # 三つ目は、二つ目とは連続していないので、fresh は二つ目の最後と同一になる

    from_epgdump = EPGFromEpgdump.new(dummy_xml)
    assert_equal(from_epgdump.program_list.size, 3)
    assert_equal(from_epgdump.fresh['C39'], Time.local(y2, 7, 3 , 3, 30))

    #現在のデータが含まれていない場合
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
  <programme start="20210603031500 +0900" stop="20210703033000 +0900" channel="C39">
    <title lang="ja_JP">Ａ×Ａ</title>
    <desc lang="ja_JP">（ダブルエー）「フィギュアスケートＪａｐａｎ　Ｏｐｅｎ２０１１」 国と地域の威信をかけて頂点を目指すチーム戦！「フィギュアスケートＪａｐａｎ　Ｏｐｅｎ２０１１」をご紹介！日本代表の活躍の歴史を名場面とともに振り返ります！</desc>
    <category lang="ja_JP">情報</category>
    <category lang="en">information</category>
  </programme>
  <programme start="20210703033030 +0900" stop="20210703040000 +0900" channel="C39">
    <title lang="ja_JP">続　夏目友人帳第９話</title>
    <desc lang="ja_JP">「桜並木の彼」 妖（あやかし）を見ることができる少年・夏目貴志と、招き猫の姿をした妖・ニャンコ先生が繰り広げる、妖しく、切なく、そして懐かしい物語。</desc>
    <category lang="ja_JP">アニメ・特撮</category>
    <category lang="en">anime</category>
  </programme>
</tv>
EOF
    #ひとつ目は現在より過去のもの。二つ目以降は未来のもの(2021年まではこのテストが有効)

    from_epgdump = EPGFromEpgdump.new(dummy_xml)
    assert_equal(from_epgdump.program_list.size, 3)
    assert_equal(from_epgdump.fresh['C39'], nil)


return



  end
end


class DummyEPG
  attr_reader :program_list
  attr_reader :channel_list
  attr_reader :fresh

  def initialize(opt)
    @program_list = []
    @channel_list = {}
    @fresh = {}
    opt.each { |data|
      if data[:fresh]
        @fresh[data[:channel]] = data[:fresh]
        next
      end

      program = Program.new(data)
      @program_list << program

      @channel_list["C39"] = "テレビ東京１" if program.channel == "C39"
      @channel_list["C47"] = "東京ＭＸ" if program.channel == "C47"
    }

    @channel_list["C39"] = "テレビ東京１" if @channel_list.size == 0
  end
end

class DummyAccessor
  def initialize(opt)
    @epg = []
    @opt = opt
    $fork = []
  end
  def get_epg(ch, sec)
    EPG.new(DummyEPG, [{:title => "GETEPG_#{ch}_#{sec}", :channel => ch}])
  end
  def record(program)
    "#{program.start} - #{program.stop}: #{program.title} "
  end

  def available_slot
    @opt
  end
  def fork(program = nil, &proc)
    $fork << proc.call
    # FIXME: $fork ってのはさすがにヒドイので別の手段を考える？
  end

end


class TC_EPG < Test::Unit::TestCase
  def test_update
    #
    epg = EPG.new(DummyEPG, [
      {:title => 'M0',  :start => Time.local(2011, 6, 14, 23, 30), :stop => Time.local(2011, 6, 15, 0, 0), :channel => "C39"},
    ])
    epg2 = EPG.new(DummyEPG, [
      {:title => 'C1',  :start => Time.local(2011, 6, 14, 23, 0),  :stop => Time.local(2011, 6, 14, 23, 30), :channel => "C39"},
      {:title => 'C2',  :start => Time.local(2011, 6, 14, 23, 30), :stop => Time.local(2011, 6, 15, 0, 0), :channel => "C39"},
      {:title => 'C3',  :start => Time.local(2011, 6, 15, 10, 0),  :stop => Time.local(2011, 6, 15, 10, 30), :channel => "C39"},
    ])

    epg.update(epg2)
    assert_equal(epg.program_list.size, 3)
    assert_equal(epg.program_list.find{ |a| a.title == "C1"}.start, Time.local(2011, 6, 14, 23, 0))
    assert_equal(epg.program_list.find{ |a| a.title == "C1"}.stop, Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list.find{ |a| a.title == "M0"}.start, Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list.find{ |a| a.title == "M0"}.stop, Time.local(2011, 6, 15, 0, 0))
    assert_equal(epg.program_list.find{ |a| a.title == "C3"}.start, Time.local(2011, 6, 15, 10, 0))
    assert_equal(epg.program_list.find{ |a| a.title == "C3"}.stop, Time.local(2011, 6, 15, 10, 30))

    #チャンネル違いへの対応
    epg = EPG.new(DummyEPG, [
      {:title => 'M0',  :start => Time.local(2011, 6, 14, 23, 30), :stop => Time.local(2011, 6, 15, 0, 0), :channel => "C47"},
    ])
    epg2 = EPG.new(DummyEPG, [
      {:title => 'C1',  :start => Time.local(2011, 6, 14, 23, 0),  :stop => Time.local(2011, 6, 14, 23, 30), :channel => "C39"},
      {:title => 'C2',  :start => Time.local(2011, 6, 14, 23, 30), :stop => Time.local(2011, 6, 15, 0, 0), :channel => "C39"},
      {:title => 'C3',  :start => Time.local(2011, 6, 15, 10, 0),  :stop => Time.local(2011, 6, 15, 10, 30), :channel => "C39"},
    ])

    epg.update(epg2)
    assert_equal(epg.program_list.size, 4)
    assert_equal(epg.program_list.find{ |a| a.title == "M0"}.start, Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list.find{ |a| a.title == "M0"}.stop, Time.local(2011, 6, 15, 0, 0))
    assert_equal(epg.program_list.find{ |a| a.title == "C1"}.start, Time.local(2011, 6, 14, 23, 0))
    assert_equal(epg.program_list.find{ |a| a.title == "C1"}.stop, Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list.find{ |a| a.title == "C2"}.start, Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list.find{ |a| a.title == "C2"}.start, Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list.find{ |a| a.title == "C3"}.start, Time.local(2011, 6, 15, 10, 0))
    assert_equal(epg.program_list.find{ |a| a.title == "C3"}.stop, Time.local(2011, 6, 15, 10, 30))

    epg = EPG.new(DummyEPG, [
      {:title => 'M1',  :start => Time.local(2011, 6, 14, 23, 0),  :stop => Time.local(2011, 6, 14, 23, 30), :channel => "C39"},
      {:title => 'M2',  :start => Time.local(2011, 6, 14, 23, 30), :stop => Time.local(2011, 6, 15, 0, 0), :channel => "C39"},
      {:title => 'M3',  :start => Time.local(2011, 6, 15, 10, 0),  :stop => Time.local(2011, 6, 15, 10, 30), :channel => "C39"},
    ])
    epg2 = EPG.new(DummyEPG, [
      {:title => 'C0',  :start => Time.local(2011, 6, 14, 23, 30), :stop => Time.local(2011, 6, 15, 0, 0), :channel => "C39"},
    ])

    epg.update(epg2)
    assert_equal(epg.program_list.size, 3)
    assert_equal(epg.program_list[0].title, 'M1')
    assert_equal(epg.program_list[1].title, 'M2')
    assert_equal(epg.program_list[2].title, 'M3')
    assert_equal(epg.program_list[0].start, Time.local(2011, 6, 14, 23, 0))
    assert_equal(epg.program_list[0].stop,  Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list[1].start, Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list[1].stop,  Time.local(2011, 6, 15, 0, 0))
    assert_equal(epg.program_list[2].start, Time.local(2011, 6, 15, 10, 0))
    assert_equal(epg.program_list[2].stop,  Time.local(2011, 6, 15, 10, 30))

    epg = EPG.new(DummyEPG, [
      {:title => 'M0',  :start => Time.local(2011, 6, 14, 22, 0),  :stop => Time.local(2011, 6, 14, 23, 00), :channel => "C39"},
      {:title => 'M1',  :start => Time.local(2011, 6, 14, 23, 0),  :stop => Time.local(2011, 6, 15, 0, 50), :channel => "C39"},
      {:title => 'M2',  :start => Time.local(2011, 6, 15, 9, 0),  :stop => Time.local(2011, 6, 15, 10, 0), :channel => "C39"},
      {:title => 'M3',  :start => Time.local(2011, 6, 15, 10, 0),  :stop => Time.local(2011, 6, 15, 10, 30), :channel => "C39"},
      {:title => 'M4',  :start => Time.local(2011, 6, 15, 10, 30), :stop => Time.local(2011, 6, 15, 10, 45), :channel => "C39"},
      {:title => 'M5',  :start => Time.local(2011, 6, 15, 10, 45), :stop => Time.local(2011, 6, 15, 11, 0), :channel => "C39"},
      {:title => 'M6',  :start => Time.local(2011, 6, 15, 11, 0),  :stop => Time.local(2011, 6, 15, 11, 30), :channel => "C39"},
      {:title => 'M7',  :start => Time.local(2011, 6, 15, 11, 30), :stop => Time.local(2011, 6, 15, 12, 30), :channel => "C39"},
      {:title => 'M8',  :start => Time.local(2011, 6, 15, 12, 30), :stop => Time.local(2011, 6, 15, 13, 30), :channel => "C39"},
      {:title => 'M9',  :start => Time.local(2011, 6, 15, 13, 30), :stop => Time.local(2011, 6, 15, 14, 5), :channel => "C39"},
      {:title => 'M10',  :start => Time.local(2011, 6, 15, 14, 5),  :stop => Time.local(2011, 6, 15, 14, 10), :channel => "C39"},
      {:title => 'M11', :start => Time.local(2011, 6, 15, 14, 10), :stop => Time.local(2011, 6, 15, 14, 30), :channel => "C39"},
      {:title => 'M12', :start => Time.local(2011, 6, 15, 14, 45), :stop => Time.local(2011, 6, 15, 15, 0), :channel => "C39"},
      {:title => 'M13', :start => Time.local(2011, 6, 15, 15, 0), :stop => Time.local(2011, 6, 15, 16, 0), :channel => "C39"},
    ])
    epg2 = EPG.new(DummyEPG, [
      {:title => 'C1',  :start => Time.local(2011, 6, 14, 23, 0),  :stop => Time.local(2011, 6, 14, 23, 30), :channel => "C39"},
      {:title => 'C2',  :start => Time.local(2011, 6, 14, 23, 30), :stop => Time.local(2011, 6, 15, 0, 0), :channel => "C39"},
      {:title => 'C3',  :start => Time.local(2011, 6, 15, 10, 0),  :stop => Time.local(2011, 6, 15, 10, 30), :channel => "C39"},
      {:title => 'C4',  :start => Time.local(2011, 6, 15, 10, 30), :stop => Time.local(2011, 6, 15, 11, 0), :channel => "C39"},
      {:title => 'C5',  :start => Time.local(2011, 6, 15, 11, 0),  :stop => Time.local(2011, 6, 15, 11, 15), :channel => "C39"},
      {:title => 'C6',  :start => Time.local(2011, 6, 15, 11, 15), :stop => Time.local(2011, 6, 15, 11, 30), :channel => "C39"},
      {:title => 'C7',  :start => Time.local(2011, 6, 15, 11, 30), :stop => Time.local(2011, 6, 15, 11, 35), :channel => "C39"},
      {:title => 'C8',  :start => Time.local(2011, 6, 15, 11, 35), :stop => Time.local(2011, 6, 15, 12, 0), :channel => "C39"},
      {:title => 'C9',  :start => Time.local(2011, 6, 15, 12, 0),  :stop => Time.local(2011, 6, 15, 13, 0), :channel => "C39"},
      {:title => 'C10', :start => Time.local(2011, 6, 15, 13, 0),  :stop => Time.local(2011, 6, 15, 14, 0), :channel => "C39"},
      {:title => 'C11', :start => Time.local(2011, 6, 15, 14, 0),  :stop => Time.local(2011, 6, 15, 14, 10), :channel => "C39"},
      {:title => 'C12', :start => Time.local(2011, 6, 15, 14, 15), :stop => Time.local(2011, 6, 15, 14, 30), :channel => "C39"},
      {:title => 'C13', :start => Time.local(2011, 6, 15, 14, 30), :stop => Time.local(2011, 6, 15, 15, 0), :channel => "C39"},
    ])

    epg.update(epg2)
    assert_equal(epg.program_list.size, 16)
    assert_equal(epg.program_list[0].title, 'M0')
    assert_equal(epg.program_list[1].title, 'C1')
    assert_equal(epg.program_list[2].title, 'C2')
    assert_equal(epg.program_list[3].title, 'M2')
    assert_equal(epg.program_list[4].title, 'M3')
    assert_equal(epg.program_list[5].title, 'C4')
    assert_equal(epg.program_list[6].title, 'C5')
    assert_equal(epg.program_list[7].title, 'C6')
    assert_equal(epg.program_list[8].title, 'C7')
    assert_equal(epg.program_list[9].title, 'C8')
    assert_equal(epg.program_list[10].title, 'C9')
    assert_equal(epg.program_list[11].title, 'C10')
    assert_equal(epg.program_list[12].title, 'C11')
    assert_equal(epg.program_list[13].title, 'C12')
    assert_equal(epg.program_list[14].title, 'C13')
    assert_equal(epg.program_list[15].title, 'M13')

    assert_equal(epg.program_list[0].start, Time.local(2011, 6, 14, 22, 0))
    assert_equal(epg.program_list[0].stop,  Time.local(2011, 6, 14, 23, 0))
    assert_equal(epg.program_list[1].start, Time.local(2011, 6, 14, 23, 0))
    assert_equal(epg.program_list[1].stop,  Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list[2].start, Time.local(2011, 6, 14, 23, 30))
    assert_equal(epg.program_list[2].stop,  Time.local(2011, 6, 15, 0, 0))
    assert_equal(epg.program_list[3].start, Time.local(2011, 6, 15, 9, 0))
    assert_equal(epg.program_list[3].stop,  Time.local(2011, 6, 15, 10, 0))
    assert_equal(epg.program_list[4].start, Time.local(2011, 6, 15, 10, 0))
    assert_equal(epg.program_list[4].stop,  Time.local(2011, 6, 15, 10, 30))
    assert_equal(epg.program_list[5].start, Time.local(2011, 6, 15, 10, 30))
    assert_equal(epg.program_list[5].stop,  Time.local(2011, 6, 15, 11, 0))
    assert_equal(epg.program_list[6].start, Time.local(2011, 6, 15, 11, 0))
    assert_equal(epg.program_list[6].stop,  Time.local(2011, 6, 15, 11, 15))
    assert_equal(epg.program_list[7].start, Time.local(2011, 6, 15, 11, 15))
    assert_equal(epg.program_list[7].stop,  Time.local(2011, 6, 15, 11, 30))
    assert_equal(epg.program_list[8].start, Time.local(2011, 6, 15, 11, 30))
    assert_equal(epg.program_list[8].stop,  Time.local(2011, 6, 15, 11, 35))
    assert_equal(epg.program_list[9].start, Time.local(2011, 6, 15, 11, 35))
    assert_equal(epg.program_list[9].stop,  Time.local(2011, 6, 15, 12, 0))
    assert_equal(epg.program_list[10].start, Time.local(2011, 6, 15, 12, 0))
    assert_equal(epg.program_list[10].stop,  Time.local(2011, 6, 15, 13, 0))
    assert_equal(epg.program_list[11].start, Time.local(2011, 6, 15, 13, 0))
    assert_equal(epg.program_list[11].stop,  Time.local(2011, 6, 15, 14, 0))
    assert_equal(epg.program_list[12].start, Time.local(2011, 6, 15, 14, 0))
    assert_equal(epg.program_list[12].stop,  Time.local(2011, 6, 15, 14, 10))
    assert_equal(epg.program_list[13].start, Time.local(2011, 6, 15, 14, 15))
    assert_equal(epg.program_list[13].stop,  Time.local(2011, 6, 15, 14, 30))
    assert_equal(epg.program_list[14].start, Time.local(2011, 6, 15, 14, 30))
    assert_equal(epg.program_list[14].stop,  Time.local(2011, 6, 15, 15, 0))
    assert_equal(epg.program_list[15].start, Time.local(2011, 6, 15, 15, 0))
    assert_equal(epg.program_list[15].stop,  Time.local(2011, 6, 15, 16, 0))


    epg = EPG.new(DummyEPG, [{
      :category => "anime", 
      :title => "ほげ", 
      :start => Time.local(2011, 6, 3, 2, 45), 
      :stop => Time.local(2011, 6, 3, 3, 15), 
      :desc => "ほげですく", 
      :channel => 'C39'
    }, {
      :category => "infomation", 
      :title => "ふが", 
      :stop => Time.local(2011, 6, 3, 3, 30), 
      :start => Time.local(2011, 6, 3, 3, 15), 
      :desc => "ふがですく", 
      :channel => 'C39'
    }])
    epg2 = EPG.new(DummyEPG, [{
      :category => "anime", 
      :title => "hoge/1", 
      :start => Time.local(2011, 6, 3, 2, 45), 
      :stop => Time.local(2011, 6, 3, 3, 0), 
      :desc => "hoge1", 
      :channel => 'C39'
    }, {
      :category => "anime", 
      :title => "hoge/2", 
      :start => Time.local(2011, 6, 3, 3, 0), 
      :stop => Time.local(2011, 6, 3, 3, 15), 
      :desc => "hoge2", 
      :channel => 'C39'
    }])
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

  def test_program
    # 一応 dummy データに問題がない事を確認
    epg = EPG.new(DummyEPG, [{
      :category => "anime", 
      :title => "ほげ", 
      :start => Time.local(2011, 6, 3, 2, 45), 
      :stop => Time.local(2011, 6, 3, 3, 15), 
      :desc => "ほげですく", 
      :channel => 'C39'
    }, {
      :category => "infomation", 
      :title => "ふが", 
      :stop => Time.local(2011, 6, 3, 3, 30), 
      :start => Time.local(2011, 6, 3, 3, 15), 
      :desc => "ふがですく", 
      :channel => 'C39'
    }])
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
    epg = EPG.new(DummyEPG, [{
      :category => "anime", 
      :title => "ほげ", 
      :start => Time.local(2011, 6, 3, 2, 45), 
      :stop => Time.local(2011, 6, 3, 3, 15), 
      :desc => "ほげですく", 
      :channel => 'C39'
    }, {
      :category => "infomation", 
      :title => "ふが", 
      :stop => Time.local(2011, 6, 3, 3, 30), 
      :start => Time.local(2011, 6, 3, 3, 15), 
      :desc => "ふがですく", 
      :channel => 'C39'
    }])

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

  def test_resolve
    # 非衝突 (時間連続)
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39', :priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39', :priority => 1},
    ])

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, false)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "2"}.conflict, false)

    # スロット一つ。必ず 3 がコンフリクトになるケース
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39', :priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39', :priority => 1},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38', :priority => 1},
    ])

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "2"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, true)

    # スロット一つ。3が優先度が高いので、1, 2 がコンフリクトになるケース
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39', :priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39', :priority => 1},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38', :priority => 2},
    ])

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, true)
    assert_equal(epg.program_list.find{ |a| a.title == "2"}.conflict, true)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, false)

    # スロット一つ。必ず3がコンフリクトになって、なおかつ、1,2 の方がプライオリティが高い
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39', :priority => 2},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39', :priority => 2},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38', :priority => 1},
    ])

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "2"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, true)

    # スロット一つ、必ず3 と 4 がコンフリクトになるケース (2 or 4 だけど、2 がプライオリティ高い)
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39' ,:priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39' ,:priority => 2},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38' ,:priority => 1},
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C37' ,:priority => 1},
    ])

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "2"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, true)
    assert_equal(epg.program_list.find{ |a| a.title == "4"}.conflict, true)

    # スロット一つ、必ず3 と、2 or 4 がコンフリクトになるケース (2が先)
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39' ,:priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39' ,:priority => 1},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38' ,:priority => 1},
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C37' ,:priority => 1},
    ])

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, true)
    c2 = epg.program_list.find{ |a| a.title == "2"}.conflict
    c4 = epg.program_list.find{ |a| a.title == "4"}.conflict
    assert_equal(c2 || c4 , true)
    assert_equal(c2 && c4 , false)

    # スロット一つ、必ず3 と、2 or 4 がコンフリクトになるケース (4が先)
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39' ,:priority => 1},
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C37' ,:priority => 1},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38' ,:priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39' ,:priority => 1},
    ])

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, true)
    c2 = epg.program_list.find{ |a| a.title == "2"}.conflict
    c4 = epg.program_list.find{ |a| a.title == "4"}.conflict
    assert_equal(c2 || c4 , true)
    assert_equal(c2 && c4 , false)

    # スロット一つ、2, 3 のプライオリティが高いケース (3 の方が先なので、3以外はコンフリクト)
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39' ,:priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39' ,:priority => 2},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38' ,:priority => 2},
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C37' ,:priority => 1},
    ])

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, true)
    assert_equal(epg.program_list.find{ |a| a.title == "2"}.conflict, true)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "4"}.conflict, true)

    # スロット一つ、4, 5 のプライオリティが高いケース (5 は、他と時間帯がずれてるので関係無い
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39' ,:priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39' ,:priority => 1},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38' ,:priority => 1},
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C37' ,:priority => 2},
      {:title => "5", :start => Time.local(2011,6, 3, 3, 45), :stop => Time.local(2011, 6, 3, 4, 15), :channel => 'C39' ,:priority => 3},
    ])

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "2"}.conflict, true)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, true)
    assert_equal(epg.program_list.find{ |a| a.title == "4"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "5"}.conflict, false)

    # スロット一つ、必ず3 と、2 or 4 がコンフリクトになるケース (update により merge したデータの場合)
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39' ,:priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39' ,:priority => 1},
    ])
    epg2 = EPG.new(DummyEPG, [
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38' ,:priority => 1},
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C37' ,:priority => 1},
    ])
    epg.update(epg2)

    epg.resolve_conflict 1
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, true)
    c2 = epg.program_list.find{ |a| a.title == "2"}.conflict
    c4 = epg.program_list.find{ |a| a.title == "4"}.conflict
    assert_equal(c2 || c4 , true)
    assert_equal(c2 && c4 , false)

    #
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39' ,:priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39' ,:priority => 1},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38' ,:priority => 1},
    ])
    epg.resolve_conflict 2
    assert_equal(epg.conflict?, false)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.slot, epg.program_list.find{ |a| a.title == "2"}.slot)
    assert_not_equal(epg.program_list.find{ |a| a.title == "1"}.slot, epg.program_list.find{ |a| a.title == "3"}.slot)
    assert_not_equal(epg.program_list.find{ |a| a.title == "2"}.slot, epg.program_list.find{ |a| a.title == "3"}.slot)

    #
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39' ,:priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39' ,:priority => 1},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38' ,:priority => 1},
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C37' ,:priority => 1},
    ])
    epg.resolve_conflict 2
    assert_equal(epg.conflict?, true)
    assert_equal(epg.program_list.find{ |a| a.title == "1"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "2"}.conflict, false)
    assert_equal(epg.program_list.find{ |a| a.title == "3"}.conflict, false)
    c2 = epg.program_list.find{ |a| a.title == "2"}.conflict
    c4 = epg.program_list.find{ |a| a.title == "4"}.conflict
    assert_equal(c2 || c4 , true)
    assert_equal(c2 && c4 , false)
    assert_not_equal(epg.program_list.find{ |a| a.title == "2"}.slot, epg.program_list.find{ |a| a.title == "3"}.slot)

    #
    epg = EPG.new(DummyEPG, [
      {:title => "1", :start => Time.local(2011,6, 3, 2, 45), :stop => Time.local(2011, 6, 3, 3, 15), :channel => 'C39' ,:priority => 1},
      {:title => "2", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 45), :channel => 'C39' ,:priority => 1},
      {:title => "3", :start => Time.local(2011,6, 3, 3,  5), :stop => Time.local(2011, 6, 3, 3, 20), :channel => 'C38' ,:priority => 1},
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C37' ,:priority => 1},
    ])
    epg.resolve_conflict 3
    assert_equal(epg.conflict?, false)
    assert_not_equal(epg.program_list.find{ |a| a.title == "2"}.slot, epg.program_list.find{ |a| a.title == "3"}.slot)
    assert_not_equal(epg.program_list.find{ |a| a.title == "3"}.slot, epg.program_list.find{ |a| a.title == "4"}.slot)
    assert_not_equal(epg.program_list.find{ |a| a.title == "2"}.slot, epg.program_list.find{ |a| a.title == "4"}.slot)
  end

  def test_main
    # 空の状態ならば、全チャンネルに対して 60 秒取得
    fabula = Fabula.new
    fabula.injection_config(:channel => {'C39' => 'テレビ東京', 'C47' => '東京ＭＸ'})
    fabula.injection_accessor(DummyAccessor, [0, 1])
    fabula.main

    assert_equal($fork.size, 2)
    assert_equal($fork.find{ |a| a.program_list[0].channel == 'C39'}.program_list[0].title, "GETEPG_C39_60")
    assert_equal($fork.find{ |a| a.program_list[0].channel == 'C47'}.program_list[0].title, "GETEPG_C47_60")

	# 空じゃなくて、fresh が空
    fabula = Fabula.new
    fabula.injection_epg(EPG.new(DummyEPG, [
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C39' ,:priority => 1},
    ]))

    fabula.injection_config(:channel => {'C39' => 'テレビ東京', 'C47' => '東京ＭＸ'})
    fabula.injection_accessor(DummyAccessor, [0, 1])
    fabula.main

    assert_equal($fork.size, 2)
    assert_equal($fork.find{ |a| a.program_list[0].channel == 'C39'}.program_list[0].title, "GETEPG_C39_60")
    assert_equal($fork.find{ |a| a.program_list[0].channel == 'C47'}.program_list[0].title, "GETEPG_C47_60")

    # 空じゃなくて、fresh が 古い
    fabula = Fabula.new
    fabula.injection_epg(EPG.new(DummyEPG, [
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C39' ,:priority => 1},
      {:fresh => Time.now - 1, :channel => "C39"}
    ]))
    fabula.injection_config(:channel => {'C39' => 'テレビ東京', 'C47' => '東京ＭＸ'})
    fabula.injection_accessor(DummyAccessor, [0, 1])
    fabula.main

    assert_equal($fork.size, 2)
    assert_equal($fork.find{ |a| a.program_list[0].channel == 'C39'}.program_list[0].title, "GETEPG_C39_60")
    assert_equal($fork.find{ |a| a.program_list[0].channel == 'C47'}.program_list[0].title, "GETEPG_C47_60")

    # 空じゃなくて fresh がまだで last_fresh が新しい
    fabula = Fabula.new
    fabula.injection_epg(EPG.new(DummyEPG, [
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C39' ,:priority => 1},
      {:fresh => Time.now + 60 * 60, :channel => "C39"}
    ]))
    fabula.injection_config(:channel => {'C39' => 'テレビ東京', 'C47' => '東京ＭＸ'})
    fabula.injection_accessor(DummyAccessor, [0, 1])
    fabula.epg.injection_lastfresh('C39', Time.now)
    fabula.main

    assert_equal($fork.size, 1)
    assert_equal($fork.find{ |a| a.program_list[0].channel == 'C47'}.program_list[0].title, "GETEPG_C47_60")

    # 空じゃなくて fresh がまだで last_fresh が5分以上経過
    fabula = Fabula.new
    fabula.injection_epg(EPG.new(DummyEPG, [
      {:title => "4", :start => Time.local(2011,6, 3, 3, 15), :stop => Time.local(2011, 6, 3, 3, 30), :channel => 'C39' ,:priority => 1},
      {:fresh => Time.now + 60 * 60, :channel => "C39"}
    ]))
    fabula.injection_config(:channel => {'C39' => 'テレビ東京', 'C47' => '東京ＭＸ'})
    fabula.injection_accessor(DummyAccessor, [0, 1])
    fabula.epg.injection_lastfresh('C39', Time.now - 60 * 6)
    fabula.main

    assert_equal($fork.size, 2)
    assert_equal($fork.find{ |a| a.program_list[0].channel == 'C39'}.program_list[0].title, "GETEPG_C39_3")
    assert_equal($fork.find{ |a| a.program_list[0].channel == 'C47'}.program_list[0].title, "GETEPG_C47_60")

    # 録画キューの処理
  end


end





















