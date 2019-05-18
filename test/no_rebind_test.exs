defmodule NoRebindTest do
  use ExUnit.Case
  use NoRebind
  alias NoRebind.Test.Support.Factory
  doctest NoRebind

  setup do
    %{
      module: Factory.new_module(),
      other_module: Factory.new_module()
    }
  end

  test "success simple", %{module: module} do
    compiled =
      quote do
        defmodule unquote(module) do
          def fac(0), do: 1
          def fac(x) when x > 0, do: x * fac(x - 1)
        end
      end
      |> Code.compile_quoted()

    assert [{^module, <<_::binary>>}] = compiled
  end

  test "success with bindings", %{module: module, other_module: other_module} do
    compiled =
      quote do
        defmodule unquote(other_module) do
          defstruct [:bar]
        end

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
      end
      |> Code.compile_quoted()

    assert [
             {^other_module, <<_::binary>>},
             {^module, <<_::binary>>}
           ] = compiled
  end

  test "fn -> success", %{module: module} do
    quote do
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
    end
    |> Code.compile_quoted()
  end
end
