# encoding: utf-8

require 'telegram/bot'
require 'net/http'
require 'json'

def start_time
  @start_time ||= Time.now
end
puts start_time

token = File.read('data/token.txt', encoding: 'UTF-8').lines.first.delete("\n")
@deepai_token = File.read('data/ai.txt', encoding: 'UTF-8').lines.first.delete("\n")
def admin_ids
  @admin_ids ||= File.read('data/admins.txt').split("\n").map(&:to_i).compact
end

def help_msg
  'Я умею:
  * /roll 3d6 - брось дайсы!
  * /for_the_emperor - Мотивирующая фраза от вашего лорда-комиссара.
  * /qr_it - Сделать qr-код.
  * /tableflip - Переверни стол!
  * /vzhuh - Вжух!
  * /shrug - пожми плечами
  * /version - показывать свою версию
  * Нихуя
А еще я сплю большую часть времени.'
end

def roll(text)
  res = text.scan(/\d+/).map(&:to_i)
  p res
  condition = text.scan(/[\>\<\=CcСс]\s*\d+/).first
  if condition
    target = res[-1]
    res = res[0..-2]
  end
  return 'Че-то ты криво рольнул.' unless res.size == 2
  return 'Куда тебе столько, ебанутый?' if res[0] > 1000
  return 'Нуль себе дерни, пес' if res[1].zero?

  rolls = []
  res[0].times do |_|
    rolls << rand(res[1]) + 1
  end
  sum = rolls.inject(0) do |r, x|
    r + x
  end
  if condition
    method = condition.scan(/[\>\<\=CcСс]/).first
    method = '==' if method == '='
    method = '>=' if method =~ /[CcСс]/
    check_result = rolls.select { |x| x.send(method.to_sym, target) }.size
  end
  text = "Бросок #{res[0]}d#{res[1]}: #{sum} (#{rolls.join(', ')})."
  text += " Успехов: #{check_result}." if check_result
  text
end

def tableflip_str
  @tableflip_str ||= '(╯°□°）╯︵ ┻━┻'
end

