defmodule NFC.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  @moduledoc false

  def load_nif() do
    nif_binary = Application.app_dir(:nfc, "priv/nfc_nif")
    libnfc_install_dir = Application.app_dir(:nfc, "priv/lib")
    IO.inspect(File.ls!(libnfc_install_dir))
    System.put_env("LD_LIBRARY_PATH", libnfc_install_dir)
    :erlang.load_nif(to_charlist(nif_binary), 0)
  end

  def open(_pid) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def close(_nfc) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
