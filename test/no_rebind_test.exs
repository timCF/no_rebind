defmodule NoRebindTest do
  use ExUnit.Case
  doctest NoRebind

  test "success" do
    defmodule Success do
      use NoRebind

      # foo = 1
      # bar = foo + 1
      #
      # def special(list) do
      #   Enum.reduce(list, 0, fn x, acc ->
      #     case rem(x, 2) do
      #       0 -> acc
      #       x when x in [1, -1] -> acc + x
      #     end
      #   end)
      # end

      def fac(0), do: 1
      def fac(x) when x > 0, do: x * fac(x - 1)
    end
  end
end
