defmodule Chromoid.Config do
  use GenServer
  require Logger

  def wifi_provisioned? do
    GenServer.call(__MODULE__, :wifi_provisioned?)
  end

  def set_wifi_provisioned do
    GenServer.call(__MODULE__, :set_wifi_provisioned)
  end

  def put_token_refresh(new_token) do
    GenServer.call(__MODULE__, {:put_token_refresh, new_token})
  end

  def put_url(url) do
    GenServer.call(__MODULE__, {:put_url, url})
  end

  def backup_then_put_url(url) do
    GenServer.call(__MODULE__, :backup_url)
    GenServer.call(__MODULE__, {:put_url, url})
  end

  def restore_url() do
    GenServer.call(__MODULE__, :restore_url)
  end

  def get_socket_url() do
    GenServer.call(__MODULE__, :get_socket_url)
  end

  def persist_relay_state(relay_addr, relay_state) do
    GenServer.call(__MODULE__, {:persist_relay_state, relay_addr, relay_state})
  end

  def load_relay_state(relay_addr) do
    GenServer.call(__MODULE__, {:load_relay_state, relay_addr})
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
    new_uri = %{uri | query: new_query_params}
    Logger.info("Refreshed chromoid socket token")
    reply = CubDB.put(state.db, :chromoid_socket_url, to_string(new_uri))
    {:reply, reply, state}
  end

  def handle_call({:put_url, url}, _from, state) do
    reply = CubDB.put(state.db, :chromoid_socket_url, to_string(url))
    {:reply, reply, state}
  end

  def handle_call(:backup_url, _from, state) do
    current = get_url(state.db)
    reply = CubDB.put(state.db, :chromoid_socket_url_backup, to_string(current))
    {:reply, reply, state}
  end

  def handle_call(:restore_url, _from, state) do
    current = get_url(state.db)
    backup = CubDB.get(state.db, :chromoid_socket_url_backup)
    :ok = CubDB.put(state.db, :chromoid_socket_url_backup, to_string(current))
    reply = CubDB.put(state.db, :chromoid_socket_url, to_string(backup))
    {:reply, reply, state}
  end

  def handle_call(:get_socket_url, _from, state) do
    current = get_url(state.db)
    {:reply, current, state}
  end

  def handle_call(:wifi_provisioned?, _from, state) do
    reply = CubDB.get(state.db, :chromoid_wifi_provisioned?) || false
    {:reply, reply, state}
  end

  def handle_call(:set_wifi_provisioned, _from, state) do
    reply = CubDB.put(state.db, :chromoid_wifi_provisioned?, true)
    {:reply, reply, state}
  end

  def handle_call({:persist_relay_state, relay_addr, relay_state}, _from, state) do
    reply = CubDB.put(state.db, {:relay, relay_addr}, relay_state)
    {:reply, reply, state}
  end

  def handle_call({:load_relay_state, relay_addr}, _from, state) do
    reply = CubDB.get(state.db, {:relay, relay_addr})
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info(:put_url_from_application_env, state) do
    from_env = Application.get_env(:chromoid, :socket)[:url]
    from_db = CubDB.get(state.db, :chromoid_socket_url)

    if is_nil(from_db) && not is_nil(from_env) do
      Logger.warn("Moving chromoid socket url into CubDB")
      CubDB.put(state.db, :chromoid_socket_url, from_env)
    end

    {:noreply, state}
  end

  defp get_url(db), do: CubDB.get(db, :chromoid_socket_url) || default_url()

  def default_url, do: Application.get_env(:chromoid, :socket)[:url]

  def data_dir do
    case Application.get_env(:chromoid, :target) do
      :host -> "/tmp/chromoid_link_data"
      _ -> "/root/chromoid_link_data"
    end
  end
end
