defmodule Chromoid.CameraProvider do
  @callback jpeg() :: {:ok, binary()} | {:error, any()}
end
