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
      |> extract_and_merge_vars(header |> Macro.expand(__CALLER__))
      |> traverse_body(body |> Macro.expand(__CALLER__))

    quote do
      Kernel.def(unquote(header), do: unquote(body))
    end
  end

  defp traverse_body(%MapSet{} = vars, raw_ast) do
    {_, %MapSet{} = new_vars} =
      raw_ast
      |> Macro.postwalk(vars, fn
        {:=, _, [lhs, rhs]}, %MapSet{} = acc ->
          {
            # eliminate all AST node
            # because full expression (lhs and rhs)
            # is handled explicitly
            nil,
            acc
            # lhs can contain only patterns, not function calls
            |> extract_and_merge_vars(lhs)
            # rhs can contain any expression
            |> traverse_body(rhs)
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

  defp extract_and_merge_vars(%MapSet{} = vars, ast) do
    ast
    |> extract_vars()
    |> merge_vars(vars, ast)
  end

  defp extract_vars(raw_ast) do
    {^raw_ast, %MapSet{} = vars} =
      raw_ast
      |> Macro.postwalk(MapSet.new(), fn
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
