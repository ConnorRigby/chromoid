defmodule Chromoid.Config do
  use GenServer
  require Logger

  def put_token_refresh(new_token) do
    GenServer.call(__MODULE__, {:put_token_refresh, new_token})
  end

  def get_socket_url() do
    GenServer.call(__MODULE__, :get_socket_url)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    with {:ok, db} <- CubDB.start_link(data_dir: data_dir()) do
      send(self(), :put_url_from_application_env)
      {:ok, %{db: db}}
    end
  end

  @impl GenServer
  def handle_call({:put_token_refresh, new_token}, _from, state) do
    current = get_url(state.db)
    uri = URI.parse(current)
    old_query_params = uri |> Map.fetch!(:query) |> URI.decode_query()
    new_query_params = %{old_query_params | "token" => new_token} |> URI.encode_query()
    new_uri = %{uri | params: new_query_params}
    Logger.info("Refreshed chromoid socket token")
    reply = CubDB.put(state.db, :chromoid_socket_url, to_string(new_uri))
    {:reply, reply, state}
  end

  def handle_call(:get_socket_url, _from, state) do
    current = get_url(state.db)
    {:reply, current, state}
  end

  @impl GenServer
  def handle_info(:put_url_from_application_env, state) do
    if is_nil(CubDB.get(state.db, :chromoid_socket_url)) do
      Logger.warn("Moving chromoid socket url into CubDB")
      CubDB.put(state.db, :chromoid_socket_url, Application.get_env(:chromoid, :socket)[:url])
    end

    {:noreply, state}
  end

  defp get_url(db), do: CubDB.get(db, :chromoid_socket_url) || default_url()

  def default_url, do: Application.get_env(:chromoid, :socket)[:url] || raise(ArgumentError, "no chromo.id url configured")

  def data_dir do
    case Application.get_env(:chromoid, :target) do
      :host -> "/tmp/chromoid_link_data"
      _ -> "/root/chromoid_link_data"
    end
  end
end