def tableflip_regexp
  @tableflip_regexp ||= /\(╯°□°\）╯︵ ┻━┻/
end

def doubleflip_str
  @doubleflip_str ||= '┻━┻ ︵ヽ(`Д´)ﾉ︵﻿ ┻━┻'
end

def unflip_str
  @unflip_str ||= '┬─┬ ノ( ゜-゜ノ)'
end

def qr_it
  query = @message.text.sub(/\/qr_it(@drrn_bot)?\s+/, '')
  if query.empty? && @message.reply_to_message
    query = @message.reply_to_message.text
  end
  return if query.empty?
  url = qr_url(query)
  reply_with_image url
  nil
end

def qr_url(query)
  "http://chart.apis.google.com/chart?chs=300x300&cht=qr&choe=UTF-8&chl=#{query}"
end

def dataline(filename)
  lines ||= File.read("data/#{filename}.txt", encoding: 'UTF-8')
                .split("\n")
  lines.sample
end

def humantime(dTime)
  def time2str(period, names)
    return "" if period.zero?
    def timesuffixes(ivalue, strs)
      case ivalue % 100
      when 11..14
        return "#{strs[2]}"
      end
      case ivalue%10
      when 0
        return "#{strs[2]}"
      when 1
        return "#{strs[0]}"
      when 2..4
        return "#{strs[1]}"
      else
        return "#{strs[2]}"
      end
    end
    def number2str(number, sex)
      return "бесконечное число" if(number > 999)
      res = ""
      hundreds = [ "", "сто", "двести", "триста", "четыреста", "пятьсот", "шестьсот", "семьсот", "восемьсот", "девятьсот" ]
      unders  = [ "", "", "", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять", "десять",
                  "одиннадцать", "двенадцать", "тринадцать", "четырнадцать", "пятнадцать", "шестнадцать", "семнадцать", "восемнадцать", "девятнадцать" ]
      case sex
      when "M"
        unders[0..2] = [ "", "один", "два" ]
      when "F"
        unders[0..2] = [ "", "одну", "две" ]
      end
      dozens  = [ "", "", "двадцать", "тридцать", "сорок", "пятьдесят", "шестьдесят", "семьдесят", "восемьдесят", "девяносто" ]
      res += hundreds[number / 100] + " "
      number = number % 100
      case number
      when 0..19
        res += unders[number]
      else
        res += dozens[number / 10] + " " + unders[number % 10]
      end
      res.strip
    end
    if names[0][-1].eql? "y" then
      sex = "F"
    else
      sex = "M"
    end
    "#{number2str(period, sex)} #{timesuffixes(period, names)}"
  end
  prefix = "Я не спал уже"
  iStM = 60
  iMtH = 60
  iHtD = 24
  iStH = iStM * iMtH
  iStD = iStH * iHtD
  iMtD = iMtH * iHtD
  idTime = dTime.to_i
  days         = idTime / iStD
  return "#{prefix} целую вечность!" if days > 999
  hours        = idTime / iStH - (days * iHtD)
  minutes      = idTime / iStM - (days * iMtD + hours * iMtH)
  seconds      = idTime        - (days * iStD + hours * iStH + minutes * iStM)
  floatseconds = dTime - idTime
  nanoseconds  = "#{floatseconds.round(9)}"[2..-1].to_i
  milliseconds = nanoseconds / 1000 / 1000
  miсroseconds = nanoseconds / 1000 % 1000
  nanoseconds  = nanoseconds        % 1000
  prefix = "Я не сплю уже" if days * iHtD + hours < 8
  if hours < 1 then
    tmp = minutes
    tmp = seconds      if tmp.zero?
    tmp = milliseconds if tmp.zero?
    tmp = microseconds if tmp.zero?
    tmp = nanoseconds  if tmp.zero?
    if tmp % 100 == 11 then
      prefix += " целых"
    else
      case tmp % 10
      when 1
        prefix += " целую"
      else
        prefix += " целых"
      end
    end
  end
  days         = time2str(days,         ["день",         "дня",          "дней"       ])
  hours        = time2str(hours,        ["час",          "часа",         "часов"      ])
  minutes      = time2str(minutes,      ["минутy",       "минуты",       "минут"      ])
  seconds      = time2str(seconds,      ["секундy",      "секунды",      "секунд"     ])
  milliseconds = time2str(milliseconds, ["миллисекундy", "миллисекунды", "миллисекунд"])
  miсroseconds = time2str(miсroseconds, ["микросекундy", "микросекунды", "микросекунд"])
  nanoseconds  = time2str(nanoseconds,  ["наносекундy",  "наносекунды",  "наносекунд" ])
  "#{prefix} #{days} #{hours} #{minutes} #{seconds} #{milliseconds} #{miсroseconds} #{nanoseconds}".squeeze(" ").sub "целую одну", "целую"
end

def humandate(time)
  def humanms(number, names)
    numerals = [ "нуля", "одной", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти", "десяти",
                 "одиннадцати", "двенадцати", "тринадцати", "четырнадцати", "пятнадцати", "шестнадцати", "семнадцати", "восемнадцати", "девятнадцати" ]
    dozens = [ "", "", "двадцати", "тридцати", "сорока", "пятидесяти", "шестидесяти" ]
    res = ""
    case number
    when 0..19
      res = numerals[number]
    else
      res = dozens[number / 10]
      res += " " + numerals[number % 10] if !(number % 10).zero?
    end
    case number
    when 1,21,31,41,51
      res += " " + names[1]
    else
      res += " " + names[0]
    end
  end
  def humanhours(number)
    res = ""
    numerals = [ "", "", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти", "десяти", "одиннадцати" ]
    case number
    when 0
      res = "нуля часов"
    when 1
      res = "первого часа ночи и"
    when 2..11
      res = numerals[number] + " часов"
    end
    case number
    when 2..3
      res += " ночи"
    when 4..11
      res += " утра"
    end
    return res if !res.eql? ""
    number -= 12
    case number
    when 0
      res = "двенадцати часов"
    when 1
      res = "часу"
    when 2..11
      res = numerals[number] + " часов"
    end
    case number
    when 0..4
      res += " дня"
    when 5..11
      res += " вечера"
    end
    res
  end
  def humanday(number)
    days = [ "", "первого", "второго", "третьего", "четвертого", "пятого", "шестого", "седьмого", "восьмого", "девятого", "десятого",
      "одиннадцатого", "двенадцатого", "тринадцатого", "четырнадцатого", "пятнадцатого", "шестнадцатого", "семнадцатого", "восемнадцатого", "девятнадцатого", "двадцатого" ]
    dozendays = [ "", "", "двадцать", "тридцать" ]
    thirtieth = "тридцатого"
    case number
    when 1..20
      days[number]
    when 30
      thirtieth
    when 21..29, 31
      dozendays[number / 10] + " " + days[number % 10]
    end
  end
  def humanmonth(number)
    [ "января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря" ][number - 1]
  end
  def humanyear(number)
    #только для 2ххх годов и не 2000-ого
    return "неизвестного года" if number <= 2000 or number > 2999
    res = "две тысячи "
    hundreds   = [ "", "сто", "двести", "триста", "четыреста", "пятьсот", "шестьсот", "семьсот", "восемьсот", "девятьсот" ]
    hundredths = [ "", "сотого", "двухсотого", "трёхсотого", "четырёхсотого", "пятисотого", "шестисотого", "семисотого", "восьмисотого", "девятисотого" ]
    underths   = [ "", "первого", "второго", "третьего", "четвертого", "пятого", "шестого", "седьмого", "восьмого", "девятого", "десятого",
                   "одиннадцатого", "двенадцатого", "тринадцатого", "четырнадцатого", "пятнадцатого", "шестнадцатого", "семнадцатого", "восемнадцатого", "девятнадцатого" ]
    dozens     = [ "", "", "двадцать", "тридцать", "сорок", "пятьдесят", "шестьдесят", "сетьдесят", "восемьдесят", "девяносто" ]
    dozenths   = [ "", "", "двадцатого", "тридцатого", "сорокового", "пятидесятого", "шестидесятого", "семидесятого", "восьмидесятого", "девятидесятого" ]
    number = number % 1000
    if number % 100 == 0 then
      res += hundredths[number/100] + " "
    else
      res += hundreds[number/100] + " "
    end
    number = number % 100
    case number
    when 0
    when 1..19
      res += underths[number]
    else
      if (number % 10).zero? then
        res += dozenths[number / 10]
      else
        res += dozens[number / 10] + " " + underths[number % 10]
      end
    end
    res += " года"
    res.squeeze " "
  end
  def humanzone(name)
    "по " +
    { "ACST" => "центральноавстралийскому",
      "AEST" => "восточноавстралийскому",
      "AKT"  => "аляскинскому",
      "ART"  => "аргентинскому",
      "AST"  => "атлантическому",
      "AWST" => "западноавстралийскому",
      "BDT"  => "бангладешскому",
      "BTT"  => "бутанскому",
      "CAT"  => "центральноафриканскому",
      "CET"  => "центральноевропейскому",
      "CST"  => "центральноамериканскому",
      "CXT"  => "рождественскому островному",
      "ChT"  => "чаморсскому",
      "EAT"  => "восточноафриканскому",
      "EET"  => "восточноевропейскому",
      "EST"  => "североамериканскому восточному",
      "FET"  => "восточному",
      "GALT" => "галапагосскому",
      "GMT"  => "среднему по Гринвичу",
      "HAST" => "гавайско-алеутскому",
      "HKT"  => "гонконгскому",
      "IRST" => "иранскому",
      "JST"  => "японскому",
      "MT"   => "горному",
      "MSK"  => "московскому",
      "MST"  => "мьянмскому",
      "NFT"  => "норфолкскому островному",
      "NST"  => "ньюфаундлендскому",
      "PET"  => "перуанскому",
      "PHT"  => "филлипинскому",
      "PKT"  => "пакистанскому",
      "PMST" => "сен-пьер-и-микелонскому",
      "PST"  => "тихоокеанскому",
      "SLT"  => "шри-ланкийскому",
      "SST"  => "сингапурскому",
      "ST"   => "самоаскому",
      "THA"  => "таиландскому",
      "UTC"  => "всемирному координационному",
      "WAT"  => "западноафриканскому",
      "WET"  => "западноевропейскому"
    }[name] + " времени"
  end
  "#{humanhours time.hour} #{humanms(time.min, [ 'минут', 'минуты' ])} #{humanms(time.sec, [ 'секунд', 'секунды' ])} #{humanday time.day} #{humanmonth time.month} #{humanyear time.year} #{humanzone time.zone}"
end

#################################### <- mobile telegram line meter :)
def vzhuh_str(mes)
  "```
∧＿∧
( ･ω･｡)つ━☆・*。
⊂　 ノ 　　　・゜+.
しーＪ　　　°。+ *´¨)
　　　　　　　　　.· ´¸.·*´¨) ¸.·*¨)
　　　　　　　　　　(¸.·´ (¸.·'* ☆ #{mes}
```"
end

def fur_sausage
  %q[```
,____          (\=-,
\ "=.`'-.______/ /^
 `-._.-"(=====' /
         \<'--\(
          ^^   ^^
```]
end

def send_markdown_message(text)
  @bot.api.send_message(
    chat_id: @message.chat.id,
    text: text,
    reply_to_message_id: @message.message_id,
    parse_mode: 'Markdown'
  )
  nil
end

def this_fucking_cat
  "https://thiscatdoesnotexist.com/?сrutch=#{Time.now.to_i}"
end

def deepai_text2img(text)
  uri = URI("http://api.deepai.org/api/text2img")
  req = Net::HTTP::Post.new(uri)
  req["api-key"] = @deepai_token
  req.set_form_data("text" => text)
  res = Net::HTTP.start(uri.hostname, uri.port) {|http|
    http.request(req)
  }
  puts res.body
  JSON.parse(res.body)["output_url"]
end

def this_fucking_fox
  deepai_text2img "fox"
end

def infinite_scream
  # tribute to https://twitter.com/infinite_scream
  'A' * (rand(1..10) + rand(6)) + 'H' * rand(1..6)
end

def reply_with_image(image_url)
  @bot.api.send_photo(
     chat_id: @message.chat.id,
     photo: image_url,
     reply_to_message_id: @message.message_id
  )
end

def handle_message
  puts "#{@message.from.first_name}: #{@message.text}"
  case @message.text
  when /^\/update(@drrn_bot)?(\s+.*|$)/
    return 'Пошел нахуй.' unless admin_ids.include?(@message.from.id)

    delta = Time.now - start_time
    if delta < 60 # если перегружались меньше минуты назад
      return "Сейчас мы тут: #{%x{git show --oneline -s}}\n\
До следующего возможного перезапуска #{(60 - delta).to_i} секунд."
    end

    query = @message.text.sub(/\/update(@drrn_bot)?\s*/, '')
    unless query.empty?
      @bot.api.send_message(
        chat_id: @message.chat.id,
        text: "Пробуем чекаутить #{query}"
      )
      res = `git checkout #{query}`
      @bot.api.send_message(chat_id: @message.chat.id, text: res)
    end
    @bot.api.send_message(chat_id: @message.chat.id, text: 'Ок, перегружаюсь.')
    sleep 5
    abort # просто пристрелить себя, демон сам все сделает
  when /^\/start(@drrn_bot)?$/
    "Ну привет, #{@message.from.first_name}"
  when /^\/stop(@drrn_bot)?$/
    "Покеда, #{@message.from.first_name}"
  when /^\/help(@drrn_bot)?$/
    help_msg
  when /^\/version(@drrn_bot)?(\s+.*|$)/
    "Сейчас мы тут:\n#{%x{git show -s --format='%h %s'}}"
  when /^\/qr_it(@drrn_bot)?\s+.+/
    qr_it
  when /^\/(vzhuh|magic)(@drrn_bot)?(\s+.*|$)/
    return 'Сам себе вжухай!' if rand(9) == 0
    query = @message.text.sub(/\/(vzhuh|magic)(@drrn_bot)?\s*/, '')
    res = vzhuh_str query
    send_markdown_message(res) if res.is_a? String
  when /^\/shrug(@drrn_bot)?(\s+.*|$)/
    query = @message.text.sub(/\/shrug(@drrn_bot)?\s*/, '')
    "#{query}¯\\_(ツ)_/¯"
  when /^\/unflip(@drrn_bot)?(\s+.*|$)/, tableflip_regexp, /(подними|поставь) (стол|обратно|на место|назад)/i, /верни стол (обратно|на место)/i
    unflip_str
  when /^\/doubleflip(@drrn_bot)?(\s+.*|$)/
    query = @message.text.sub(/\/doubleflip(@drrn_bot)?\s*/, '')
    "#{query} #{doubleflip_str}"
  when /Now you.+thinking with portals!/, /^\/portals(@drrn_bot)?/
    'Шас жахнет!'
  when /^\/uptime(@drrn_bot)?/
    dTime = Time.now - start_time
    "#{humantime dTime} c #{humandate start_time}! Я крут!"
  when /^\/for_the_emperor(@drrn_bot)?$/, 'За Императора!'
    dataline "warhammer_quotes"
  when /^\/heresy(@drrn_bot)?$/
    kb = [
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: 'Да', callback_data: "#{@message.chat.id}~ересь"
      ),
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: 'Нет', callback_data: "#{@message.chat.id}~не ересь"
      )
    ]
    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    if @message.reply_to_message != nil
      @bot.api.send_message(
        chat_id: @message.chat.id,
        text: 'Вы подозреваете ересь?',
        reply_to_message_id: @message.reply_to_message.message_id,
        reply_markup: markup
      )
    else
      @bot.api.send_message(
        chat_id: @message.chat.id,
        text: 'Вы подозреваете ересь?',
        reply_markup: markup
      )
    end
    nil
  when /^\/roll(@drrn_bot)?\s*$/
    'Че кидать-то будем?'
  when /^\/roll(@drrn_bot)?\s+\d+d\d+(\s*[\>\<\=CcСс]\d+)?/
    query = @message.text.sub(/\/roll(@drrn_bot)?\s*/, '')
    result = roll(query)
    begin
      @bot.api.send_message(
        chat_id: @message.chat.id,
        text: result,
        reply_to_message_id: @message.message_id
      )
      nil
    rescue => e
      'Куда тебе столько, ебанутый?'
    end
  when /^\/should_?i(@drrn_bot)?\s*$/
    'Тупить? Тупить не нужно.'
  when /^\/should_?i(@drrn_bot)?(\s+.*|$)/
    kb = [
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: 'Да', callback_data: "#{@message.chat.id}~answer-да"
      ),
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: 'Нет', callback_data: "#{@message.chat.id}~answer-нет"
      )
    ]
    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    res = dataline "shouldi_answers"
    res += "\n_Этот ответ был полезен?_"
    @bot.api.send_message(
      chat_id: @message.chat.id,
      text: res,
      parse_mode: 'Markdown',
      reply_markup: markup,
      reply_to_message_id: @message.message_id
    )
    nil
  when /^\/taft(_?test)?(@drrn_bot)?(\s+\d+\s+\d+)?/
    query = @message.text.sub(/\/taft(_?test)?(@drrn_bot)?\s*/, '')
    params = query.scan(/\d+/)
    width, height = params
    width  ||= rand(100..1600)
    height ||= rand(100..1600)
    url = "https://tafttest.com/#{width}x#{height}.png"
    reply_with_image url
    nil
  when /^\/lenny_?face(@drrn_bot)?(\s+.*|$)/
    query = @message.text.sub(/\/lenny_?face(@drrn_bot)?\s*/, '')
    "#{query} ( ͡° ͜ʖ ͡°)"
  when /с новым годом/i
    now = Time.now
    if (now.day == 31 && now.month == 12 && now.hour >= 15) || (now.day == 1 && now.month == 1)
      "С новым, блин, годом, #{@message.from.first_name}!"
    else
      nil
    end
  when /шерстяная колбаса/i
    send_markdown_message fur_sausage
  when /^\/this_fucking_cat(@drrn_bot)?/, /всрат(ый ко(т|шак)|ая ко(тя|ша)ра)/i, /всратая ша(у|ве)рма/i, /(шерстяной|пушистый) пид(а|о)рас/i #, /ъуъ/i, /уъу/i
    reply_with_image this_fucking_cat
  when /^\/this_fucking_fox(@drrn_bot)?/, /(шерстяная|съедобная|всратая) лиса/i, /(шерстяной|съедобный|всратый) лис(ец)?/i
    reply_with_image this_fucking_fox
  when /^\/(cppref|tableflip)(@drrn_bot)?(\s+.*|$)/ #, /блэт/i, /жеваный крот/i, /фак\b/i, /fuck/i
    query = @message.text.sub(/\/(cppref|tableflip)(@drrn_bot)?\s*/, '')
    "#{query} #{tableflip_str}"
  when /[aа]{4,}/i, /^\/infinite_scream/
    infinite_scream
  end
