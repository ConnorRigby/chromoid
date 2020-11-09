defmodule ChromoidWeb.DeviceController do
  use ChromoidWeb, :controller
  require Logger

  def index(conn, _params) do
    send_resp(conn, 200, "TODO (connor): I'll implement this at some point (probably)")
  end

  def show(conn, _params) do
    send_resp(conn, 200, "TODO (connor): I'll implement this at some point (probably)")
  end

  def stream(conn, %{"id" => id}) do
    device = Chromoid.Devices.get_device(id)
    render(conn, "stream.html", device: device)
  end

  def live(conn, %{"id" => id}) do
    device = Chromoid.Devices.get_device(id)

    conn
    |> put_resp_header("Content-Type", "multipart/x-mixed-replace; boundary=\"MJPEGBOUNDRY\"")
    |> send_chunked(200)
    |> do_livestream(device)
  end

  def do_livestream(conn, device) do
    case request_photo(device) do
      {:ok, %{"content" => jpeg}} ->
        content = [
          """
          --MJPEGBOUNDRY
          Content-Type: image/jpeg

          """,
          jpeg
        ]

        case chunk(conn, content) do
          {:ok, conn} ->
            do_livestream(conn, device)

          {:error, :closed} ->
            Logger.error("livestream connection cloesed")

            conn
            |> halt()
        end

      {:error, error} ->
        Logger.error("error getting frame: #{inspect(error)}")

        conn
        |> put_flash(:error, error)
        |> halt()
    end
  end

  def request_photo(device) do
    Chromoid.Devices.Photo.request_photo(device)
  catch
    :exit, {:noproc, _} ->
      {:error, "device not connected"}
  end
end
