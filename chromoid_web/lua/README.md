# Chromoid Lua Scripting Basic API and Usage

This contains documentation for the Basic Lua scripting engine built into
Chromoid. The files in this directory contain examples of usage.

The basic API is meant to mimic [Discordia](https://github.com/SinisterRectus/Discordia)
hoever, not 100% of the API is mimiced.

## Client

The most basic component in the library is a `client` class.

```lua
client = discord.Client()
```

### ready event

```lua
client:on('ready', function()
  -- client.user is the path for your bot
  print('Logged in as '.. client.user.username)
end)
```

### messageCreate event

```lua
client:on('messageCreate', function(message)
  message.channel:send('echo: '.. message.content)
end)
```
