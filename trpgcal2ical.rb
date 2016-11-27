require 'icalendar'
require 'mechanize'

# 実行日時の先月、当月、来月のTRPGイベントカレンダー(仮)をiCal方式に変換する

calendar = Icalendar::Calendar.new
calendar.timezone do |t|
  t.tzid = 'Asia/Tokyo'
  t.standard do |s|
    s.tzoffsetfrom = '+0900'
    s.tzoffsetto   = '+0900'
    s.tzname       = 'JST'
    s.dtstart      = '19700101T000000'
  end
end
calendar.append_custom_property('X-WR-CALNAME;VALUE=TEXT', 'TRPGイベントカレンダー(仮)')

agent = Mechanize.new
[Date.today.prev_month, Date.today, Date.today.next_month].each do |d|
  begin
    uri = URI::HTTP.new('http', nil, 'trpg_calendar.alchemist.ne.jp', nil, nil, '/cgi/webcal.cgi', nil, "form=2&year=#{d.year}&mon=#{d.month}", nil) # Ruby 2.1.5など古い処理系でアンダースコアを含むホストネームをparseさせるとエラーになるのでこうしてみている
    page = agent.get(uri)
    trs = page.search('table:nth-of-type(2) tr') # なぜかtable[3]だと取れない
    trs[1..-1].each do |tr| # 一番上のテーブルヘッダーは飛ばす
      tds = tr.search('td')
      day = tds[0].inner_text.to_i
      times = tds[3].search('b').map{|b| b.inner_text}
      summaries = tds[4].search('b font font[1]').map{|b| b.inner_text}
      locations = tds[4].search('b font font[2]').map{|b| b.inner_text.delete(' / 場所：')}
      
      # 時刻指定のないイベントで配列の対応関係がズレないようにする
      # 見たところ時刻指定のないイベントは一番上に配置されるようなので、配列の先頭を埋める
      if times.size < summaries.size
        times.insert(0, *Array.new(summaries.size - times.size, nil))
      end

      unless (times.size == summaries.size) && (times.size == locations.size)
        raise 'invalid array size'
      end

      (0...summaries.size).each do |i|
        event = Icalendar::Event.new
        event.summary = summaries[i]
        event.location = locations[i]

        sh, sm, eh, em = times[i] ? times[i].split('〜').map{|t| t.split(':')}.flatten.map{|t| t.to_i} : [nil, nil, nil, nil]
        if sh && sm
          event.dtstart = Icalendar::Values::DateTime.new(DateTime.new(d.year, d.month, day, sh, sm, 0))
        else
          event.dtstart = Icalendar::Values::Date.new(Date.new(d.year, d.month, day))
        end
        if eh && em
          event.dtend = Icalendar::Values::DateTime.new(DateTime.new(d.year, d.month, day, eh, em, 0))
        else
          event.dtend = Icalendar::Values::Date.new(Date.new(d.year, d.month, day))
        end

        calendar.add_event(event)
      end
    end
  rescue
    STDERR.puts $!, $@
  end
end

calendar.publish
puts calendar.to_ical