rescue => e then
  e.to_s
end

def handle_inline
  p query = @message.query
  i = 1
  results = [
    ['Пожать плечами', { message_text: "#{query} ¯\\_(ツ)_/¯" }],
    ['Перевернуть стол!', { message_text: "#{query} #{tableflip_str}" }],
    ['Вернуть стол!', { message_text: "#{query} #{unflip_str}" }],
    ['За Императора!', { message_text: dataline("warhammer_quotes") }],
    ['Вжухни!', { message_text: vzhuh_str(query), parse_mode: 'Markdown' }]
  ]
  unless query.empty?
    results << ['...чертов гук!', { message_text: goddamn_guk(query) }]
    results << ['Больше Х богу Х!', { message_text: "Больше #{query} богу #{query}!" }]
  end
  results.map! do |title, msg_content|
    content = Telegram::Bot::Types::InputTextMessageContent.new(msg_content)
    Telegram::Bot::Types::InlineQueryResultArticle.new(
      id: (i += 1),
      title: title,
      input_message_content: content
    )
  end
  if query[/всратый/i]
    {
      this_fucking_cat => 'Всратый кот.',
      this_fucking_fox => 'Всратый лис.',
    }.each do |url, title|
      results << Telegram::Bot::Types::InlineQueryResultPhoto.new(
        id: (i += 1), photo_url: url, thumb_url: url, title: title,
      )
    end
  end
  results
