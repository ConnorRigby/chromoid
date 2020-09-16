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

default_email = "admin@chromo.id"
default_password = "password123456"
alias Chromoid.Repo

{:ok, user} =
  Chromoid.Administration.register_admin(%{
    email: default_email,
    password: default_password
  })

device =
  %Chromoid.Devices.Device{
    serial: "abcdef",
    avatar_url: "https://api.adorable.io/avatars/285/abcdef.png"
  }
  |> Repo.insert!()

token = Chromoid.Devices.generate_token(device)

IO.warn(
  """
  User Credentials: #{user.email}:#{default_password}
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
