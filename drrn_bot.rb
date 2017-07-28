require 'telegram/bot'
require 'net/http'

$start_time = Time.now

$token = File.read('data/token.txt', encoding: 'UTF-8')
$drrn_id = File.read('data/drrn_id.txt').to_i
$admin_ids = File.read('data/admins.txt').split("\n").map.to_i.compact

def help_msg
%Q{Я умею:
	* /roll 3d6 - брось дайсы!
	* /for_the_emperor - Мотивирующая фраза от вашего лорда-комиссара.
	* /qr_it - Сделать qr-код.
	* /tableflip - Переверни стол!
	* /vzhuh - Вжух!
	* Нихуя
А еще я сплю большую часть времени.
}
end

def roll(text)
	res = text.scan(/\d+/).map(&:to_i)
	p res
	if res.size == 2
		rolls = []
		return 'Куда тебе столько, ебанутый?' if res[0] > 1000
		return 'Нуль себе дерни, пес' if res[1] == 0
		res[0].times do |n|
			rolls << rand(res[1]) + 1
		end
		sum = rolls.inject(0) do |res, x|
			res + x
		end
		"Бросок #{res[0]}d#{res[1]}: #{sum} (#{rolls.join(', ')})."
	else
		return 'Че-то ты криво рольнул.'
	end
end

def tableflip_str
	@tableflip_str ||= '(╯°□°）╯︵ ┻━┻'
end

def qr_it(message, bot)
	query = message.text.sub(/\/qr_it\s+/,'')
	url = qr_url(query)
	bot.api.send_photo(chat_id: message.chat.id, photo: url, reply_to_message_id: message.message_id)
	nil
end

def qr_url(query)
	"http://chart.apis.google.com/chart?chs=300x300&cht=qr&choe=UTF-8&chl=#{query}"
end

def wh40kquote
	@quotes ||= File.read('data/warhammer_quotes.txt', encoding: 'UTF-8').split("\n")
	@quotes.sample
end

def vzhuh_str(mes)
%Q{``` ∧＿∧
( ･ω･｡)つ━☆・*。
⊂　 ノ 　　　・゜+.
しーＪ　　　°。+ *´¨)
　　　　　　　　　.· ´¸.·*´¨) ¸.·*¨)
　　　　　　　　　　(¸.·´ (¸.·'* ☆ #{mes}```}
end

def handle_message(message, bot)
	begin
		p text = message.text && message.text.gsub('@drrn_bot','').strip
		case text
		when '/start'
			"Ну привет, #{message.from.first_name}"
		when '/stop'
			"Покеда, #{message.from.first_name}"
		when '/help'
			help_msg
		when /\/qr_it\s.+/
			qr_it(message, bot)
		when /\/vzhuh\s?.?/
			query = text.sub(/\/vzhuh\s?/, '')
			res = vzhuh_str(query)
			bot.api.send_message(chat_id: message.chat.id, text: res, reply_to_message_id: message.message_id, parse_mode: 'Markdown') if res.is_a? String
			nil
		when '/cppref'
			tableflip_str
		when /\/tableflip\s?.?/
			query = text.sub(/\/tableflip\s?/, '')
			"#{query} #{tableflip_str}"
		when /Now you.+thinking with portals!/, '/portals'
			'Шас жахнет!'
			# bot.api.send_sticker(chat_id: message.chat.id, sticker: 'CAADAgADEgAD3Q_4SCfsQNkInMIsAg')
			# nil
		when '/for_the_emperor', 'За Императора!'
			wh40kquote
		when '/heresy'
			kb = [
				Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Да', callback_data: "#{message.chat.id}~ересь"),
				Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Нет', callback_data: "#{message.chat.id}~не ересь")
			]
			markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
			bot.api.send_message(chat_id: message.chat.id, text: 'Вы подозреваете ересь?', reply_markup: markup)
			nil
		when /\/update_and_restart\s?.?/
			return 'Пошел нахуй.' unless $admin_ids.include?(message.from.id)
			delta = Time.now - $start_time
			if delta < 60 # если перегружались меньше минуты назад
				return "Теперь мы тут: #{%x{git show --oneline -s}}\nДо следующего возможного перезапуска #{(60 - delta).to_i} секунд."
			end
			query = text.sub(/\/update_and_restart\s?/, '')
			if query.size > 0
				bot.api.send_message(chat_id: message.chat.id, text: "Пробуем чекаутить #{query}")
				res = %x{git checkout #{query}}
				bot.api.send_message(chat_id: message.chat.id, text: res)
			end
			bot.api.send_message(chat_id: message.chat.id, text: 'Ок, перегружаюсь.')
			sleep 5
			abort # просто пристрелить себя, демон сам все сделает
		when '/roll'
			'Че кидать-то будем?'
		when /\/roll\s\d+d\d+/
			roll(text)
		end
	rescue => e then
		e.to_s
	end
end

def handle_inline(message, bot)
	p query = message.query
	i = 1
	results = [
		[(i += 1), 'Пожать плечами', "#{query} ¯\\_(ツ)_/¯"],
		[(i += 1), 'Перевернуть стол!', "#{query} #{tableflip_str}"],
		[(i += 1), 'За Императора!', wh40kquote]
	]
	results << [(i += 1), '...чертов гук!', goddamn_guk(query)] if query.size > 0
	results.map do |arr|
		Telegram::Bot::Types::InlineQueryResultArticle.new(
			id: arr[0],
			title: arr[1],
			input_message_content: Telegram::Bot::Types::InputTextMessageContent.new(message_text: arr[2])
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

def handle_callback(message, bot)
	p data = message.data
	case data.split(?~).last
	when 'ересь' then 'Возможно, ересь.'
	when 'не ересь' then 'Хреновый из вас инквизитор.'
	end
end

Telegram::Bot::Client.run($token) do |bot|
	bot.listen do |message|
		case message
		when Telegram::Bot::Types::InlineQuery
			results = handle_inline(message, bot)
			begin
				bot.api.answer_inline_query(inline_query_id: message.id, results: results, cache_time: 1)
			rescue => e then puts(e)
			end
		when Telegram::Bot::Types::Message
			res = handle_message(message, bot)
			begin
				bot.api.send_message(chat_id: message.chat.id, text: res, reply_to_message_id: message.message_id) if res.is_a? String
			rescue => e then puts(e)
			end
		when Telegram::Bot::Types::CallbackQuery
			# Here you can handle your callbacks from inline buttons
			res = handle_callback(message, bot)
			begin
				bot.api.edit_message_text(chat_id: message.data.split(?~).first, message_id: message.message.message_id, text: res) if res.is_a? String
			rescue => e then puts(e)
			end
		end
	end
end
