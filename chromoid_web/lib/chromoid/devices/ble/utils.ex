defmodule Chromoid.Devices.Ble.Utils do
  def format_address(address) do
    <<a, b, c, d, e, f>> = <<String.to_integer(address)::48>>
    :io_lib.format('~2.16.0B:~2.16.0B:~2.16.0B:~2.16.0B:~2.16.0B:~2.16.0B', [a, b, c, d, e, f])
  end
end
