defmodule Helpers do
  defmacro stub_command(pattern, reply) do
    quote location: :keep do
      def maybe_reply(:command, unquote(pattern), state) do
        state.recv.(<<0x4>> <> unquote(reply))
        :ok
      end
    end
  end
end
