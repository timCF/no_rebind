defmodule NoRebind.Test.Support.Factory do
  def new_module do
    try do
      do_new_module()
    catch
      :exit, {:noproc, _} ->
        {:ok, _} = Agent.start(fn -> 0 end, name: __MODULE__)
        do_new_module()
    end
  end

  def new_function do
    try do
      do_new_function()
    catch
      :exit, {:noproc, _} ->
        {:ok, _} = Agent.start(fn -> 0 end, name: __MODULE__)
        do_new_function()
    end
  end

  defp do_new_module do
    x = Agent.get_and_update(__MODULE__, &{&1, &1 + 1})
    Module.concat(__MODULE__, "Module#{x}")
  end

  defp do_new_function do
    x = Agent.get_and_update(__MODULE__, &{&1, &1 + 1})
    String.to_atom("function#{x}")
  end
end
