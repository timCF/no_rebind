defmodule NoRebind.Exception do
  @type t :: %__MODULE__{message: String.t()}
  defexception [:message]
end
