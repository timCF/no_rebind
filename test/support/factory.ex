defmodule NoRebind.Test.Support.Factory do
  def new_module do
    _ = Agent.start_link(fn -> 0 end, name: __MODULE__)
    x = Agent.get_and_update(__MODULE__, &{&1, &1 + 1})
    Module.concat(__MODULE__, "Module#{x}")
  end
end
