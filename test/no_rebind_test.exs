defmodule NoRebindTest do
  use ExUnit.Case
  doctest NoRebind

  test "greets the world" do
    assert NoRebind.hello() == :world
  end
end
