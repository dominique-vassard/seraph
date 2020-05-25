defmodule Seraph.Query.Builder.Match do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.Match
  alias Seraph.Query.Builder.Entity
  alias Seraph.Query.Builder.Helper

  defstruct [:entities]

  @type t :: %__MODULE__{
          entities: [Entity.t()]
        }

  @impl true
  def build(ast, env) do
    entity_list = Enum.map(ast, &build_entity(&1, env))

    match_data =
      Enum.reduce(
        entity_list,
        %{entities: [], identifiers: %{}, params: []},
        fn entity, query_data ->
          %{entity: new_entity, params: updated_params} =
            Entity.manage_params(entity, query_data.params)

          check_identifier_presence(query_data.identifiers, new_entity.identifier)

          %{
            query_data
            | entities: [new_entity | query_data.entities],
              identifiers: build_identifiers(new_entity, query_data.identifiers),
              params: updated_params
          }
        end
      )

    match_data
    |> Map.put(:match, %Match{entities: match_data.entities})
    |> Map.drop([:entities])
  end

  @impl true
  @spec check(Match.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(match_data, query) do
    Enum.reduce_while(match_data.entities, :ok, fn %{properties: properties}, _ ->
      case check_properties(properties, query.params) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @spec check_properties([Entity.Property.t()], Keyword.t()) :: :ok | {:error, String.t()}
  defp check_properties(properties, query_params) do
    Enum.reduce_while(properties, :ok, fn property, _ ->
      case Keyword.fetch!(query_params, String.to_atom(property.bound_name)) do
        nil ->
          {:halt, {:error, "`nil` is not a valid value. Use `is_nil(property)` instead."}}

        value ->
          case Helper.check_property(property.entity_queryable, property.name, value) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
      end
    end)
  end

  @spec build_entity(Macro.t(), Macro.Env.t(), nil | :from_rel) :: Entity.t()
  defp build_entity(ast, env, call_from \\ nil)
  # Node with identifier, queryable and properties
  # {u, User, %{uuid: "uuid-2"}}
  # {u, User, %{uuid: ^uuid}}
  defp build_entity(
         {:{}, _,
          [
            {node_identifier, _, _},
            {:__aliases__, _, _} = queryable_ast,
            {:%{}, _, properties}
          ]},
         env,
         _
       ) do
    queryable = Macro.expand(queryable_ast, env)
    identifier = Atom.to_string(node_identifier)

    %Entity.Node{
      queryable: queryable,
      identifier: identifier,
      labels: [queryable.__schema__(:primary_label)],
      properties: build_properties(queryable, identifier, properties)
    }
  end

  # Node with node identifier, queryable, properties
  # {User, %{uuid: ^user_uuid}
  defp build_entity({{:__aliases__, _, _} = queryable_ast, {:%{}, _, properties}}, env, _) do
    queryable = Macro.expand(queryable_ast, env)

    %Entity.Node{
      queryable: queryable,
      identifier: nil,
      labels: [queryable.__schema__(:primary_label)],
      properties: build_properties(queryable, nil, properties)
    }
  end

  # Node with no identifier, no queryable, properties
  # {u, %{uuid: ^user_uuid}
  defp build_entity({{node_identifier, _, _}, {:%{}, _, properties}}, _env, _) do
    queryable = Seraph.Node
    identifier = Atom.to_string(node_identifier)

    %Entity.Node{
      queryable: queryable,
      identifier: identifier,
      properties: build_properties(queryable, identifier, properties)
    }
  end

  # Node with only a queryable: allowed inside a relationship
  defp build_entity({:{}, _, [{:__aliases__, _, _} = queryable_ast]}, env, :from_rel) do
    queryable = Macro.expand(queryable_ast, env)

    %Entity.Node{
      queryable: queryable,
      labels: [queryable.__schema__(:primary_label)]
    }
  end

  # Node with only a queryable: not allowed in any other case
  defp build_entity({:{}, _, [{:__aliases__, _, [_]}]}, _env, _) do
    raise ArgumentError, "Nodes with only a queryable are not allowed except i nrelationships."
  end

  # Node with identifier, no queryable, no properties
  # {u}
  defp build_entity({:{}, _, [{node_identifier, _, _}]}, _env, _) do
    identifier = Atom.to_string(node_identifier)

    %Entity.Node{
      queryable: Seraph.Node,
      identifier: identifier
    }
  end

  # Node with identifier, queryable, no properties
  # {u, User}
  defp build_entity({{node_identifier, _, _}, {:__aliases__, _, _} = queryable_ast}, env, _) do
    queryable = Macro.expand(queryable_ast, env)
    identifier = Atom.to_string(node_identifier)

    %Entity.Node{
      queryable: queryable,
      identifier: identifier,
      labels: [queryable.__schema__(:primary_label)]
    }
  end

  # Empty node: allowed inside a relationship
  # {}
  defp build_entity({:{}, _, []}, _env, :from_rel) do
    %Entity.Node{
      queryable: Seraph.Node,
      identifier: nil
    }
  end

  # Empty node: not allowed in any other case
  # {}
  defp build_entity({:{}, _, []}, _env, _) do
    raise ArgumentError, "Empty nodes are not supported except in relationships."
  end

  # Empty relationship
  # [{}, [], {}]
  defp build_entity([{:{}, _, []}, [], {:{}, _, []}], _env, _) do
    raise ArgumentError, "Empty relationships are not allowed."
  end

  # Relationship with no identifier, no queryable, no properties
  # []
  defp build_entity([], _env, _) do
    %Entity.Relationship{}
  end

  # Relationship with no identifier, queryable, no properties
  # [Wrote]
  defp build_entity([{:__aliases__, _, _} = queryable_ast], env, _) do
    queryable = Macro.expand(queryable_ast, env)

    %Entity.Relationship{
      queryable: queryable,
      type: queryable.__schema__(:type)
    }
  end

  # Relationship with no identifier, queryable, properties
  # [Wrote, %{at: ^date}]
  defp build_entity([{:__aliases__, _, _} = queryable_ast, {:%{}, _, properties}], env, _) do
    queryable = Macro.expand(queryable_ast, env)

    %Entity.Relationship{
      queryable: queryable,
      identifier: nil,
      type: queryable.__schema__(:type),
      properties: build_properties(queryable, nil, properties)
    }
  end

  # Relationship with identifier, queryable, no properties
  # [rel, Wrote]
  defp build_entity([{rel_identifier, _, _}, {:__aliases__, _, _} = queryable_ast], env, _) do
    queryable = Macro.expand(queryable_ast, env)
    identifier = Atom.to_string(rel_identifier)

    %Entity.Relationship{
      queryable: queryable,
      identifier: identifier,
      type: queryable.__schema__(:type)
    }
  end

  # Relationship with identifier, no queryable, properties
  # [rel, %{at: ^date}]
  defp build_entity([{rel_identifier, _, _}, {:%{}, _, properties}], _env, _) do
    queryable = Seraph.Relationship
    identifier = Atom.to_string(rel_identifier)

    %Entity.Relationship{
      queryable: queryable,
      identifier: identifier,
      properties: build_properties(queryable, identifier, properties)
    }
  end

  # Relationship with identifier, no queryable, no properties
  # [rel]
  defp build_entity([{rel_identifier, _, _}], _env, _) do
    identifier = Atom.to_string(rel_identifier)

    %Entity.Relationship{
      queryable: Seraph.Relationship,
      identifier: identifier
    }
  end

  # Relationship with no identifier, string queryable, no properties
  # ["WROTE"]
  defp build_entity([rel_type], _env, _) when is_bitstring(rel_type) do
    rel_type = String.upcase(rel_type)
    check_string_relationship_type(rel_type)

    %Entity.Relationship{
      queryable: Seraph.Relationship,
      type: rel_type
    }
  end

  # Relationship with identifier, string queryable, no properties
  # [rel, "WROTE"]
  defp build_entity([{rel_identifier, _, _}, rel_type], _env, _) when is_bitstring(rel_type) do
    rel_type = String.upcase(rel_type)
    check_string_relationship_type(rel_type)

    %Entity.Relationship{
      identifier: Atom.to_string(rel_identifier),
      queryable: Seraph.Relationship,
      type: rel_type
    }
  end

  # Relationship with identifier, string queryable, properties
  # [rel, "WROTE, %{at: ^date}]
  defp build_entity([{rel_identifier, _, _}, rel_type, {:%{}, _, properties}], _env, _)
       when is_bitstring(rel_type) do
    queryable = Seraph.Relationship
    identifier = Atom.to_string(rel_identifier)
    rel_type = String.upcase(rel_type)
    check_string_relationship_type(rel_type)

    %Entity.Relationship{
      queryable: queryable,
      identifier: identifier,
      type: rel_type,
      properties: build_properties(queryable, identifier, properties)
    }
  end

  # Relationship with no identifier, string queryable, properties
  # ["WROTE", %{at: ^date}]
  defp build_entity([rel_type, {:%{}, _, properties}], _env, _) when is_bitstring(rel_type) do
    queryable = Seraph.Relationship
    rel_type = String.upcase(rel_type)
    check_string_relationship_type(rel_type)

    %Entity.Relationship{
      queryable: queryable,
      type: rel_type,
      properties: build_properties(queryable, nil, properties)
    }
  end

  # Relationship with identifier, queryable, properties
  # [rel, Wrote, %{at: ^date}]
  defp build_entity(
         [{rel_identifier, _, _}, {:__aliases__, _, _} = queryable_ast, {:%{}, _, properties}],
         env,
         _
       ) do
    queryable = Macro.expand(queryable_ast, env)
    identifier = Atom.to_string(rel_identifier)

    %Entity.Relationship{
      queryable: queryable,
      identifier: identifier,
      type: queryable.__schema__(:type),
      properties: build_properties(queryable, identifier, properties)
    }
  end

  # Match a relationship type and build it
  defp build_entity([start_ast, relationship_ast, end_ast], env, _) do
    start_data = build_entity(start_ast, env, :from_rel)
    end_data = build_entity(end_ast, env, :from_rel)

    relationship = build_entity(relationship_ast, env)

    start_node = fill_queryable(start_data, relationship.queryable, :start_node)
    end_node = fill_queryable(end_data, relationship.queryable, :end_node)

    relationship
    |> Map.put(:start, start_node)
    |> Map.put(:end, end_node)
  end

  @spec build_identifiers(Entity.t(), %{String.t() => Entity.t()}) :: %{String.t() => Entity.t()}
  defp build_identifiers(%Entity.Node{identifier: nil}, current_identifiers) do
    current_identifiers
  end

  defp build_identifiers(%Entity.Node{} = entity, current_identifiers) do
    check_identifier_presence(current_identifiers, entity.identifier)
    Map.put(current_identifiers, entity.identifier, entity)
  end

  defp build_identifiers(%Entity.Relationship{} = relationship, current_identifiers) do
    new_identifiers =
      current_identifiers
      |> build_relationship_nodes_identifiers(relationship.start)
      |> build_relationship_nodes_identifiers(relationship.end)

    if is_nil(relationship.identifier) do
      new_identifiers
    else
      check_identifier_presence(current_identifiers, relationship.identifier)
      Map.put(new_identifiers, relationship.identifier, relationship)
    end
  end

  @spec build_relationship_nodes_identifiers(%{String.t() => Entity.t()}, Entity.t()) :: %{
          String.t() => Entity.t()
        }
  defp build_relationship_nodes_identifiers(current_identifiers, %Entity.Node{identifier: nil}) do
    current_identifiers
  end

  defp build_relationship_nodes_identifiers(
         current_identifiers,
         %Entity.Node{identifier: identifier} = node_data
       ) do
    case Map.fetch(current_identifiers, identifier) do
      :error ->
        Map.put(current_identifiers, identifier, node_data)

      {:ok, %Entity.Node{queryable: Seraph.Node}} ->
        current_identifiers
        |> Map.drop([identifier])
        |> Map.put(identifier, node_data)

      {:ok, %Entity.Node{queryable: queryable}} ->
        if queryable != node_data.queryable do
          message =
            "identifier `#{identifier}` for schema `#{inspect(node_data.queryable)}` is already used for schema `#{
              inspect(queryable)
            }`"

          raise ArgumentError, message
        end

      {:ok, %Entity.Relationship{}} ->
        raise ArgumentError, "identifier `#{identifier}` is already taken."
    end
  end

  defp check_string_relationship_type(relationship_type) do
    if not Regex.match?(~r/^[A-Z][A-Z0-9_]*$/, relationship_type) do
      message =
        "`#{relationship_type}` is not a valid relationship type. Allowed format: ^[A-Z][A-Z0-9_]*$."

      raise ArgumentError, message
    end
  end

  @spec check_identifier_presence(map, String.t()) :: :ok
  defp check_identifier_presence(identifiers, candidate) do
    case Map.fetch(identifiers, candidate) do
      {:ok, _} -> raise ArgumentError, "identifier `#{candidate}` is already taken."
      :error -> :ok
    end
  end

  @spec build_properties(Seraph.Repo.queryable(), nil | String.t(), Keyword.t()) :: [
          Entity.Property
        ]
  defp build_properties(queryable, identifier, properties) do
    Enum.reduce(properties, [], fn {prop_key, prop_value}, prop_list ->
      property = %Entity.Property{
        entity_identifier: identifier,
        entity_queryable: queryable,
        name: prop_key,
        value: interpolate(prop_value)
      }

      [property | prop_list]
    end)
  end

  @spec interpolate(Macro.t()) :: Macro.t()
  defp interpolate({:^, _, [{name, _ctx, _env} = value]}) when is_atom(name) do
    value
  end

  defp interpolate(value) do
    value
  end

  @spec fill_queryable(Entity.Node.t(), Seraph.Repo.queryable(), :start_node | :end_node) ::
          Entity.Node.t()
  defp fill_queryable(node_data, Seraph.Relationship, _) do
    node_data
  end

  defp fill_queryable(%Entity.Node{queryable: Seraph.Node} = node_data, rel_queryable, node_type) do
    node_queryable = rel_queryable.__schema__(node_type)

    new_props =
      node_data.properties
      |> Enum.map(fn prop ->
        Map.put(prop, :entity_queryable, node_queryable)
      end)

    node_data
    |> Map.put(:queryable, node_queryable)
    |> Map.put(:labels, [node_queryable.__schema__(:primary_label)])
    |> Map.put(:properties, new_props)
  end

  defp fill_queryable(node_data, rel_queryable, node_type) do
    node_queryable = rel_queryable.__schema__(node_type)

    if node_data.queryable == node_queryable do
      node_data
    else
      message = """
      `#{inspect(node_data.queryable)}` is not a valid #{inspect(node_type)} for `#{
        inspect(rel_queryable)
      }`.
      It should be a `#{inspect(node_queryable)}`.
      """

      raise ArgumentError, message
    end
  end

  defimpl Seraph.Query.Cypher, for: Match do
    def encode(%Match{entities: entities}, _) do
      match_str =
        entities
        |> Enum.map(&Seraph.Query.Cypher.encode(&1, operation: :match))
        |> Enum.join("\n\t")

      if String.length(match_str) > 0 do
        """
        MATCH
          #{match_str}
        """
      end
    end
  end
end
