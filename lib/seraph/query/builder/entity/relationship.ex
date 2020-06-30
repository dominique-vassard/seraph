defmodule Seraph.Query.Builder.Entity.Relationship do
  @moduledoc false
  alias Seraph.Query.Builder.Entity.Relationship
  alias Seraph.Query.Builder.Entity

  defstruct [
    :identifier,
    :start,
    :end,
    :type,
    :alias,
    properties: [],
    queryable: Seraph.Relationship
  ]

  @type t :: %__MODULE__{
          queryable: Seraph.Repo.queryable() | module,
          identifier: nil | String.t(),
          start: nil | Entity.Node.t(),
          end: nil | Entity.Node.t(),
          type: String.t(),
          alias: nil | String.t(),
          properties: [Entity.Property.t()]
        }

  # Empty relationship
  # [{}, [], {}]
  @spec from_ast(Macro.t(), Macro.Env.t()) :: Relationship.t()
  def from_ast([{:{}, _, []}, [], {:{}, _, []}], _env) do
    raise ArgumentError, "Empty relationships are not allowed."
  end

  # Relationship with no identifier, no queryable, no properties
  # []
  def from_ast([], _env) do
    %Entity.Relationship{}
  end

  # Relationship with no identifier, queryable, no properties
  # [Wrote]
  def from_ast([{:__aliases__, _, _} = queryable_ast], env) do
    queryable = Macro.expand(queryable_ast, env)

    %Entity.Relationship{
      queryable: queryable,
      type: queryable.__schema__(:type)
    }
  end

  # Relationship with no identifier, queryable, properties
  # [Wrote, %{at: ^date}]
  def from_ast([{:__aliases__, _, _} = queryable_ast, {:%{}, _, properties}], env) do
    queryable = Macro.expand(queryable_ast, env)

    %Entity.Relationship{
      queryable: queryable,
      identifier: nil,
      type: queryable.__schema__(:type),
      properties: Entity.build_properties(queryable, nil, properties)
    }
  end

  # Relationship with identifier, queryable, no properties
  # [rel, Wrote]
  def from_ast([{rel_identifier, _, _}, {:__aliases__, _, _} = queryable_ast], env) do
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
  def from_ast([{rel_identifier, _, _}, {:%{}, _, properties}], _env) do
    queryable = Seraph.Relationship
    identifier = Atom.to_string(rel_identifier)

    %Entity.Relationship{
      queryable: queryable,
      identifier: identifier,
      properties: Entity.build_properties(queryable, identifier, properties)
    }
  end

  # Realtionship with no identifier, no queryable, properties
  # [%{at: ^date}]
  def from_ast([{:%{}, _, properties}], _env) do
    queryable = Seraph.Relationship

    %Entity.Relationship{
      queryable: queryable,
      properties: Entity.build_properties(queryable, nil, properties)
    }
  end

  # Relationship with identifier, no queryable, no properties
  # [rel]
  def from_ast([{rel_identifier, _, _}], _env) do
    identifier = Atom.to_string(rel_identifier)

    %Entity.Relationship{
      queryable: Seraph.Relationship,
      identifier: identifier
    }
  end

  # Relationship with no identifier, string queryable, no properties
  # ["WROTE"]
  def from_ast([rel_type], _env) when is_bitstring(rel_type) do
    rel_type = String.upcase(rel_type)
    check_string_relationship_type(rel_type)

    %Entity.Relationship{
      queryable: Seraph.Relationship,
      type: rel_type
    }
  end

  # Relationship with identifier, string queryable, no properties
  # [rel, "WROTE"]
  def from_ast([{rel_identifier, _, _}, rel_type], _env) when is_bitstring(rel_type) do
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
  def from_ast([{rel_identifier, _, _}, rel_type, {:%{}, _, properties}], _env)
      when is_bitstring(rel_type) do
    queryable = Seraph.Relationship
    identifier = Atom.to_string(rel_identifier)
    rel_type = String.upcase(rel_type)
    check_string_relationship_type(rel_type)

    %Entity.Relationship{
      queryable: queryable,
      identifier: identifier,
      type: rel_type,
      properties: Entity.build_properties(queryable, identifier, properties)
    }
  end

  # Relationship with no identifier, string queryable, properties
  # ["WROTE", %{at: ^date}]
  def from_ast([rel_type, {:%{}, _, properties}], _env) when is_bitstring(rel_type) do
    queryable = Seraph.Relationship
    rel_type = String.upcase(rel_type)
    check_string_relationship_type(rel_type)

    %Entity.Relationship{
      queryable: queryable,
      type: rel_type,
      properties: Entity.build_properties(queryable, nil, properties)
    }
  end

  # Relationship with identifier, queryable, properties
  # [rel, Wrote, %{at: ^date}]
  def from_ast(
        [{rel_identifier, _, _}, {:__aliases__, _, _} = queryable_ast, {:%{}, _, properties}],
        env
      ) do
    queryable = Macro.expand(queryable_ast, env)
    identifier = Atom.to_string(rel_identifier)

    %Entity.Relationship{
      queryable: queryable,
      identifier: identifier,
      type: queryable.__schema__(:type),
      properties: Entity.build_properties(queryable, identifier, properties)
    }
  end

  # Match a relationship type and build it
  def from_ast([start_ast, relationship_ast, end_ast], env) do
    start_data = Entity.Node.from_ast(start_ast, env)
    end_data = Entity.Node.from_ast(end_ast, env)

    relationship = from_ast(relationship_ast, env)

    start_node = fill_queryable(start_data, relationship.queryable, :start_node)
    end_node = fill_queryable(end_data, relationship.queryable, :end_node)

    relationship
    |> Map.put(:start, start_node)
    |> Map.put(:end, end_node)
  end

  @spec from_queryable(
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map,
          map,
          String.t(),
          String.t()
        ) :: %{entity: Relationship.t(), params: Keyword.t()}
  def from_queryable(
        queryable,
        start_struct_or_data,
        end_struct_or_data,
        rel_properties,
        identifier \\ "rel",
        prefix
      ) do
    start_properties = extract_node_properties(start_struct_or_data)
    end_properties = extract_node_properties(end_struct_or_data)

    start_queryable = queryable.__schema__(:start_node)
    end_queryable = queryable.__schema__(:end_node)

    %{entity: start_node, params: start_params} =
      Entity.Node.from_queryable(start_queryable, start_properties, prefix, "start")

    %{entity: end_node, params: end_params} =
      Entity.Node.from_queryable(end_queryable, end_properties, prefix, "end")

    relationship =
      %Relationship{
        queryable: queryable,
        identifier: identifier,
        type: queryable.__schema__(:type)
      }
      |> Map.put(:start, start_node)
      |> Map.put(:end, end_node)

    props = Entity.Property.from_map(rel_properties, relationship)

    %{entity: final_rel, params: rel_params} =
      Entity.extract_params(
        Map.put(relationship, :properties, props),
        [],
        prefix
      )

    params =
      rel_params
      |> Keyword.merge(start_params)
      |> Keyword.merge(end_params)

    %{entity: final_rel, params: params}
  end

  @spec check_string_relationship_type(String.t()) :: nil
  defp check_string_relationship_type(relationship_type) do
    if not Regex.match?(~r/^[A-Z][A-Z0-9_]*$/, relationship_type) do
      message =
        "`#{relationship_type}` is not a valid relationship type. Allowed format: ^[A-Z][A-Z0-9_]*$."

      raise ArgumentError, message
    end
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

  @spec extract_node_properties(Seraph.Schema.Node.t()) :: map
  def extract_node_properties(%{__struct__: queryable} = node_data) do
    id_field = Seraph.Repo.Helper.identifier_field!(queryable)
    id_value = Map.fetch!(node_data, id_field)

    Map.put(%{}, id_field, id_value)
  end

  def extract_node_properties(node_properties) do
    node_properties
  end

  defimpl Seraph.Query.Cypher, for: Relationship do
    @spec encode(Relationship.t(), Keyword.t()) :: String.t()
    def encode(%Relationship{identifier: identifier}, operation: :delete) do
      "#{identifier}"
    end

    def encode(%Relationship{alias: rel_alias, identifier: identifier}, operation: :return)
        when not is_nil(rel_alias) do
      "#{identifier} AS #{rel_alias}"
    end

    def encode(%Relationship{identifier: identifier}, operation: operation)
        when operation in [:return, :order_by] do
      identifier
    end

    def encode(
          %Relationship{
            identifier: identifier,
            start: start_node,
            end: end_node,
            type: rel_type,
            properties: []
          },
          opts
        ) do
      rel_type_str =
        unless is_nil(rel_type) do
          ":#{rel_type}"
        end

      Seraph.Query.Cypher.encode(start_node, opts) <>
        "-[#{identifier}#{rel_type_str}]->" <> Seraph.Query.Cypher.encode(end_node, opts)
    end

    def encode(
          %Relationship{
            identifier: identifier,
            start: start_node,
            end: end_node,
            type: rel_type,
            properties: properties
          },
          opts
        ) do
      rel_type_str =
        unless is_nil(rel_type) do
          ":#{rel_type}"
        end

      props =
        Enum.map(properties, &Seraph.Query.Cypher.encode/1)
        |> Enum.join(",")

      Seraph.Query.Cypher.encode(start_node, opts) <>
        "-[#{identifier}#{rel_type_str} {#{props}}]->" <>
        Seraph.Query.Cypher.encode(end_node, opts)
    end
  end
end
