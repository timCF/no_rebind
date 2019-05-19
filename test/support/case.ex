defmodule NoRebind.Test.Case do
  use ExUnit.CaseTemplate
  alias NoRebind.Test.Support.Factory

  using do
    quote do
      alias NoRebind.Test.Support.Factory
    end
  end

  setup do
    %{
      module: Factory.new_module(),
      function: Factory.new_function()
    }
  end
end
