defmodule Seraph.Query do
  defstruct aliases: [], params: [], operations: [], literal: [], result_aliases: []

  @type operation :: :match | :where | :return

  @type t :: %__MODULE__{
          aliases: [{atom, {Seraph.Repo.queryable(), Seraph.Query.Builder.entity_expr()}}],
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

  @doc false
  @spec build_match(Macro.t(), Macro.t(), any) :: Macro.t()
  def build_match(query, expr, env) do
    {match, aliases, params, prop_check} = Seraph.Query.Match.build(expr, env)

    match = Macro.escape(match)
    aliases = Macro.escape(aliases)
    prop_check = Macro.escape(prop_check)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(",\n\t")

    quote bind_quoted: [
            query: query,
            match: match,
            aliases: aliases,
            params: params,
            prop_check: prop_check,
            literal: literal
          ] do
      query = %{
        query
        | aliases: query.aliases ++ aliases,
          operations: query.operations ++ [match: match],
          params: query.params ++ params,
          literal: query.literal ++ ["match:\n\t" <> literal]
      }

      check_aliases_and_props(query, fill_value(prop_check, params))
      query
    end
  end

  @doc false
  @spec build_where(Macro.t(), Macro.t(), any) :: Macro.t()
  def build_where(query, expr, _env) do
    {condition, params, prop_check} = Seraph.Query.Where.build(expr)

    condition = Macro.escape(condition)
    prop_check = Macro.escape(prop_check)

    literal =
      expr
      |> Macro.to_string()
      |> String.replace("()", "")

    quote bind_quoted: [
            query: query,
            condition: condition,
            params: params,
            prop_check: prop_check,
            literal: literal
          ] do
      check_aliases_and_props(query, fill_value(prop_check, params))

      %{
        query
        | operations: query.operations ++ [where: condition],
          params: query.params ++ params,
          literal: query.literal ++ ["where:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_return(Macro.t(), Macro.t(), any) :: Macro.t()
  def build_return(query, expr, _env) do
    return =
      expr
      |> Seraph.Query.Return.build()
      |> Macro.escape()

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", ")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, return: return, literal: literal] do
      prop_check =
        return
        |> Enum.map(fn {entity_alias, property, _} -> {entity_alias, property} end)

      check_aliases_and_props(query, prop_check)

      result_aliases =
        return
        |> Enum.map(fn
          {entity_alias, nil, nil} ->
            {queryable, _} = Keyword.fetch!(query.aliases, entity_alias)
            {entity_alias, queryable}

          {entity_alias, nil, result_alias} ->
            {queryable, _} = Keyword.fetch!(query.aliases, entity_alias)
            {result_alias, queryable}

          _ ->
            nil
        end)
        |> Enum.reject(&is_nil/1)

      return_expr = %Seraph.Query.Builder.ReturnExpr{
        fields: Seraph.Query.Return.finalize_build(query.aliases, return)
      }

      %{
        query
        | operations: query.operations ++ [return: return_expr],
          literal: query.literal ++ ["return:\n\t" <> literal],
          result_aliases: result_aliases
      }
    end
  end

  @doc false
  @spec fill_value([{atom, atom, String.t()}], Keyword.t()) :: [{atom, atom, any}]
  def fill_value(prop_check, params) do
    Enum.map(prop_check, fn {entity_alias, prop, bound_name} ->
      value =
        if not is_nil(prop) do
          Keyword.fetch!(params, String.to_atom(bound_name))
        end

      {entity_alias, prop, value}
    end)
  end

  @doc false
  @spec check_aliases_and_props(Seraph.Query.t(), [tuple]) :: :ok
  def check_aliases_and_props(query, aliases_and_props) do
    Enum.each(aliases_and_props, &do_check_aliases_and_props(query, &1))
  end

  defp do_check_aliases_and_props(query, {entity_alias, nil}) do
    if :error == Keyword.fetch(query.aliases, entity_alias) do
      raise Seraph.QueryError,
        message: "Unknown alias #{inspect(entity_alias)}",
        query: query.literal
    end
  end

  @spec do_check_aliases_and_props(Seraph.Query.t(), tuple) :: :ok | {:error, String.t()}
  defp do_check_aliases_and_props(query, {entity_alias, property}) do
    case Keyword.fetch(query.aliases, entity_alias) do
      {:ok, {queryable, _}} ->
        case check_property(queryable, property) do
          {:error, message} ->
            raise Seraph.QueryError, message: message, query: query.literal

          :ok ->
            :ok
        end

      :error ->
        raise Seraph.QueryError,
          message: "Unknown alias #{inspect(entity_alias)}",
          query: query.literal
    end
  end

  defp do_check_aliases_and_props(query, {entity_alias, nil, _}) do
    if :error == Keyword.fetch(query.aliases, entity_alias) do
      raise Seraph.QueryError,
        message: "Unknown alias #{inspect(entity_alias)}",
        query: query.literal
    end
  end

  defp do_check_aliases_and_props(query, {entity_alias, property, value}) do
    case Keyword.fetch(query.aliases, entity_alias) do
      {:ok, {queryable, _}} ->
        case check_property(queryable, property) do
          {:error, message} ->
            raise Seraph.QueryError, message: message, query: query.literal

          :ok ->
            :ok
        end

        case check_type(queryable, property, value) do
          {:error, message} ->
            raise Seraph.QueryError, message: message, query: query.literal

          :ok ->
            :ok
        end

      :error ->
        raise Seraph.QueryError,
          message: "Unknown alias #{inspect(entity_alias)}",
          query: query.literal
    end
  end

  @spec check_property(Seraph.Repo.queryable(), atom) :: :ok | {:error, String.t()}
  defp check_property(nil, _) do
    :ok
  end

  defp check_property(queryable, property) do
    case property in queryable.__schema__(:properties) do
      false ->
        message = "Unknwon property #{inspect(property)} on #{inspect(queryable)}"
        {:error, message}

      true ->
        :ok
    end
  end

  defp check_type(nil, _, _) do
    :ok
  end

  @spec check_type(Seraph.Repo.queryable(), atom, any) :: :ok | {:error, String.t()}
  defp check_type(queryable, property, value) do
    type = queryable.__schema__(:type, property)

    case Ecto.Type.dump(type, value) do
      :error ->
        message = """
        Wrong type for value [#{inspect(value)}] for property #{inspect(property)} on #{
          inspect(queryable)
        }.
        Expect: #{type}
        """

        {:error, message}

      _ ->
        :ok
    end
  end
end
