defmodule ChromoidDiscord.Guild.CommandProcessor do
  @moduledoc """
  Processes commands from users
  """

  use GenStage
  require Logger
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  alias ChromoidDiscord.Guild.EventDispatcher

  import Nostrum.Struct.Embed

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    {:producer_consumer, %{guild: guild, current_user: current_user, config: config},
     subscribe_to: [via(guild, EventDispatcher)]}
  end

  @impl GenStage
  def handle_events(events, _from, %{current_user: %{id: current_user_id}} = state) do
    {actions, state} =
      Enum.reduce(events, {[], state}, fn
        # Ignore messages from self
        {:MESSAGE_CREATE, %{author: %{id: author_id}}}, {actions, state}
        when author_id == current_user_id ->
          {actions, state}

        {:MESSAGE_CREATE, message}, {actions, state} ->
          handle_message(message, {actions, state})

        _, {actions, state} ->
          {actions, state}
      end)

    {:noreply, actions, state}
  end

  @scripts_regex ~r/-script\s{0,1}info\s{0,1}(?<id>[0-9]+)/

  @doc false
  def handle_message(message, {actions, state}) do
    cond do
      String.contains?(message.content, "-help") ->
        handle_help(message, {actions, state})

      Regex.match?(@scripts_regex, message.content) ->
        handle_scripts_info(message, {actions, state})

      String.contains?(message.content, "-scripts") ->
        handle_scripts(message, {actions, state})

      true ->
        {actions, state}
    end
  end

  @help_help """
  `-help`
    Print this message

  `-help` `[command]`
    Print help about a command
  """

  @device_help """
  `-device` `list`
    Print the list of currently connected devices

  `-device` `info` `[device]`
    Print info about a currently connected device

  `-device` `photo` `[device]`
    Request a photo from a currently connected device
  """

  @color_help """
  `-color` `[address]` `[color]`
    Set the color of a device. Color should be a html color code. IE: `#ff69ff`
  """

  def handle_help(%{content: "-help color" <> _} = message, {actions, state}) do
    embed =
      %Nostrum.Struct.Embed{}
      |> put_title("Color Help")
      |> put_description("""
      `-color` `[address]` `[color]`
      """)
      |> put_field("**Available Friendly Color Names**", """
      `-color A4:C1:38:9D:1E:AD white`
      `-color A4:C1:38:9D:1E:AD silver`
      `-color A4:C1:38:9D:1E:AD gray`
      `-color A4:C1:38:9D:1E:AD black`
      `-color A4:C1:38:9D:1E:AD red`
      `-color A4:C1:38:9D:1E:AD maroon`
      `-color A4:C1:38:9D:1E:AD yellow`
      `-color A4:C1:38:9D:1E:AD olive`
      `-color A4:C1:38:9D:1E:AD lime`
      `-color A4:C1:38:9D:1E:AD green`
      `-color A4:C1:38:9D:1E:AD aqua`
      `-color A4:C1:38:9D:1E:AD teal`
      `-color A4:C1:38:9D:1E:AD blue`
      `-color A4:C1:38:9D:1E:AD navy`
      `-color A4:C1:38:9D:1E:AD fuchsia`
      `-color A4:C1:38:9D:1E:AD purple`
      `-color A4:C1:38:9D:1E:AD red`
      """)

    {actions ++ [{:create_message!, [message.channel_id, [embed: embed]]}], state}
  end

  def handle_help(message, {actions, state}) do
    embed =
      %Nostrum.Struct.Embed{}
      |> put_title("Help")
      |> put_description("I actually did this for this bot lmao")
      |> put_color(0xFF69FF)
      |> put_field("**Help Commands**", @help_help)
      |> put_field("**Device Commands**", @device_help)
      |> put_field("**Color Commands**", @color_help)

    {actions ++ [{:create_message!, [message.channel_id, [embed: embed]]}], state}
  end

  def handle_scripts_info(message, {actions, state}) do
    %{"id" => id} = Regex.named_captures(@scripts_regex, message.content)

    with %Chromoid.Lua.Script{} = script <- Chromoid.Lua.ScriptStorage.get_script(id),
         %Chromoid.Lua.Script{} = script <- Chromoid.Lua.ScriptStorage.load_script(script) do
      content = """
      ```lua
      #{script.content}
      ```
      """

      {actions ++ [{:create_message!, [message.channel_id, content]}], state}
    else
      nil ->
        {actions ++ [{:create_message!, [message.channel_id, "Could not find that script!"]}],
         state}
    end
  end

  def handle_scripts(message, {actions, state}) do
    embed =
      %Nostrum.Struct.Embed{}
      |> put_title("Help")
      |> put_description("All active scripts for this server")
      |> put_color(0xFF69FF)

    scripts = Chromoid.Lua.ScriptStorage.list_scripts()

    embed =
      Enum.reduce(scripts, embed, fn script, embed ->
        embed
        |> put_field(script.filename, """
        **id**: #{script.id}
        """)
      end)

    {actions ++ [{:create_message!, [message.channel_id, [embed: embed]]}], state}
  end
end
