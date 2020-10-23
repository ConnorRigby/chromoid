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
end