end

def goddamn_guk(str)
  @guk_str ||= " чёртов гук! Эти сукины сыны научились прятаться даже там! \
Я позвал ребят и мы начали палить что есть силы по этому чёртовому полю, \
мне даже прострелили каску, Джонни, это был просто ад, а не перестрелка! \
Нашего сержанта ранили, мы оттащили его в окоп и перевязали там же.\n— Ребята, \
передайте моей матери… — начал сержант Лейнисон.\n— Ты сам ей всё передашь, \
чёртов камикадзе!\nИ тогда мы вызвали наших ребят, наших славных соколов, \
которые сбросили на этих гуков напалм. Ты бы видел это, парень! Когда я \
приходил на это поле, оно было то зелёное, то золотое, а теперь оно ещё долго \
будет золотым и лишь потом почернеет, поглотив своей чернотой гуков. Я люблю \
запах напалма поутру. Весь холм был им пропитан. Это был запах… победы!\n\
Когда-нибудь эта война закончится."
  str + @guk_str
end

def handle_callback_heresy
  p data = @message.data
  case data.split('~').last
  when 'ересь' then 'Возможно, ересь.'
  when 'не ересь' then "Хреновый из Вас инквизитор, #{@message.from.first_name}."
  end
end

def handle_callback_answer
  p data = @message.data
  case data.split('~').last
  when 'answer-да' then 'Ну вот и славно!'
  when 'answer-нет' then 'На нет и суда нет!'
  end
