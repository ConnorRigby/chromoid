defmodule Chromoid.Devices.NFC.ColorAction do
  @moduledoc """
  Changes the color of one a ble_link by it's `address`


  * `address` format can be like A4:C1:38:F0:BA:29 or A4C138F0BA29
  * `color` format can be one of the html common color names or #rrggbb
  """

  require Logger
  alias Chromoid.Devices.NFC.Action
  # import Chromoid.Devices.Ble.Utils
  @behaviour Action

  @impl Action
  def perform(%Action{args: %{"address" => address_with_colons, "color" => color_arg}} = _action) do
    address = String.replace(address_with_colons, ":", "") |> String.to_integer(16) |> to_string()
    color = decode_color_arg(color_arg)

    # device_id = Chromoid.Devices.Presence.device_id_for_ble_address(address)
    _meta = Chromoid.Devices.Color.set_color(address, color)
    :ok
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

  @impl Action
  def fields do
    [
      {:color, :string, placeholder: "Hex format"},
      {:address, :string, placeholder: "Address of the BLE device"}
    ]
  end
end
