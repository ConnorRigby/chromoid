defmodule Chromoid.Repo do
  use Ecto.Repo,
    otp_app: :chromoid,
    adapter: Ecto.Adapters.Postgres
end
