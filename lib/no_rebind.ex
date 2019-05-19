defmodule NoRebind do
  defmacro apply(ast) do
    %MapSet{} =
      __CALLER__
      |> Macro.Env.vars()
      |> Enum.map(fn {x, _} -> x end)
      |> MapSet.new()
      |> traverse_expression(ast)

    ast
  end

  defp traverse_clause(%MapSet{} = vars, header, body) do
    vars
    |> extract_and_merge_vars(header, header)
    |> traverse_expression(body)
  end

  defp traverse_expression(%MapSet{} = vars, raw_ast) do
    {_, %MapSet{} = new_vars} =
      raw_ast
      |> Macro.prewalk(vars, fn
        {mid, _, ast} = debug_ast, %MapSet{} = acc
        when mid in [:=, :<-] ->
          [lhs, rhs] = ast

          {
            nil,
            acc
            |> extract_and_merge_vars(lhs, debug_ast)
            |> traverse_expression(rhs)
          }

        {defs, _, ast}, %MapSet{} = acc
        when defs in [:def, :defp, :defmacro, :defmacrop, :->] ->
          [header, body] = ast
          %MapSet{} = traverse_clause(acc, header, body)

          {
            nil,
            acc
          }

        ast, %MapSet{} = acc ->
          {
            ast,
            acc
          }
      end)

    #
    # TODO : implement!!
    #
    new_vars
  end

  defp extract_and_merge_vars(%MapSet{} = vars, ast, debug_ast) do
    ast
    |> extract_vars()
    |> merge_vars(vars, debug_ast)
  end

  defp extract_vars(raw_ast) do
    {_, %MapSet{} = vars} =
      raw_ast
      |> Macro.prewalk(MapSet.new(), fn
        {:^, _, [{v, _, c}]}, %MapSet{} = acc when is_atom(v) and is_atom(c) ->
          {nil, acc}

        {v, _, c} = ast, %MapSet{} = acc
        when v in [:__CALLER__, :__DIR__, :__ENV__, :__MODULE__, :__STACKTRACE__] and is_atom(c) ->
          {ast, acc}

        {v, _, c} = ast, %MapSet{} = acc when is_atom(v) and is_atom(c) ->
          {ast, MapSet.put(acc, v)}

        ast, %MapSet{} = acc ->
          {ast, acc}
      end)

    vars
  end

  defp merge_vars(%MapSet{} = new_vars, %MapSet{} = old_vars, debug_ast) do
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
            vars_intersection
            |> MapSet.to_list()
            |> Enum.map(&"'#{&1}'")
            |> Enum.join(", ")
          } already exist, but was redefined in

            #{debug_ast |> Macro.to_string()}
          """
        }
        |> raise
    end
  end
end
