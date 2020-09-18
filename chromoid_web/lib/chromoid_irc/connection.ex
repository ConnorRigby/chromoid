defmodule ChromoidIRC.Connection do
  use GenServer
  require Logger
  import Chromoid.Devices.Ble.Utils
  alias Chromoid.Devices.Color
  @device_list_regex ~r/-device(?:\s{1,})list/
  @device_info_regex ~r/-device(?:\s{1,})info(?:\s{1,})(?<serial>[a-z_0-9\-]+)/
  @device_photo_regex ~r/-device(?:\s{1,})photo(?:\s{1,})(?<serial>[a-z_0-9\-]+)/
  @color_hex_regex ~r/-color(?:\s{1,})(?<address>(?:[[:xdigit:]]{2}\:?){6})(?:\s{1,})(?<color>\#[[:xdigit:]]{6})/
  @color_friendly_regex ~r/-color(?:\s{1,})(?<address>(?:[[:xdigit:]]{2}\:?){6})(?:\s{1,})(?<color>(white)|(silver)|(gray)|(black)|(red)|(maroon)|(yellow)|(olive)|(lime)|(green)|(aqua)|(teal)|(blue)|(navy)|(fuchsia)|(purple))/

  defmodule Config do
    defstruct server: nil,
              port: nil,
              pass: nil,
              nick: nil,
              user: nil,
              name: nil,
              channel: nil,
              client: nil
  end

  alias ExIRC.Client
  alias ExIRC.SenderInfo

  def start_link(params) when is_map(params) do
    GenServer.start_link(__MODULE__, [struct(Config, params)])
  end

  def init([config]) do
    # Start the client and handler processes, the ExIRC supervisor is automatically started when your app runs
    {:ok, client} = ExIRC.start_link!()

    # Register the event handler with ExIRC
    Client.add_handler(client, self())

    # Connect and logon to a server, join a channel and send a simple message
    Logger.debug("Connecting to #{config.server}:#{config.port}")
    Client.connect!(client, config.server, config.port)

    {:ok, %Config{config | :client => client}}
  end

  def handle_info({:connected, server, port}, config) do
    Logger.debug("Connected to #{server}:#{port}")
    Logger.debug("Logging to #{server}:#{port} as #{config.nick}..")
    Client.logon(config.client, config.pass, config.nick, config.user, config.name)
    {:noreply, config}
  end

  def handle_info(:logged_in, config) do
    Logger.debug("Logged in to #{config.server}:#{config.port}")
    Logger.debug("Joining #{config.channel}..")
    Client.join(config.client, config.channel)
    {:noreply, config}
  end

  def handle_info({:login_failed, :nick_in_use} = error, config) do
    {:stop, error, config}
  end

  def handle_info(:disconnected, config) do
    Logger.debug("Disconnected from #{config.server}:#{config.port}")
    {:stop, :normal, config}
  end

  def handle_info({:joined, channel}, config) do
    Logger.debug("Joined #{channel}")
    Client.msg(config.client, :privmsg, config.channel, "Hello world!")
    {:noreply, config}
  end

  def handle_info({:names_list, channel, names_list}, config) do
    names =
      String.split(names_list, " ", trim: true)
      |> Enum.map(fn name -> " #{name}\n" end)

    Logger.info("Users logged in to #{channel}:\n#{names}")
    {:noreply, config}
  end

  def handle_info({:received, msg, %SenderInfo{}, _channel}, config) do
    cond do
      # String.match?(msg, @device_list_regex) ->
      #   handle_device_list(
      #     Regex.named_captures(@device_list_regex, msg),
      #     config
      #   )

      # String.match?(msg, @device_photo_regex) ->
      #   handle_device_photo(
      #     Regex.named_captures(@device_photo_regex, msg),
      #     config
      #   )

      # String.match?(msg, @device_info_regex) ->
      #   handle_device_info(
      #     Regex.named_captures(@device_info_regex, msg),
      #     config
      #   )

      String.match?(msg, @color_hex_regex) ->
        handle_color(
          Regex.named_captures(@color_hex_regex, msg),
          config
        )

      String.match?(msg, @color_friendly_regex) ->
        handle_color(
          Regex.named_captures(@color_friendly_regex, msg),
          config
        )

      String.match?(msg, ~r/-color(.)+/) ->
        handle_color_error(config)

      true ->
        {:noreply, config}
    end
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, config) do
    {:noreply, config}
  end

  def handle_color(
        %{"address" => address_with_colons, "color" => color_arg},
        config
      ) do
    address = String.replace(address_with_colons, ":", "") |> String.to_integer(16) |> to_string()
    color = decode_color_arg(color_arg)

    device_id = Chromoid.Devices.Presence.device_id_for_address(address)

    if device_id do
      # _device = Repo.get!(Chromoid.Devices.Device, device_id)

      Logger.info(
        "Sending color change command: #{format_address(address)} #{Color.format_color(color)}"
      )

      meta = Chromoid.Devices.Color.set_color(address, color)

      Client.msg(
        config.client,
        :privmsg,
        config.channel,
        "#{format_address(address)} color updated: #{Color.format_color(meta.color)}"
      )

      {:noreply, config}
    else
      error_message = "couldn't find the device that #{format_address(address)} is attached to"
      Client.msg(config.client, :privmsg, config.channel, error_message)
      {:noreply, config}
    end
  end

  defp decode_color_arg("#" <> hex_str) do
    String.to_integer(hex_str, 16)
  end

  defp decode_color_arg("white"), do: 0xFFFFFF
  defp decode_color_arg("silver"), do: 0xC0C0C0
  defp decode_color_arg("gray"), do: 0x808080
  defp decode_color_arg("black"), do: 0x000000
  defp decode_color_arg("red"), do: 0xFF0000
  defp decode_color_arg("maroon"), do: 0x800000
  defp decode_color_arg("yellow"), do: 0xFFFF00
  defp decode_color_arg("olive"), do: 0x808000
  defp decode_color_arg("lime"), do: 0x00FF00
  defp decode_color_arg("green"), do: 0x008000
  defp decode_color_arg("aqua"), do: 0x00FFFF
  defp decode_color_arg("teal"), do: 0x008080
  defp decode_color_arg("blue"), do: 0x0000FF
  defp decode_color_arg("navy"), do: 0x000080
  defp decode_color_arg("fuchsia"), do: 0xFF00FF
  defp decode_color_arg("purple"), do: 0x800080

  def handle_color_error(config) do
    Logger.error("Error processing color message")

    """
    Could not decode color arguments.
    `-color` `[address]` `color`
    See `-help color` for more info

    Examples:
    `-color A4:C1:38:9D:1E:AD red`
    `-color A4:C1:38:9D:1E:AD green`
    `-color A4:C1:38:9D:1E:AD blue`
    `-color A4:C1:38:9D:1E:AD #ff0000`
    `-color A4:C1:38:9D:1E:AD #00ff00`
    `-color A4:C1:38:9D:1E:AD #0000ff`
    """
    |> String.split("\n")
    |> Enum.map(fn msg ->
      Client.msg(config.client, :privmsg, config.channel, msg)
    end)

    {:noreply, config}
  end

  def terminate(_, state) do
    # Quit the channel and close the underlying client connection when the process is terminating
    Client.quit(state.client, "Goodbye, cruel world.")
    Client.stop!(state.client)
    :ok
  end
end
