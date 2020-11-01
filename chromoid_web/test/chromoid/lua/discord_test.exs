defmodule Chromoid.Lua.DiscordTest do
  use Chromoid.DataCase
  alias Chromoid.Lua

  setup do
    guild = ChromoidDiscord.FakeDiscordSource.default_guild()
    config = ChromoidDiscord.FakeDiscordSource.default_config(guild)
    current_user = ChromoidDiscord.FakeDiscordSource.default_user()
    {:ok, guild: guild, config: config, user: current_user}
  end

  test "script executes", %{guild: guild, user: user} do
    script = %Lua.Script{filename: "test.lua"}
    lua = Lua.init(guild, user, script)

    {[client], lua} =
      :luerl.do(
        """
        -- Create a client connection
        client = discord.Client()

        -- 'ready' event will be emitted when the script is loaded
        client:on('ready', function()
          -- client.user is the path for your bot
          print('Script started as '.. client.user.username)
        end)

        -- 'messageCreate' callback will be called every time a message is sent
        client:on('messageCreate', function(message)
          -- handle messages here
          message.channel:send(message.content)
        end)

        return client
        """,
        lua
      )

    assert_receive {:client, ^client}

    {_, lua} = Lua.Discord.Client.ready(client, lua)
    %{id: channel_id} = channel = ChromoidDiscord.FakeDiscordSource.default_channel()
    message = ChromoidDiscord.FakeDiscordSource.default_message(guild, channel, "test test test")
    {_, _lua} = Lua.Discord.Client.message_create(client, message, channel, lua)

    assert_receive {:action, {:create_message!, [^channel_id, "test test test"]}}
  end

  test "script exception", %{guild: guild, user: user} do
    script = %Lua.Script{filename: "test.lua"}
    lua = Lua.init(guild, user, script)

    {[client], lua} =
      :luerl.do(
        """
        -- Create a client connection
        client = discord.Client()

        -- 'ready' event will be emitted when the script is loaded
        client:on('ready', function()
        -- handle messages here
        -- this will fail!
          message.channel:typo()
        end)

        return client
        """,
        lua
      )

    assert_receive {:client, ^client}
    assert {:lua_error, _error, lua} = catch_error(Lua.Discord.Client.ready(client, lua))

    assert [{"client:on('ready')", [], [file: "test.lua", line: 8]}] ==
             :new_luerl.get_stacktrace(lua)
  end

  test "message.user", %{guild: guild, user: user} do
    script = %Lua.Script{filename: "test.lua"}
    lua = Lua.init(guild, user, script)

    {[client], lua} =
      :luerl.do(
        """
        -- Create a client connection
        client = discord.Client()

        -- 'ready' event will be emitted when the script is loaded
        client:on('ready', function()
          -- client.user is the path for your bot
          print('Script started as '.. client.user.username)
        end)

        -- 'messageCreate' callback will be called every time a message is sent
        client:on('messageCreate', function(message)
          -- handle messages here
          message.channel:send(message.author:mention().. " urmom")
        end)

        return client
        """,
        lua
      )

    assert_receive {:client, ^client}

    {_, lua} = Lua.Discord.Client.ready(client, lua)
    %{id: channel_id} = channel = ChromoidDiscord.FakeDiscordSource.default_channel()
    message = ChromoidDiscord.FakeDiscordSource.default_message(guild, channel, "test test test")
    {_, _lua} = Lua.Discord.Client.message_create(client, message, channel, lua)

    assert_receive {:action, {:create_message!, [^channel_id, "<@755805360123805987> urmom"]}}
  end

  test "typingStart", %{guild: guild, user: user} do
    script = %Lua.Script{filename: "test.lua"}
    lua = Lua.init(guild, user, script)

    {[client], lua} =
      :luerl.do(
        """
        -- Create a client connection
        client = discord.Client()

        client:on('typingStart', function(user_id, channel_id, timestamp)
          return user_id, channel_id, timestamp
        end)

        return client
        """,
        lua
      )

    assert_receive {:client, ^client}

    {_, lua} = Lua.Discord.Client.ready(client, lua)
    assert {[100, 200, 300], _lua} = Lua.Discord.Client.typing_start(client, 100, 200, 300, lua)
  end
end
