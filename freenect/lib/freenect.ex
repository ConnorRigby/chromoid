defmodule Freenect do
  use GenServer
  require Logger

  @freenect_log_fatal 0x0
  @freenect_log_error 0x1
  @freenect_log_warning 0x2
  @freenect_log_notice 0x3
  @freenect_log_info 0x4
  @freenect_log_debug 0x5
  @freenect_log_spew 0x6
  @freenect_log_flood 0x7

  @freenect_tilt_status_stopped 0x00
  @freenect_tilt_status_limit 0x01
  @freenect_tilt_status_moving 0x04

  @freenect_led_off 0
  @freenect_led_green 1
  @freenect_led_red 2
  @freenect_led_yellow 3
  @freenect_led_blink_green 4
  @freenect_led_blink_green_but_its_five 5
  @freenect_led_blink_red_yellow 6

  @freenect_depth_11bit 0
  @freenect_depth_10bit1
  @freenect_depth_registered 4
  @freenect_depth_mm 5

  @event_buffer_rgb 0x0
  @event_buffer_depth 0x1
  @event_buffer_rgb_jpeg 0x2
  @event_buffer_depth_jpeg 0x3

  @event_led_state 0x7
  @event_tilt_state 0x8
  @event_freenect_log 0x9

  @command_get_buffer_rgb 0x10
  @command_get_buffer_depth 0x11
  @command_get_buffer_rgb_jpeg 0x12
  @command_get_buffer_depth_jpeg 0x13

  @command_get_led_state 0x17
  @command_get_tilt_state 0x18

  @command_set_led_state 0x27
  @command_set_tilt_state 0x28

  @command_set_video_mode 0x30
  @command_set_depth_mode 0x31

  defmodule TiltState do
    defstruct accelerometer_x: 0,
              accelerometer_y: 0,
              accelerometer_z: 0,
              tilt_angle: 0,
              tilt_status: nil
  end

  def get_buffer_rgb(pid \\ __MODULE__) do
    GenServer.call(pid, :get_buffer_rgb)
  end

  def get_buffer_depth(pid \\ __MODULE__) do
    GenServer.call(pid, :get_buffer_depth)
  end

  def get_buffer_rgb_jpeg(pid \\ __MODULE__) do
    GenServer.call(pid, :get_buffer_rgb_jpeg)
  end

  def get_buffer_depth_jpeg(pid \\ __MODULE__) do
    GenServer.call(pid, :get_buffer_depth_jpeg)
  end

  def get_led_state(pid \\ __MODULE__) do
    GenServer.call(pid, :get_led_state)
  end

  def get_tilt_state(pid \\ __MODULE__) do
    GenServer.call(pid, :get_tilt_state)
  end

  def set_tilt_state(pid \\ __MODULE__, angle) do
    GenServer.call(pid, {:set_tilt_state, angle})
  end

  def set_led_state(pid \\ __MODULE__, led_state) do
    GenServer.call(pid, {:set_led_state, led_state})
  end

  @doc """
  /// Enumeration of depth frame states
  /// See http://openkinect.org/wiki/Protocol_Documentation#RGB_Camera for more information.
      typedef enum {
        FREENECT_DEPTH_11BIT        = 0, /**< 11 bit depth information in one uint16_t/pixel */
        FREENECT_DEPTH_10BIT        = 1, /**< 10 bit depth information in one uint16_t/pixel */
        FREENECT_DEPTH_11BIT_PACKED = 2, /**< 11 bit packed depth information */
        FREENECT_DEPTH_10BIT_PACKED = 3, /**< 10 bit packed depth information */
        FREENECT_DEPTH_REGISTERED   = 4, /**< processed depth data in mm, aligned to 640x480 RGB */
        FREENECT_DEPTH_MM           = 5, /**< depth to each pixel in mm, but left unaligned to RGB image */
      } freenect_depth_format;
  """
  def set_video_mode(pid \\ __MODULE__, mode) do
    GenServer.call(pid, {:set_video_mode, mode})
  end

  def set_depth_mode(pid \\ __MODULE__, mode) do
    GenServer.call(pid, {:set_depth_mode, mode})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    port = start_port()
    {:ok, %{port: port, caller: nil, ready: false, tilt: %TiltState{}, led: :off}}
  end

  def handle_info({port, {:data, <<@event_buffer_rgb, rgb::binary>>}}, %{port: port} = state) do
    if state.caller, do: GenServer.reply(state.caller, {:ok, rgb})
    {:noreply, %{state | caller: nil}}
  end

  def handle_info({port, {:data, <<@event_buffer_depth, rgb::binary>>}}, %{port: port} = state) do
    if state.caller, do: GenServer.reply(state.caller, {:ok, rgb})
    {:noreply, %{state | caller: nil}}
  end

  def handle_info({port, {:data, <<@event_buffer_rgb_jpeg, jpeg::binary>>}}, %{port: port} = state) do
    if state.caller, do: GenServer.reply(state.caller, {:ok, jpeg})
    {:noreply, %{state | caller: nil}}
  end

  def handle_info({port, {:data, <<@event_buffer_depth_jpeg, jpeg::binary>>}}, %{port: port} = state) do
    if state.caller, do: GenServer.reply(state.caller, {:ok, jpeg})
    {:noreply, %{state | caller: nil}}
  end

  def handle_info({port, {:data, <<@event_led_state, led_state::8>>}}, %{port: port} = state) do
    {:noreply, _set_led_state(led_state, state)}
  end

  def handle_info(
        {port, {:data, <<@event_tilt_state, tilt_state::binary>>}},
        %{port: port} = state
      ) do
    {:noreply, _set_tilt_state(tilt_state, state)}
  end

  def handle_info(
        {port, {:data, <<@event_freenect_log, level::8, msg::binary>>}},
        %{port: port} = state
      ) do
    handle_log(level, msg)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("Port exit: #{inspect(status)} restarting...")
    if state.caller, do: GenServer.call(state.caller, {:error, :timeout})
    Process.sleep(1000)
    port = start_port()
    {:noreply, %{state | port: port, caller: nil}}
  end

  def handle_info(:ready, state) do
    {:noreply, %{state | ready: true}}
  end

  def handle_info(:timeout, %{caller: {_, _} = caller} = state) do
    GenServer.reply(caller, {:error, :timeout})
    {:noreply, %{state | caller: nil}}
  end

  def handle_info(unknown, state) do
    {:stop, {:unhandled_info, unknown}, state}
  end

  def handle_call(_call, _from, %{ready: false} = state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_call(:get_buffer_rgb, from, state) do
    Port.command(state.port, <<@command_get_buffer_rgb::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call(:get_buffer_depth, from, state) do
    Port.command(state.port, <<@command_get_buffer_depth::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call(:get_buffer_rgb_jpeg, from, state) do
    Port.command(state.port, <<@command_get_buffer_rgb_jpeg::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call(:get_buffer_depth_jpeg, from, state) do
    Port.command(state.port, <<@command_get_buffer_depth_jpeg::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call(:get_led_state, from, state) do
    Port.command(state.port, <<@command_get_led_state::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call(:get_tilt_state, from, state) do
    Port.command(state.port, <<@command_get_tilt_state::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call({:set_tilt_state, angle}, from, state) do
    Port.command(state.port, <<@command_set_tilt_state::8, angle::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call({:set_led_state, led_state}, from, state) do
    Port.command(state.port, <<@command_set_led_state::8, atom_to_led_state(led_state)::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call({:set_video_mode, mode}, from, state) do
    Port.command(state.port, <<@command_set_video_mode::8, atom_to_video_mode(mode)::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call({:set_depth_mode, mode}, from, state) do
    Port.command(state.port, <<@command_set_depth_mode::8, atom_to_depth_mode(mode)::8>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def start_port do
    Process.send_after(self(), :ready, 2000)

    Port.open({:spawn_executable, port_executable()}, [
      {:args, []},
      :binary,
      :exit_status,
      {:packet, 4},
      :nouse_stdio,
      {:env, [{'LD_LIBRARY_PATH', to_charlist(Application.app_dir(:freenect, ["priv", "lib"]))}]}
    ])
  end

  def port_executable(), do: Application.app_dir(:freenect, ["priv", "freenect_port"])

  defp _set_led_state(led_state, state) do
    led = led_state_to_atom(led_state)

    if state.caller do
      GenServer.reply(state.caller, led)
      %{state | led: led, caller: nil}
    else
      %{state | led: led}
    end
  end

  defp led_state_to_atom(@freenect_led_off), do: :off
  defp led_state_to_atom(@freenect_led_green), do: :green
  defp led_state_to_atom(@freenect_led_red), do: :red
  defp led_state_to_atom(@freenect_led_yellow), do: :yellow
  defp led_state_to_atom(@freenect_led_blink_green), do: :blink_green
  defp led_state_to_atom(@freenect_led_blink_green_but_its_five), do: :blink_green
  defp led_state_to_atom(@freenect_led_blink_red_yellow), do: :blink_red_yellow

  defp atom_to_led_state(:off), do: @freenect_led_off
  defp atom_to_led_state(:green), do: @freenect_led_green
  defp atom_to_led_state(:red), do: @freenect_led_red
  defp atom_to_led_state(:yellow), do: @freenect_led_yellow
  defp atom_to_led_state(:blink_green), do: @freenect_led_blink_green
  defp atom_to_led_state(:blink_red_yellow), do: @freenect_led_blink_red_yellow

  defp atom_to_video_mode(:freenect_video_rgb), do: @freenect_video_rgb
  defp atom_to_video_mode(:freenect_video_bayer), do: @freenect_video_bayer
  defp atom_to_video_mode(:freenect_video_ir_8bit), do: @freenect_video_ir_8bit
  defp atom_to_video_mode(:freenect_video_ir_10bit), do: @freenect_video_ir_10bit
  defp atom_to_video_mode(:freenect_video_ir_10bit_packed), do: @freenect_video_ir_10bit_packed
  defp atom_to_video_mode(:freenect_video_yuv_rgb), do: @freenect_video_yuv_rgb
  defp atom_to_video_mode(:freenect_video_yuv_raw), do: @freenect_video_yuv_raw

  defp atom_to_depth_mode(:freenect_depth_11bit), do: @freenect_depth_11bit
  defp atom_to_depth_mode(:freenect_depth_10bit), do: @freenect_depth_10bit
  defp atom_to_depth_mode(:freenect_depth_registered), do: @freenect_depth_registered
  defp atom_to_depth_mode(:freenect_depth_mm), do: @freenect_depth_mm

  defp _set_tilt_state(<<x::16, y::16, z::16, tilt_angle::8, tilt_status::8>>, state) do
    tilt_state = %TiltState{
      accelerometer_x: x,
      accelerometer_y: y,
      accelerometer_z: z,
      tilt_angle: tilt_angle,
      tilt_status: tilt_status_to_atom(tilt_status)
    }

    if state.caller do
      GenServer.reply(state.caller, tilt_state)
      %{state | tilt: tilt_state, caller: nil}
    else
      %{state | tilt: tilt_state}
    end
  end

  defp tilt_status_to_atom(@freenect_tilt_status_stopped), do: :stopped
  defp tilt_status_to_atom(@freenect_tilt_status_limit), do: :limit
  defp tilt_status_to_atom(@freenect_tilt_status_moving), do: :moving

  @compile {:inline, handle_log: 2}
  if Version.match?(System.version(), "~> 1.11") do
    defp handle_log(@freenect_log_fatal, msg), do: Logger.emergency(msg)
    defp handle_log(@freenect_log_notice, msg), do: Logger.notice(msg)
  else
    defp handle_log(@freenect_log_fatal, msg), do: Logger.error(msg)
    defp handle_log(@freenect_log_notice, msg), do: Logger.info(msg)
  end

  defp handle_log(@freenect_log_error, msg), do: Logger.error(msg)
  defp handle_log(@freenect_log_warning, msg), do: Logger.warn(msg)
  defp handle_log(@freenect_log_info, msg), do: Logger.info(msg)
  defp handle_log(@freenect_log_debug, msg), do: Logger.debug(msg)
  defp handle_log(@freenect_log_spew, msg), do: Logger.debug(msg)
  defp handle_log(@freenect_log_flood, msg), do: Logger.debug(msg)
end
