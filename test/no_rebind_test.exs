defmodule NoRebindTest do
  use ExUnit.Case
  alias NoRebind.Test.Support.Factory
  doctest NoRebind

  setup do
    %{
      module: Factory.new_module(),
      other_module: Factory.new_module(),
      function: Factory.new_function()
    }
  end

  test "success simple", %{module: module} do
    compiled =
      quote do
        require NoRebind

        defmodule unquote(module) do
          def fac(0), do: 1
          def fac(x) when x > 0, do: x * fac(x - 1)
        end
        |> NoRebind.apply()
      end
      |> Code.compile_quoted()

    assert [{^module, <<_::binary>>}] = compiled
  end

  test "success with bindings", %{module: module, other_module: other_module} do
    compiled =
      quote do
        require NoRebind

        defmodule unquote(other_module) do
          defstruct [:bar]
        end
        |> NoRebind.apply()

        defmodule unquote(module) do
          defstruct [:foo]

          def foo(x) do
            %__MODULE__{
              foo:
                %unquote(other_module){
                  bar: z
                } = y
            } =
              %__MODULE__{
                foo: yy
              } = x

            %unquote(other_module){
              bar: zz
            } = yy

            zz
          end
        end
        |> NoRebind.apply()
      end
      |> Code.compile_quoted()

    assert [
             {^other_module, <<_::binary>>},
             {^module, <<_::binary>>}
           ] = compiled
  end

  test "fn -> success", %{module: module} do
    quote do
      require NoRebind

      defmodule unquote(module) do
        def foo(lst) do
          Enum.reduce(lst, "", fn
            x, acc when is_integer(x) ->
              "#{acc}#{x}"

            x, acc when is_float(x) ->
              "#{acc}#{Float.round(x)}"
          end)
        end
      end
      |> NoRebind.apply()
    end
    |> Code.compile_quoted()
  end

  # comprehensions success
  [
    quote do
      for n <- [1, 2, 3, 4], do: n * n
    end,
    quote do
      for n <- 1..4, do: n * n
    end,
    quote do
      values = [good: 1, good: 2, bad: 3, good: 4]
      for {:good, n} <- values, do: n * n
    end,
    quote do
      multiple_of_3? = fn n -> rem(n, 3) == 0 end
      for n <- 0..5, multiple_of_3?.(n), do: n * n
    end,
    quote do
      for i <- [:a, :b, :c], j <- [1, 2], do: {i, j}
    end,
    quote do
      pixels = <<213, 45, 132, 64, 76, 32, 76, 0, 0, 234, 32, 15>>
      for <<r::8, g::8, b::8 <- pixels>>, do: {r, g, b}
    end,
    quote do
      for <<c <- " hello world ">>, c != ?\s, into: "", do: <<c>>
    end,
    quote do
      for {key, val} <- %{"a" => 1, "b" => 2}, into: %{}, do: {key, val * val}
    end,
    quote do
      stream = IO.stream(:stdio, :line)

      for line <- stream, into: stream do
        String.upcase(line) <> "\n"
      end
    end
  ]
  |> Enum.with_index()
  |> Enum.each(fn {exp, index} ->
    test "comperhensoins success #{index}", %{module: module, function: function} do
      exp_ast = unquote(exp |> Macro.escape())

      compiled =
        quote do
          require NoRebind

          defmodule unquote(module) do
            def unquote(function)() do
              unquote(exp_ast)
            end
          end
          |> NoRebind.apply()
        end
        |> Code.compile_quoted()

      assert [{^module, <<_::binary>>}] = compiled
    end
  end)
end
