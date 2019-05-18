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
      |> traverse_clause(header, body)

    quote do
      Kernel.def(unquote(header), do: unquote(body))
    end
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
        {:=, _, [lhs, rhs]} = ast, %MapSet{} = acc ->
          {
            # eliminate this AST node
            # because full expression (lhs and rhs)
            # was handled explicitly
            nil,
            acc
            |> extract_and_merge_vars(lhs, ast)
            |> traverse_expression(rhs)
          }

        {:fn, _, [_ | _] = clauses}, %MapSet{} = acc ->
          :ok =
            clauses
            |> Enum.each(fn {:->, _, [header, body]} ->
              traverse_clause(acc, header, body)
            end)

          {
            # eliminate this AST node
            # because full expression (function with clauses)
            # is handled explicitly
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
    {^raw_ast, %MapSet{} = vars} =
      raw_ast
      |> Macro.prewalk(MapSet.new(), fn
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
            vars_intersection |> MapSet.to_list() |> Enum.map(&"'#{&1}'") |> Enum.join(", ")
          } already exist, but was redefined in

            #{debug_ast |> Macro.to_string()}
          """
        }
        |> raise
    end
  end
end
