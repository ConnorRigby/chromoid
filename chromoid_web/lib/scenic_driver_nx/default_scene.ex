defmodule DefaultScene do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  alias Scenic.ViewPort

  import Scenic.Primitives
  # import Scenic.Components

  @note """
    This is a very simple starter application.

    If you want a more full-on example, please start from:

    mix scenic.new.example
  """

  @text_size 24

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, opts) do
    ChromoidWeb.Endpoint.subscribe("nx")
    # get the width and height of the viewport. This is to demonstrate creating
    # a transparent full-screen rectangle to catch user input
    {:ok, %ViewPort.Status{size: {width, height}}} = ViewPort.info(opts[:viewport])

    # show the version of scenic and the glfw driver
    scenic_ver = Application.spec(:scenic, :vsn) |> to_string()
    glfw_ver = Application.spec(:scenic_driver_glfw, :vsn) |> to_string()

    graph =
      Graph.build(font: :roboto, font_size: @text_size)
      |> add_specs_to_graph([
        text_spec("scenic: v" <> scenic_ver, translate: {20, 40}),
        text_spec("glfw: v" <> glfw_ver, translate: {20, 40 + @text_size}),
        text_spec(@note, translate: {20, 120}),
        rect_spec({width, height})
      ])
      |> circle(150, fill: :green, translate: {300, 350})

    {:ok, graph, push: graph}
  end

  def handle_input(event, _context, state) do
    Logger.info("Received event: #{inspect(event)}")
    {:noreply, state}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "nx", payload: payload}, graph) do
    IO.inspect(payload, label: "scenic")

    graph =
      graph
      |> circle(150, fill: :blue, translate: {500, 350})

    {:noreply, graph, push: graph}
  end
end
