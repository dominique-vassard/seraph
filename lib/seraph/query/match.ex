defmodule Seraph.Query.Match do
  alias Seraph.Query.Builder

  @spec build(Macro.t(), any) :: {[Builder.entity_expr()], Keyword.t(), Keyword.t(), [tuple()]}
  def build(ast, env) do
    entity_list = Enum.map(ast, &extract_entity(&1, env))

    {rels, nodes} = Enum.split_with(entity_list, &is_list/1)

    nodes_aliases_list =
      nodes
      |> Enum.reject(fn
        {nil, _, _, _, _} -> true
        {_, _, _, _, _} -> false
      end)
      |> build_aliases()

    aliases =
      rels
      |> Enum.map(fn [start_data, end_data, {_, queryable, _, _, _} = rel_data] ->
        [
          fill_queryable(start_data, queryable, :start_node),
          fill_queryable(end_data, queryable, :end_node),
          rel_data
        ]
      end)
      |> List.flatten()
      |> Enum.reject(fn
        {nil, _, _, _, _} -> true
        {_, _, _, _, _} -> false
      end)
      |> build_aliases(:from_rels, nodes_aliases_list)

    {match, params, prop_check} =
      entity_list
      |> Enum.reduce({[], [], []}, fn
        [
          {_, _, _, start_params, start_prop_check},
          {_, _, _, end_params, end_prop_check},
          rel_data
        ],
        {match, params, prop_check} ->
          {_, _, rel, rel_params, rel_prop_check} = rel_data

          new_params =
            params
            |> Keyword.merge(start_params)
            |> Keyword.merge(end_params)
            |> Keyword.merge(rel_params)

          {[rel | match], new_params,
           prop_check ++ start_prop_check ++ end_prop_check ++ rel_prop_check}

        {_, _, node_data, node_params, node_prop_check}, {match, params, prop_check} ->
          {[node_data | match], Keyword.merge(params, node_params), prop_check ++ node_prop_check}
      end)

    {match, aliases, params, prop_check}
  end

  defp fill_queryable({node_alias, nil, node_data, params, prop_check}, queryable, node_type)
       when not is_nil(queryable) do
    {node_alias, queryable.__schema__(node_type), node_data, params, prop_check}
  end

  defp fill_queryable(node_data, _, _) do
    node_data
  end

  defp build_aliases(entity_data, from_entity_type \\ :from_node, aliases_list \\ [])

  defp build_aliases([], _, aliases_list) do
    aliases_list
  end

  defp build_aliases([{entity_alias, queryable, entity, _, _} | t], from_entity_type, []) do
    build_aliases(t, from_entity_type, Keyword.put([], entity_alias, {queryable, entity}))
  end

  defp build_aliases([{entity_alias, queryable, entity, _, _} | t], :from_node, aliases_list) do
    cond do
      Keyword.has_key?(aliases_list, entity_alias) ->
        raise ArgumentError,
              "alias #{inspect(entity_alias)} for #{inspect(queryable)} is invalid: already taken."

      true ->
        build_aliases(t, :from_node, Keyword.put(aliases_list, entity_alias, {queryable, entity}))
    end
  end

  defp build_aliases(
         [{entity_alias, queryable, %Builder.NodeExpr{} = entity, _, _} | t],
         :from_rels,
         aliases_list
       ) do
    existence = Keyword.get(aliases_list, entity_alias)

    cond do
      Kernel.match?({nil, _}, existence) ->
        build_aliases(t, :from_rels, Keyword.put(aliases_list, entity_alias, {queryable, entity}))

      Kernel.match?({^queryable, _}, existence) ->
        build_aliases(t, :from_rels, aliases_list)

      Keyword.has_key?(aliases_list, entity_alias) and is_nil(queryable) ->
        build_aliases(t, :from_rels, aliases_list)

      not Keyword.has_key?(aliases_list, entity_alias) ->
        build_aliases(t, :from_rels, Keyword.put(aliases_list, entity_alias, {queryable, entity}))

      true ->
        raise ArgumentError,
              "alias #{inspect(entity_alias)} for #{inspect(queryable)} is invalid: already taken."
    end
  end

  defp build_aliases(
         [{entity_alias, queryable, %Builder.RelationshipExpr{} = entity, _, _} | t],
         :from_rels,
         aliases_list
       ) do
    cond do
      not Keyword.has_key?(aliases_list, entity_alias) ->
        build_aliases(t, :from_rels, Keyword.put(aliases_list, entity_alias, {queryable, entity}))

      true ->
        raise ArgumentError,
              "alias #{inspect(entity_alias)} for #{inspect(queryable)} is invalid: already taken."
    end
  end

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

    {node_alias, queryable, node, params, prop_check}
  end

  defp extract_entity({{node_alias, _, _}, {:%{}, _, properties}}, _env) do
    %{props: props, params: params} = extract_properties(node_alias, properties)

    node = %Builder.NodeExpr{
      variable: Atom.to_string(node_alias),
      properties: props
    }

    {node_alias, nil, node, params, []}
  end

  defp extract_entity({{node_alias, _, _}, {:__aliases__, _, _} = queryable_ast}, env) do
    queryable = Seraph.Schema.Helper.expand_alias(queryable_ast, env)

    node = %Builder.NodeExpr{
      variable: Atom.to_string(node_alias),
      labels: [Macro.expand(queryable, env).__schema__(:primary_label)]
    }

    {node_alias, queryable, node, [], []}
  end

  defp extract_entity({:{}, _, [{:__aliases__, _, _} = queryable_ast]}, env) do
    queryable = Seraph.Schema.Helper.expand_alias(queryable_ast, env)

    node = %Builder.NodeExpr{
      labels: [Macro.expand(queryable, env).__schema__(:primary_label)]
    }

    {nil, queryable, node, [], []}
  end

  defp extract_entity({:{}, _, [{node_alias, _, _}]}, _env) do
    node = %Builder.NodeExpr{
      variable: Atom.to_string(node_alias)
    }

    {node_alias, nil, node, [], []}
  end

  defp extract_entity({:{}, _, []}, _env) do
    raise ArgumentError, "Empty nodes are not supported except in relationships."
  end

  defp extract_entity([start_ast, relationship_ast, end_ast], env) do
    start_data = extract_empty_node(start_ast, env) || extract_entity(start_ast, env)
    end_data = extract_empty_node(end_ast, env) || extract_entity(end_ast, env)

    {_, _, start_node, _, _} = start_data
    {_, _, end_node, _, _} = end_data

    result = [
      start_data,
      end_data,
      extract_relationship(relationship_ast, start_node, end_node, env)
    ]

    all_empty? =
      Enum.all?(result, fn
        {nil, nil, _, _, _} -> true
        _ -> false
      end)

    if all_empty? do
      raise ArgumentError, "Empty relationships are not allowed."
    end

    result
  end

  defp extract_empty_node({:{}, _, []}, _env) do
    node = %Builder.NodeExpr{}

    {nil, nil, node, [], []}
  end

  defp extract_empty_node(_, _) do
    nil
  end

  defp extract_relationship([{rel_alias, _, nil}], start_node, end_node, _env) do
    rel = %Builder.RelationshipExpr{
      start: start_node,
      end: end_node,
      variable: Atom.to_string(rel_alias)
    }

    {rel_alias, nil, rel, [], []}
  end

  defp extract_relationship([{:__aliases__, _, _} = queryable_ast], start_node, end_node, env) do
    queryable = Seraph.Schema.Helper.expand_alias(queryable_ast, env)

    rel = %Builder.RelationshipExpr{
      start: start_node,
      end: end_node,
      type: Macro.expand(queryable, env).__schema__(:type)
    }

    {nil, queryable, rel, [], []}
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

    {rel_alias, queryable, rel, [], []}
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

    {rel_alias, queryable, rel, params, prop_check}
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

    {rel_alias, nil, rel, params, prop_check}
  end

  defp extract_relationship([], start_node, end_node, _env) do
    rel = %Builder.RelationshipExpr{
      start: start_node,
      end: end_node
    }

    {nil, nil, rel, [], []}
  end

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

  defp interpolate({:^, _, [{name, _ctx, _env} = v]}) when is_atom(name) do
    v
  end

  defp interpolate(x) do
    x
  end
end
