# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Chromoid.Repo.insert!(%Chromoid.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Chromoid.Repo

device =
  %Chromoid.Devices.Device{
    serial: "abcdef",
    avatar_url: "https://api.adorable.io/avatars/285/abcdef.png"
  }
  |> Repo.insert!()

token = Chromoid.Devices.generate_token(device)

IO.warn(
  """
  Device Token: #{token}
  Device connect call:
    PhoenixClient.Socket.start_link(url: "ws://localhost:4000/device_socket/websocket?token=#{
    token
  }")
  """,
  []
)

%ChromoidDiscord.Guild.Config{
  guild_id: 755_804_994_053_341_194,
  device_status_channel_id: 755_850_677_548_220_468
}
|> Repo.insert!()

%ChromoidDiscord.Guild.Config{
  guild_id: 643_947_339_895_013_416,
  device_status_channel_id: 657_776_429_555_122_186
}
|> Repo.insert!()
