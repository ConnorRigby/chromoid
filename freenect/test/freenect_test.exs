defmodule FreenectTest do
  use ExUnit.Case
  doctest Freenect

  test "greets the world" do
    {:ok, pid} = Freenect.start_link([])
    :ok = Freenect.set_depth_mode(pid, :freenect_depth_registered)
    {:ok, buffer} = Freenect.get_buffer_depth(pid)

  end
end
