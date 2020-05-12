defmodule Seraph.Query do
  alias Seraph.Query.Builder
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
  def build_return(query, expr, env) when not is_list(expr) do
    build_return(query, [expr], env)
  end

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
          # {entity_alias, nil, nil} ->
          #   {queryable, _} = Keyword.fetch!(query.aliases, entity_alias)
          #   {entity_alias, queryable}

          {entity_alias, nil, result_alias} when not is_nil(result_alias) ->
            # {queryable, _} = Keyword.fetch!(query.aliases, entity_alias)
            {result_alias, entity_alias}

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

  def prepare(query, opts) do
    relationship_result = Keyword.fetch!(opts, :relationship_result)
    adapt_for_result(query, relationship_result)
  end

  def to_string(query, _opts \\ []) do
    query.operations
    |> Enum.map(&Seraph.Query.Stringifier.stringify/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
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

  @spec do_check_aliases_and_props(Seraph.Query.t(), tuple) :: :ok | {:error, String.t()}
  defp do_check_aliases_and_props(query, {entity_alias, nil}) do
    if :error == Keyword.fetch(query.aliases, entity_alias) do
      raise Seraph.QueryError,
        message: "Unknown alias #{inspect(entity_alias)}",
        query: query.literal
    end
  end

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

  @spec adapt_for_result(Seraph.Query.t(), :full | :no_nodes | :contextual) :: Seraph.Query.t()
  defp adapt_for_result(query, :full) do
    # TODO: Should work also with non-return queries...

    updated_rel_list =
      Enum.reduce(query.operations[:return].fields, [], fn
        %Builder.RelationshipExpr{} = rel, rel_list ->
          new_rel =
            rel
            |> fill_node_alias(rel.start, :start)
            |> fill_node_alias(rel.end, :end)

          [new_rel | rel_list]

        _, rel_list ->
          rel_list
      end)

    {new_aliases, new_return, new_result_aliases} =
      updated_rel_list
      |> Enum.reduce([], fn %Builder.RelationshipExpr{start: start_node, end: end_node} = rel,
                            to_add ->
        to_add
        |> add_new_returns(start_node, query, rel, :start_node, is_in_return?(query, start_node))
        |> add_new_returns(end_node, query, rel, :end_node, is_in_return?(query, end_node))
      end)
      |> Enum.reduce(
        {query.aliases, query.operations[:return], query.result_aliases},
        fn {node_alias, node_queryable, node_data}, {aliases, return, result_aliases} ->
          new_return = %Builder.ReturnExpr{return | fields: return.fields ++ [node_data]}

          new_aliases =
            case Keyword.fetch(aliases, node_alias) do
              {:ok, {nil, alias_data}} ->
                Keyword.put(aliases, node_alias, {node_queryable, alias_data})

              {:ok, _} ->
                aliases

              :error ->
                Keyword.put(aliases, node_alias, {node_queryable, node_data})
            end

          new_result_aliases = [{String.to_atom(node_data.alias), node_alias} | result_aliases]

          {new_aliases, new_return, new_result_aliases}
        end
      )

    new_rel_list =
      Enum.reduce(updated_rel_list, %{}, fn
        %Builder.RelationshipExpr{variable: variable} = rel, new_rels ->
          Map.put(new_rels, variable, rel)
      end)

    new_rel_aliases = Map.keys(new_rel_list)

    new_match =
      Enum.map(query.operations[:match], fn
        %Builder.RelationshipExpr{variable: variable} = rel_data ->
          if variable in new_rel_aliases do
            Map.fetch!(new_rel_list, variable)
          else
            rel_data
          end

        entity_data ->
          entity_data
      end)

    new_return_fields =
      Enum.map(new_return.fields, fn
        %Builder.RelationshipExpr{variable: variable} = rel_data ->
          if variable in new_rel_aliases do
            Map.fetch!(new_rel_list, variable)
          else
            rel_data
          end

        entity_data ->
          entity_data
      end)

    new_return = %{new_return | fields: new_return_fields}

    new_aliases =
      Enum.reduce(new_rel_list, new_aliases, fn {rel_var, rel_data}, aliases ->
        rel_alias = String.to_atom(rel_var)
        {queryable, _} = Keyword.fetch!(aliases, rel_alias)
        Keyword.put(aliases, rel_alias, {queryable, rel_data})
      end)

    new_ops =
      Enum.map(query.operations, fn
        {:return, _} ->
          {:return, new_return}

        {:match, _} ->
          {:match, new_match}

        operation ->
          operation
      end)

    %{query | aliases: new_aliases, operations: new_ops, result_aliases: new_result_aliases}
  end

  defp adapt_for_result(query, _) do
    query
  end

  defp add_new_returns(to_add, _node_data, _query, _rel, _node_type, true) do
    to_add
  end

  defp add_new_returns(to_add, node_data, query, rel, node_type, false) do
    %Builder.RelationshipExpr{variable: variable} = rel

    rel_alias = Seraph.Repo.Helper.result_queryable(String.to_atom(variable), query)

    node_alias = String.to_atom(node_data.variable)

    node_info =
      case rel_alias do
        :error ->
          {node_alias, nil, node_data}

        {:ok, {rel_queryable, _}} ->
          {node_alias, rel_queryable.__schema__(node_type), node_data}
      end

    [node_info | to_add]
  end

  defp is_in_return?(query, node_data) do
    node_alias = String.to_atom(node_data.variable)
    node_variable = node_data.variable

    case Enum.find(query.result_aliases, fn {_, v} -> v == node_alias end) do
      {_, _} ->
        true

      nil ->
        Enum.any?(query.operations[:return].fields, fn
          %Builder.NodeExpr{variable: ^node_variable} ->
            true

          _ ->
            false
        end)
    end
  end

  defp fill_node_alias(
         relationship,
         %Builder.NodeExpr{variable: nil} = node_data,
         node_type
       ) do
    node_alias = "__seraph_" <> Atom.to_string(node_type) <> "_" <> relationship.variable

    new_node_data = %{
      node_data
      | variable: node_alias,
        alias: node_alias
    }

    Map.put(relationship, node_type, new_node_data)
  end

  defp fill_node_alias(relationship, node_data, node_type) do
    node_alias = "__seraph_" <> Atom.to_string(node_type) <> "_" <> relationship.variable

    new_node_data = %{
      node_data
      | alias: node_alias
    }

    Map.put(relationship, node_type, new_node_data)
  end
end
