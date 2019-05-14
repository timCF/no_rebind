defmodule NoRebindTest do
  use ExUnit.Case
  use NoRebind
  alias NoRebind.Test.Support.Factory
  doctest NoRebind

  setup do
    %{module: Factory.new_module()}
  end

  test "success", %{module: module} do
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
end
