defmodule ChromoidDiscord.Guild.LuaConsumerTest do
  use Chromoid.DataCase

  test "executes script" do
    guild = ChromoidDiscord.FakeDiscordSource.default_guild()
    discord_user = ChromoidDiscord.FakeDiscordSource.default_user()
    channel = ChromoidDiscord.FakeDiscordSource.default_channel()

    {:ok, _pid} = ChromoidDiscord.FakeDiscordSource.init_guild(guild, discord_user)

    {:ok, user} =
      Chromoid.Accounts.register_user(%{
        "email" => "test+#{System.unique_integer([:positive])}@test.com"
      })

    {:ok, script} =
      Chromoid.Lua.ScriptStorage.new_script_for_user(user, %{
        "filename" => "test#{System.unique_integer([:positive])}.lua"
      })

    {:ok, _runtime} = ChromoidDiscord.Guild.LuaConsumer.activate_script(guild, script)
    ChromoidDiscord.FakeDiscordSource.message_create(guild, channel, "hello, world")
  end

  test "script logging" do
    guild = ChromoidDiscord.FakeDiscordSource.default_guild()
    discord_user = ChromoidDiscord.FakeDiscordSource.default_user()
    channel = ChromoidDiscord.FakeDiscordSource.default_channel()

    {:ok, user} =
      Chromoid.Accounts.register_user(%{
        "email" => "test+#{System.unique_integer([:positive])}@test.com"
      })

    {:ok, script} =
      Chromoid.Lua.ScriptStorage.new_script_for_user(user, %{
        "filename" => "test#{System.unique_integer([:positive])}.lua"
      })

    Chromoid.Lua.ScriptStorage.save_script(%{
      script
      | content: """
        -- Create a client connection
        client = discord.Client()
        print(client)

        -- 'ready' event will be emitted when the script is loaded
        client:on('ready', function()
          -- client.user is the path for your bot
          print('Script started as '.. client.user.username)
        end)

        -- 'messageCreate' callback will be called every time a message is sent
        client:on('messageCreate', function(message)
          -- handle messages here
          logger.info("received message: "..message.content)
        end)

        print(client)
        return client
        """
    })

    ChromoidDiscord.FakeDiscordSource.init_guild(guild, discord_user)
    {:ok, _runtime} = ChromoidDiscord.Guild.LuaConsumer.activate_script(guild, script)
    ChromoidDiscord.Guild.LuaConsumer.subcribe_script(guild, script.id, self())
    ChromoidDiscord.FakeDiscordSource.message_create(guild, channel, "hello, world")
    assert_receive {:tty_data, "\e[34m\r\n[info] received message: hello, world\r\n\e[22m"}
  end
end
