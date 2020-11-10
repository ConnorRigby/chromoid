defmodule Test do
  def test do
    # Freenect.start_link []
    :ok = Freenect.set_mode(:depth)
    {:ok, data} = Freenect.get_next_frame()
    File.write("tes.jpg", data)
    Process.sleep(1)
    test()
  end
end
