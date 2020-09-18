defmodule Chromoid.CameraProvider.Picam do
  @behaviour Chromoid.CameraProvider
  def jpeg() do
    Picam.set_size(640, 0)
    jpeg = Picam.next_frame()
    {:ok, jpeg}
  end
end
