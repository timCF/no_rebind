defmodule NoRebind do
  defmacro __using__(_) do
    quote do
      import Kernel, except: [def: 2]
      import unquote(__MODULE__), only: [def: 2]
    end
  end

  defmacro def(header, do: body) do
    %MapSet{} =
      __CALLER__
      |> Macro.Env.vars()
      |> Enum.map(fn {x, _} -> x end)
      |> MapSet.new()
      |> traverse_header(header |> Macro.expand(__CALLER__))
      |> traverse_body(body |> Macro.expand(__CALLER__))

    quote do
      Kernel.def(unquote(header), do: unquote(body))
    end
  end

  defp traverse_header(%MapSet{} = vars, ast) do
    ast
    |> extract_vars()
    |> merge_vars(vars, ast)
  end

  defp traverse_body(%MapSet{} = vars, raw_ast) do
    {^raw_ast, %MapSet{} = ^vars} =
      raw_ast
      |> Macro.prewalk(vars, fn
        ast, %MapSet{} = acc ->
          ast |> IO.inspect()
          {ast, acc}
      end)

    #
    # TODO : implement!!
    #
    vars
  end

  defp extract_vars(raw_ast) do
    {^raw_ast, %MapSet{} = vars} =
      raw_ast
      |> Macro.prewalk(MapSet.new(), fn
        {v, _, c} = ast, %MapSet{} = acc when is_atom(v) and is_atom(c) ->
          {ast, MapSet.put(acc, v)}

        ast, %MapSet{} = acc ->
          {ast, acc}
      end)

    vars
  end

  defp merge_vars(%MapSet{} = new_vars, %MapSet{} = old_vars, full_ast) do
    vars_intersection =
      new_vars
      |> MapSet.intersection(old_vars)

    vars_intersection
    |> MapSet.size()
    |> case do
      0 ->
        MapSet.union(new_vars, old_vars)

      _ ->
        %NoRebind.Exception{
          message: """
          Definition(s) of #{
            vars_intersection |> MapSet.to_list() |> Enum.map(&"'#{&1}'") |> Enum.join(", ")
          } already exist, but was redefined in

            #{full_ast |> Macro.to_string() |> Code.format_string!()}
          """
        }
        |> raise
    end
  end
end
