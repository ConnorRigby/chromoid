defmodule Chromoid.Lua.Class do
  defmacro alloc(opts) do
    quote location: :keep do
      @luerl_header Application.app_dir(:luerl, ["include", "luerl.hrl"])
      import Record, only: [defrecord: 2]
      defrecord :erl_func, Record.extract(:erl_func, from: @luerl_header)
      defrecord :lua_func, Record.extract(:lua_func, from: @luerl_header)
      defrecord :userdata, Record.extract(:userdata, from: @luerl_header)

      def alloc(data, properties, state) do
        expected_props = unquote(opts)[:properties] || %{}

        {properties, state} =
          Enum.reduce(expected_props, {properties, state}, fn
            {property, value}, {properties, state} when is_function(value, 2) ->
              value = erl_func(code: value)
              {Map.put(properties, property, value), state}

            # {properties, state}

            {property, type}, {properties, state} ->
              a = properties[property] || Map.fetch!(data, property)

              case a do
                %struct_type{} = value when is_atom(struct_type) ->
                  unless function_exported?(type, :alloc, 3) do
                    raise "#{type} does not implement class behaviour"
                  end

                  {value, state} = type.alloc(value, properties, state)
                  # value = Chromoid.Lua.Object.to_lua(value, properties)
                  {Map.put(properties, property, value), state}

                value when is_function(value, 2) ->
                  value = erl_func(code: value)
                  {Map.put(properties, property, value), state}

                value ->
                  {Map.put(properties, property, value), state}
              end
          end)

        table = Chromoid.Lua.Object.to_lua(data, properties)
        {table, state} = :luerl_heap.alloc_table(table, state)
        IO.puts("allocated: #{__MODULE__} => #{inspect(table)}")
        {table, state}
      end
    end
  end

  defmacro __using__(:new) do
    quote location: :keep do
      import Chromoid.Lua.Class, only: [alloc: 1]
    end
  end

  defmacro __using__(_opts) do
    quote location: :keep do
      @luerl_header Application.app_dir(:luerl, ["include", "luerl.hrl"])
      import Record, only: [defrecord: 2]
      defrecord :erl_func, Record.extract(:erl_func, from: @luerl_header)
      defrecord :lua_func, Record.extract(:lua_func, from: @luerl_header)
      defrecord :userdata, Record.extract(:userdata, from: @luerl_header)
    end
  end
end
