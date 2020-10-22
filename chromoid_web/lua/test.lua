client = discord.Client()
client:on('ready', function()
	-- client.user is the path for your bot
	print('Logged in as '.. client.user.username)
end)

client:on('messageCreate', function(message)
  print('channel message')
	if message.content == '!ping' then
		message.channel:send('Pong!')
	end
end)