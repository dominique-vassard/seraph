defmodule Seraph.Query.Match do
  alias Seraph.Query.Builder
  alias Seraph.Query.Match

  defstruct [:entity_alias, :entity, queryable: nil, params: [], prop_check: []]

  @type t :: %__MODULE__{
          entity_alias: atom,
          entity: Builder.entity_expr(),
          queryable: nil | Seraph.Repo.queryable(),
          params: Keyword.t(),
          prop_check: [tuple]
        }

  @spec build(Macro.t(), any) :: {[Builder.entity_expr()], Keyword.t(), Keyword.t(), [tuple()]}
  def build(ast, env) do
    entity_list = Enum.map(ast, &extract_entity(&1, env))

    {rels, nodes} = Enum.split_with(entity_list, &is_list/1)

    nodes_aliases_list =
      nodes
      |> Enum.reject(fn
        %Match{entity_alias: nil} -> true
        _ -> false
      end)
      |> build_aliases()

    aliases =
      rels
      |> Enum.map(fn [start_data, end_data, %Match{queryable: queryable} = rel_data] ->
        [
          fill_queryable(start_data, queryable, :start_node),
          fill_queryable(end_data, queryable, :end_node),
          rel_data
        ]
      end)
      |> List.flatten()
      |> Enum.reject(fn
        %Match{entity_alias: nil} -> true
        _ -> false
      end)
      |> build_aliases(:from_rel, nodes_aliases_list)

    {match, params, prop_check} =
      entity_list
      |> Enum.reduce({[], [], []}, fn
        [
          %Match{params: start_params, prop_check: start_prop_check},
          %Match{params: end_params, prop_check: end_prop_check},
          rel_data
        ],
        {match, params, prop_check} ->
          new_params =
            params
            |> Keyword.merge(start_params)
            |> Keyword.merge(end_params)
            |> Keyword.merge(rel_data.params)

          {[rel_data.entity | match], new_params,
           prop_check ++ start_prop_check ++ end_prop_check ++ rel_data.prop_check}

        node_data, {match, params, prop_check} ->
          {[node_data.entity | match], Keyword.merge(params, node_data.params),
           prop_check ++ node_data.prop_check}
      end)

    {match, aliases, params, prop_check}
  end

  @spec fill_queryable(Match.t(), Seraph.Repo.queryable(), :start_node | :end_node) :: Match.t()
  defp fill_queryable(%Match{queryable: nil} = node_data, rel_queryable, node_type)
       when not is_nil(rel_queryable) do
    node_queryable = rel_queryable.__schema__(node_type)
    entity = Map.put(node_data.entity, :labels, [node_queryable.__schema__(:primary_label)])

    node_data
    |> Map.put(:queryable, node_queryable)
    |> Map.put(:entity, entity)
  end

  defp fill_queryable(node_data, _, _) do
    node_data
  end

  @spec build_aliases([Match.t()], :from_node | :from_rel, Keyword.t()) :: Keyword.t()
  defp build_aliases(entity_data, from_entity_type \\ :from_node, aliases_list \\ [])

  defp build_aliases([], _, aliases_list) do
    aliases_list
  end

  defp build_aliases(
         [%Match{entity_alias: entity_alias, entity: entity, queryable: queryable} | t],
         from_entity_type,
         []
       ) do
    build_aliases(t, from_entity_type, Keyword.put([], entity_alias, {queryable, entity}))
  end

  defp build_aliases(
         [%Match{entity_alias: entity_alias, entity: entity, queryable: queryable} | t],
         :from_node,
         aliases_list
       ) do
    cond do
      Keyword.has_key?(aliases_list, entity_alias) ->
        raise ArgumentError,
              "alias #{inspect(entity_alias)} for #{inspect(queryable)} is invalid: already taken."

      true ->
        build_aliases(t, :from_node, Keyword.put(aliases_list, entity_alias, {queryable, entity}))
    end
  end

  defp build_aliases(
         [
           %Match{
             entity_alias: entity_alias,
             entity: %Builder.NodeExpr{} = entity,
             queryable: queryable
           }
           | t
         ],
         :from_rel,
         aliases_list
       ) do
    existence = Keyword.get(aliases_list, entity_alias)

    cond do
      Kernel.match?({nil, _}, existence) ->
        build_aliases(t, :from_rel, Keyword.put(aliases_list, entity_alias, {queryable, entity}))

      Kernel.match?({^queryable, _}, existence) ->
        build_aliases(t, :from_rel, aliases_list)

      Keyword.has_key?(aliases_list, entity_alias) and is_nil(queryable) ->
        build_aliases(t, :from_rel, aliases_list)

      not Keyword.has_key?(aliases_list, entity_alias) ->
        build_aliases(t, :from_rel, Keyword.put(aliases_list, entity_alias, {queryable, entity}))

      true ->
        raise ArgumentError,
              "alias #{inspect(entity_alias)} for #{inspect(queryable)} is invalid: already taken."
    end
  end

  defp build_aliases(
         [
           %Match{
             entity_alias: entity_alias,
             entity: %Builder.RelationshipExpr{} = entity,
             queryable: queryable
           }
           | t
         ],
         :from_rel,
         aliases_list
       ) do
    cond do
      not Keyword.has_key?(aliases_list, entity_alias) ->
        build_aliases(t, :from_rel, Keyword.put(aliases_list, entity_alias, {queryable, entity}))

      true ->
        raise ArgumentError,
              "alias #{inspect(entity_alias)} for #{inspect(queryable)} is invalid: already taken."
    end
  end

  @spec extract_entity(Macro.t(), Macro.Env.t()) :: Match.t()
  defp extract_entity(
         {:{}, _,
          [
            {node_alias, _, _},
            {:__aliases__, _, _} = queryable_ast,
            {:%{}, _, properties}
          ]},
         env
       ) do
    queryable = Seraph.Schema.Helper.expand_alias(queryable_ast, env)

    %{props: props, params: params} = extract_properties(node_alias, properties)

    node = %Builder.NodeExpr{
      variable: Atom.to_string(node_alias),
      labels: [Macro.expand(queryable, env).__schema__(:primary_label)],
      properties: props
    }

    prop_check =
      Enum.map(props, fn {prop_key, prop_value} ->
        {node_alias, prop_key, prop_value}
      end)

    %Match{
      entity_alias: node_alias,
      queryable: queryable,
      entity: node,
      params: params,
      prop_check: prop_check
    }
  end

  defp extract_entity({{node_alias, _, _}, {:%{}, _, properties}}, _env) do
    %{props: props, params: params} = extract_properties(node_alias, properties)

    node = %Builder.NodeExpr{
      variable: Atom.to_string(node_alias),
      properties: props
    }

    %Match{
      entity_alias: node_alias,
      entity: node,
      params: params
    }
  end

  defp extract_entity({{node_alias, _, _}, {:__aliases__, _, _} = queryable_ast}, env) do
    queryable = Seraph.Schema.Helper.expand_alias(queryable_ast, env)

    node = %Builder.NodeExpr{
      variable: Atom.to_string(node_alias),
      labels: [Macro.expand(queryable, env).__schema__(:primary_label)]
    }

    %Match{
      entity_alias: node_alias,
      queryable: queryable,
      entity: node
    }
  end

  defp extract_entity({:{}, _, [{:__aliases__, _, _} = queryable_ast]}, env) do
    queryable = Seraph.Schema.Helper.expand_alias(queryable_ast, env)

    node = %Builder.NodeExpr{
      labels: [Macro.expand(queryable, env).__schema__(:primary_label)]
    }

    %Match{
      entity_alias: nil,
      queryable: queryable,
      entity: node
    }
  end

  defp extract_entity({:{}, _, [{node_alias, _, _}]}, _env) do
    node = %Builder.NodeExpr{
      variable: Atom.to_string(node_alias)
    }

    %Match{
      entity_alias: node_alias,
      entity: node
    }
  end

  defp extract_entity({:{}, _, []}, _env) do
    raise ArgumentError, "Empty nodes are not supported except in relationships."
  end

  defp extract_entity([start_ast, relationship_ast, end_ast], env) do
    start_data = extract_empty_node(start_ast, env) || extract_entity(start_ast, env)
    end_data = extract_empty_node(end_ast, env) || extract_entity(end_ast, env)

    rel = extract_relationship(relationship_ast, start_data.entity, end_data.entity, env)

    start_d = fill_queryable(start_data, rel.queryable, :start_node)
    end_d = fill_queryable(end_data, rel.queryable, :end_node)

    relationship =
      rel.entity
      |> Map.put(:start, start_d.entity)
      |> Map.put(:end, end_d.entity)

    result = [
      start_d,
      end_d,
      Map.put(rel, :entity, relationship)
    ]

    all_empty? =
      Enum.all?(result, fn
        %Match{entity_alias: nil, queryable: nil} -> true
        _ -> false
      end)

    if all_empty? do
      raise ArgumentError, "Empty relationships are not allowed."
    end

    result
  end

  @spec extract_empty_node(Macro.t(), Macro.Env.t()) :: nil | Match.t()
  defp extract_empty_node({:{}, _, []}, _env) do
    node = %Builder.NodeExpr{}

    %Match{
      entity_alias: nil,
      entity: node
    }
  end

  defp extract_empty_node(_, _) do
    nil
  end

  @spec extract_relationship(Macro.t(), Match.t(), Match.t(), Macro.Env.t()) :: Match.t()
  defp extract_relationship([{rel_alias, _, nil}], start_node, end_node, _env) do
    rel = %Builder.RelationshipExpr{
      start: start_node,
      end: end_node,
      variable: Atom.to_string(rel_alias)
    }

    %Match{
      entity_alias: rel_alias,
      entity: rel
    }
  end

  defp extract_relationship([{:__aliases__, _, _} = queryable_ast], start_node, end_node, env) do
    queryable = Seraph.Schema.Helper.expand_alias(queryable_ast, env)

    rel = %Builder.RelationshipExpr{
      start: start_node,
      end: end_node,
      type: Macro.expand(queryable, env).__schema__(:type)
    }

    %Match{
      entity_alias: nil,
      queryable: queryable,
      entity: rel
    }
  end

  defp extract_relationship(
         [{rel_alias, _, _}, {:__aliases__, _, _} = queryable_ast],
         start_node,
         end_node,
         env
       ) do
    queryable = Seraph.Schema.Helper.expand_alias(queryable_ast, env)

    rel = %Builder.RelationshipExpr{
      variable: Atom.to_string(rel_alias),
      start: start_node,
      end: end_node,
      type: Macro.expand(queryable, env).__schema__(:type)
    }

    %Match{
      entity_alias: rel_alias,
      queryable: queryable,
      entity: rel
    }
  end

  defp extract_relationship(
         [{rel_alias, _, _}, {:__aliases__, _, _} = queryable_ast, {:%{}, _, properties}],
         start_node,
         end_node,
         env
       ) do
    queryable = Seraph.Schema.Helper.expand_alias(queryable_ast, env)

    %{props: props, params: params} = extract_properties(rel_alias, properties)

    rel = %Builder.RelationshipExpr{
      variable: Atom.to_string(rel_alias),
      start: start_node,
      end: end_node,
      type: Macro.expand(queryable, env).__schema__(:type),
      properties: props
    }

    prop_check =
      Enum.map(props, fn {prop_key, prop_value} ->
        {rel_alias, prop_key, prop_value}
      end)

    %Match{
      entity_alias: rel_alias,
      queryable: queryable,
      entity: rel,
      params: params,
      prop_check: prop_check
    }
  end

  defp extract_relationship(
         [{rel_alias, _, _}, {:%{}, _, properties}],
         start_node,
         end_node,
         _env
       ) do
    %{props: props, params: params} = extract_properties(rel_alias, properties)

    rel = %Builder.RelationshipExpr{
      variable: Atom.to_string(rel_alias),
      start: start_node,
      end: end_node,
      properties: props
    }

    prop_check =
      Enum.map(props, fn {prop_key, prop_value} ->
        {rel_alias, prop_key, prop_value}
      end)

    %Match{
      entity_alias: rel_alias,
      entity: rel,
      params: params,
      prop_check: prop_check
    }
  end

  defp extract_relationship([], start_node, end_node, _env) do
    rel = %Builder.RelationshipExpr{
      start: start_node,
      end: end_node
    }

    %Match{
      entity_alias: nil,
      entity: rel
    }
  end

  @spec extract_properties(atom, Keyword.t()) :: %{props: map, params: Keyword.t()}
  defp extract_properties(entity_alias, properties) do
    Enum.reduce(properties, %{props: %{}, params: []}, fn {k, v}, data ->
      key = Atom.to_string(entity_alias) <> "_" <> Atom.to_string(k)

      %{
        data
        | props: Map.put(data.props, k, key),
          params: Keyword.put(data.params, String.to_atom(key), interpolate(v))
      }
    end)
  end

  @spec interpolate(Macro.t()) :: Macro.t()
  defp interpolate({:^, _, [{name, _ctx, _env} = v]}) when is_atom(name) do
    v
  end

  defp interpolate(x) do
    x
  end
end
