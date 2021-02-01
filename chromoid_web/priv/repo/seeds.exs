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
alias Chromoid.Devices.Device
alias Chromoid.Devices.NFC
alias Chromoid.Devices.{NFC.ISO14443a, NFC.WebHook}

device =
  %Device{
    serial: "00000001",
    avatar_url: "https://api.adorable.io/avatars/285/00000001.png"
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

nfc =
  %ISO14443a{device_id: device.id}
  |> ISO14443a.changeset(%{
    abtAtq: Base.encode16(<<0, 4>>),
    abtAts: "",
    abtUid: Base.encode16(<<9, 83, 42, 178>>),
    btSak: 8
  })
  |> Repo.insert!()

{:ok, %WebHook{}} = NFC.new_webhook(nfc, %{url: "https://httpbin.org/post"})

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

me = %{
  "email" => "konnorrigby@gmail.com",
  "id" => "316741621498511363"
}

{:ok, user} = Chromoid.Accounts.register_user(%{"email" => me["email"]})
{:ok, user} = Chromoid.Accounts.sync_discord(user, me)

import Crontab.CronExpression

# {:ok, _schedule} =
#   Chromoid.Schedule.new_for(user, %{
#     crontab: "*/120 7-14 * * 1-5",
#     handler: Chromoid.DiscordNotificationSchedule
#   })

{:ok, _schedule} =
  Chromoid.Schedule.new_for(user, %{
    crontab: ~e[* * * * * *],
    handler: Chromoid.TestSchedule
  })
