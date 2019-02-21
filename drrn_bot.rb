# encoding: utf-8

require 'telegram/bot'
require 'net/http'

def start_time
  @start_time ||= Time.now
end
puts start_time

token = File.read('data/token.txt', encoding: 'UTF-8').lines.first.delete("\n")
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

def qr_it
  query = @message.text.sub(/\/qr_it(@drrn_bot)?\s+/, '')
  if query.empty? && @message.reply_to_message
    query = @message.reply_to_message.text
  end
  return if query.empty?
  url = qr_url(query)
  @bot.api.send_photo(
    chat_id: @message.chat.id,
    photo: url,
    reply_to_message_id: @message.message_id
  )
  nil
end

def qr_url(query)
  "http://chart.apis.google.com/chart?chs=300x300&cht=qr&choe=UTF-8&chl=#{query}"
end

def wh40kquote
  @quotes ||= File.read('data/warhammer_quotes.txt', encoding: 'UTF-8')
                  .split("\n")
  @quotes.sample
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

def handle_message
  puts "#{@message.from.first_name}: #{@message.text}"
  case @message.text
  when /^\/start(@drrn_bot)?$/
    "Ну привет, #{@message.from.first_name}"
  when /^\/stop(@drrn_bot)?$/
    "Покеда, #{@message.from.first_name}"
  when /^\/help(@drrn_bot)?$/
    help_msg
  when /^\/qr_it(@drrn_bot)?\s+.+/
    qr_it
  when /^\/(vzhuh|magic)(@drrn_bot)?(\s+.*|$)/
    return 'Сам себе вжухай!' if rand > 0.9

    query = @message.text.sub(/\/(vzhuh|magic)(@drrn_bot)?\s*/, '')
    res = vzhuh_str query
    send_markdown_message(res) if res.is_a? String
  when /^\/shrug(@drrn_bot)?(\s+.*|$)/
    query = @message.text.sub(/\/shrug(@drrn_bot)?\s*/, '')
    "#{query}¯\\_(ツ)_/¯"
  when /^\/(cppref|tableflip)(@drrn_bot)?(\s+.*|$)/, /блэт/i, /жеваный крот/i
    query = @message.text.sub(/\/(cppref|tableflip)(@drrn_bot)?\s*/, '')
    "#{query} #{tableflip_str}"
  when /Now you.+thinking with portals!/, /^\/portals(@drrn_bot)?/
    'Шас жахнет!'
  when /^\/uptime(@drrn_bot)?/
    "Я не сплю с #{start_time} (Целых #{Time.now - start_time} секунд!) Я крут!"
  when /^\/for_the_emperor(@drrn_bot)?$/, 'За Императора!'
    wh40kquote
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
    @bot.api.send_message(
      chat_id: @message.chat.id,
      text: 'Вы подозреваете ересь?',
      reply_markup: markup
    )
    nil
  when /^\/update_and_restart(@drrn_bot)?(\s+.*|$)/
    return 'Пошел нахуй.' unless admin_ids.include?(@message.from.id)

    delta = Time.now - start_time
    if delta < 60 # если перегружались меньше минуты назад
      return "Сейчас мы тут: #{%x{git show --oneline -s}}\n\
До следующего возможного перезапуска #{(60 - delta).to_i} секунд."
    end

    query = @message.text.sub(/\/update_and_restart(@drrn_bot)?\s*/, '')
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
  when /^\/roll(@drrn_bot)?\s*$/
    'Че кидать-то будем?'
  when /^\/roll(@drrn_bot)?\s+\d+d\d+(\s*[\>\<\=CcСс]\d+)?/
    query = @message.text.sub(/\/roll(@drrn_bot)?\s*/, '')
    roll(query)
  when /^\/taft(_?test)?(@drrn_bot)?(\s+\d+\s+\d+)?/
    query = @message.text.sub(/\/taft(_?test)?(@drrn_bot)?\s*/, '')
    params = query.scan(/\d+/)
    width, height = params
    width  ||= rand(100..1600)
    height ||= rand(100..1600)
    url = "https://tafttest.com/#{width}x#{height}.png"
    @bot.api.send_photo(
      chat_id: @message.chat.id,
      photo: url,
      reply_to_message_id: @message.message_id
    )
    nil
  when /^\/lenny_?face(@drrn_bot)?(\s+.*|$)/
    query = @message.text.sub(/\/lenny_?face(@drrn_bot)?\s*/, '')
    "#{query} ( ͡° ͜ʖ ͡°)"
  when /шерстяная колбаса/i
    send_markdown_message fur_sausage
  when /^\/this_fucking_cat/, /всратый кот/i
  	@bot.api.send_photo(
      chat_id: @message.chat.id,
      photo: "https://thiscatdoesnotexist.com/?сrutch=#{Time.now.to_i}",
      reply_to_message_id: @message.message_id
    )
  end
rescue => e then
  e.to_s
end

def handle_inline
  p query = @message.query
  i = 1
  results = [
    [(i += 1), 'Пожать плечами', { message_text: "#{query} ¯\\_(ツ)_/¯" }],
    [(i += 1), 'Перевернуть стол!', { message_text: "#{query} #{tableflip_str}" }],
    [(i += 1), 'За Императора!', { message_text: wh40kquote }],
    [(i += 1), 'Вжухни!', { message_text: vzhuh_str(query), parse_mode: 'Markdown' }]
  ]
  unless query.empty?
    results << [(i += 1), '...чертов гук!', { message_text: goddamn_guk(query) }]
    results << [(i += 1), 'Больше Х богу Х!', { message_text: "Больше #{query} богу #{query}!" }]
  end
  results.map do |arr|
    content = Telegram::Bot::Types::InputTextMessageContent.new(arr[2])
    Telegram::Bot::Types::InlineQueryResultArticle.new(
      id: arr[0],
      title: arr[1],
      input_message_content: content
    )
  end
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

def handle_callback
  p data = @message.data
  case data.split('~').last
  when 'ересь' then 'Возможно, ересь.'
  when 'не ересь' then 'Хреновый из вас инквизитор.'
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
      res = handle_callback
      begin
        @bot.api.edit_message_text(
          chat_id: @message.data.split(?~).first,
          message_id: @message.message.message_id,
          text: res
        ) if res.is_a? String
      rescue => e then puts(e)
      end
    end
  end
end
