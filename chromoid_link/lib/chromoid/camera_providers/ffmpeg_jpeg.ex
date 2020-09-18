defmodule Chromoid.CameraProvider.FFMpegJPEG do
  def jpeg do
    port =
      Port.open({:spawn_executable, System.find_executable("ffmpeg")}, [
        {:args,
         ~w(-f video4linux2 -s 640x480 -i /dev/video0 -ss 0:0:1 -frames 1 -f mpjpeg pipe:1)},
        :binary,
        :exit_status
      ])

    ["--ffmpeg", _, _, _, jpeg | _] = assemble(port) |> String.split("\r\n")

    {:ok, jpeg}
  end

  def assemble(port, payload \\ "") do
    receive do
      {^port, {:data, data}} -> assemble(port, payload <> data)
      {^port, {:exit_status, _}} -> payload
    end
  end
end