end

Telegram::Bot::Client.run(token) do |bot|
  @bot = bot
  bot.listen do |message|
    @message = message
    case @message
    when Telegram::Bot::Types::InlineQuery
      results = handle_inline
      begin
        @bot.api.answer_inline_query(
          inline_query_id: @message.id,
          results: results,
          cache_time: 1
        )
      rescue => e then puts(e)
      end
    when Telegram::Bot::Types::Message
      res = handle_message
      begin
        @bot.api.send_message(
          chat_id: @message.chat.id,
          text: res,
          reply_to_message_id: @message.message_id
        ) if res.is_a? String
      rescue => e then puts(e)
      end
    when Telegram::Bot::Types::CallbackQuery
      # Here you can handle your callbacks from inline buttons
      if @message.data.split(?~).last.include? "ересь"
        res = handle_callback_heresy
        begin
          @bot.api.edit_message_text(
            chat_id: @message.data.split(?~).first,
            message_id: @message.message.message_id,
            text: res
          ) if res.is_a? String
        rescue => e then puts(e)
        end
      elsif @message.data.split(?~).last.include? "answer"
        res = handle_callback_answer
        begin
          @bot.api.answer_callback_query(
            callback_query_id: @message.id,
            text: res,
            show_alert: true
          ) if res.is_a? String
        rescue => e then puts(e)
        end
      end
    end
  end
end
