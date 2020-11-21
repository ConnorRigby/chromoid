defmodule Chromoid.CameraProvider.Freenect do
  def jpeg do
    ObjectDetect.get_next_frame()
  end
end
