defmodule Chromoid.ConfigWizard do
  use GenServer
  alias Chromoid.Config

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    if should_start_wizard?() do
      args = [
        ifname: "wlan0",
        device_info: get_info()
      ]

      VintageNetWizard.run_wizard(args)
    end

    :ok = VintageNet.subscribe(["interface", :_, "connection"])
    {:ok, %{}}
  end

  def handle_info({VintageNet, ["interface", :_, "connection"], _, new_value, _}, state) when new_value in [:lan, :internet] do
    :ok = Config.set_wifi_provisioned()
    {:noreply, state}
  end

  def handle_info({VintageNet, ["interface", :_, "connection"], _, _, _}, state) do
    {:noreply, state}
  end

  def should_start_wizard?() do
    not currently_connected?() || not Config.wifi_provisioned?()
  end

  def currently_connected?() do
    # VintageNet.get_by_prefix(["interface", _, "connection"])
    VintageNet.get_by_prefix([])
    |> Enum.find_value(fn
      {["interface", _ifname, "connection"], value} when value in [:lan, :internet] -> true
      _ -> false
    end)
  end

  def get_info do
    %{
      "nerves_serial_number" => serial
    } = Nerves.Runtime.KV.get_all()

    %{
      "nerves_fw_platform" => platform,
      "nerves_fw_product" => product,
      "nerves_fw_uuid" => uuid,
      "nerves_fw_vcs_identifier" => vcs,
      "nerves_fw_version" => version
    } = Nerves.Runtime.KV.get_all_active()

    socket_url = Config.get_socket_url()

    [
      {"Serial", serial},
      {"Chromoid URL", socket_url || "UNPROVISIONED"},
      {"Platform", platform},
      {"Product", product},
      {"UUID", uuid},
      {"VCS", vcs},
      {"Version", version}
    ]
  end
end
