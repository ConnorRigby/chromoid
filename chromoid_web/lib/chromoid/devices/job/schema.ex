defmodule Chromoid.Devices.Job.Schema do
  defmacro __using__(_) do
    quote location: :keep do
      use Ecto.Schema
      @primary_key false
    end
  end
end
