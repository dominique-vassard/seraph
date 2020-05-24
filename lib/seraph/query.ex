defmodule Seraph.Query do
  alias Seraph.Query.Builder
  defstruct identifiers: [], params: [], operations: [], literal: [], result_aliases: []

  @type operation :: :match | :where | :return

  @type t :: %__MODULE__{
          identifiers: [{atom, {Seraph.Repo.queryable(), Seraph.Query.Builder.entity_expr()}}],
          params: [{atom, any()}],
          operations: [{operation(), any()}],
          literal: [String.t()],
          result_aliases: [{atom, Seraph.Repo.queryable()}]
        }

  defmacro match(expr, operations \\ []) do
    operations = [{:match, expr} | operations]

    query =
      %Seraph.Query{}
      |> Macro.escape()

    query =
      Enum.reduce(operations, query, fn {op, expression}, query ->
        func = "build_" <> Atom.to_string(op)
        Kernel.apply(Seraph.Query, String.to_atom(func), [query, expression, __CALLER__])
      end)

    quote do
      unquote(query)
    end
  end

  defmacro where(query, expr) do
    build_where(query, expr, __CALLER__)
  end

  defmacro return(query, expr) do
    build_return(query, expr, __CALLER__)
  end

  def build_match(query, expr, env) do
    %{match: match, identifiers: identifiers, params: params} = Builder.Match.build(expr, env)

    match = Macro.escape(match)
    identifiers = Macro.escape(identifiers)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(",\n\t")

    quote bind_quoted: [
            query: query,
            match: match,
            identifiers: identifiers,
            params: params,
            literal: literal
          ] do
      %{
        query
        | identifiers: query.identifiers ++ identifiers,
          operations: query.operations ++ [match: match],
          params: query.params ++ params,
          literal: query.literal ++ ["match:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_where(Macro.t(), Macro.t(), any) :: Macro.t()
  def build_where(query, expr, env) do
    %{condition: condition, params: params} = Seraph.Query.Builder.Where.build(expr, env)

    condition = Macro.escape(condition)

    literal =
      expr
      |> Macro.to_string()
      |> String.replace("()", "")

    quote bind_quoted: [
            query: query,
            condition: condition,
            params: params,
            literal: literal
          ] do
      %{
        query
        | operations: query.operations ++ [where: condition],
          params: Keyword.merge(query.params, params),
          literal: query.literal ++ ["where:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_return(Macro.t(), Macro.t(), any) :: Macro.t()
  def build_return(query, expr, env) when not is_list(expr) do
    build_return(query, [expr], env)
  end

  def build_return(query, expr, env) do
    %{return: return, params: params} = Seraph.Query.Builder.Return.build(expr, env)

    return = Macro.escape(return)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", ")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, literal: literal, return: return, params: params] do
      %{
        query
        | operations: query.operations ++ [return: return],
          literal: query.literal ++ ["return:\n\t" <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @spec prepare(Seraph.Query.t(), Keyword.t()) :: Seraph.Query.t()
  def prepare(query, opts) do
    check(query, opts)
    do_prepare(query, opts)
  end

  @spec check(Seraph.Query.t(), Keyword.t()) :: :ok
  def check(query, _opts) do
    Enum.each(query.operations, fn
      {:match, data} ->
        data
        |> Builder.Match.check(query)
        |> raise_if_fail!(query)

      {:where, %Builder.Condition{} = condition} ->
        condition
        |> Builder.Where.check(query)
        |> raise_if_fail!(query)

      {:return, %Builder.Return{} = return} ->
        return
        |> Builder.Return.check(query)
        |> raise_if_fail!(query)

      _ ->
        :ok
    end)
  end

  @spec do_prepare(Seraph.Query.t(), Keyword.t()) :: Seraph.Query.t()
  defp do_prepare(query, opts) do
    Enum.reduce(query.operations, query, fn
      {:return, return}, old_query ->
        new_return = Builder.Return.prepare(return, old_query, opts)

        %{
          old_query
          | operations: Keyword.update!(old_query.operations, :return, fn _ -> new_return end)
        }

      _, old_query ->
        old_query
    end)
  end

  defp raise_if_fail!(:ok, _) do
    :ok
  end

  defp raise_if_fail!({:error, message}, query) do
    raise Seraph.QueryError, message: message, query: query.literal
  end
end
