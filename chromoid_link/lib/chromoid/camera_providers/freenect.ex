defmodule Chromoid.CameraProvider.Freenect do
  def jpeg do
    Freenect.get_next_frame()
  end
end
