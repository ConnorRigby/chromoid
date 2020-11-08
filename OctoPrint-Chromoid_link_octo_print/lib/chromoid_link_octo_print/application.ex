defmodule ChromoidLinkOctoPrint.Application do
  use Application

  def start(_, args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    :os.cmd('epmd -d')
    {:ok, hostname} = :inet.gethostname()
    Node.start(:"#{hostname}", :shortnames)
    Node.set_cookie(:democookie)

    children = [
      ChromoidLinkOctoPrint.PluginSocket,
      ChromoidLinkOctoPrint.DeviceChannel
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
