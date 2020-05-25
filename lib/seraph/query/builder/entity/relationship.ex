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
          start: Entity.Node.t(),
          end: Entity.Node.t(),
          type: String.t(),
          alias: nil | String.t(),
          properties: [Entity.Property.t()]
        }

  @spec from_queryable(
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map,
          map,
          String.t()
        ) :: %{entity: Relationship.t(), params: Keyword.t()}
  def from_queryable(
        queryable,
        start_struct_or_data,
        end_struct_or_data,
        rel_properties,
        identifier \\ "rel"
      ) do
    start_properties = extract_node_properties(start_struct_or_data)
    end_properties = extract_node_properties(end_struct_or_data)

    start_queryable = queryable.__schema__(:start_node)
    end_queryable = queryable.__schema__(:end_node)

    %{entity: start_node, params: start_params} =
      Entity.Node.from_queryable(start_queryable, start_properties, "start")

    %{entity: end_node, params: end_params} =
      Entity.Node.from_queryable(end_queryable, end_properties, "end")

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
      Entity.manage_params(
        Map.put(relationship, :properties, props),
        []
      )

    params =
      rel_params
      |> Keyword.merge(start_params)
      |> Keyword.merge(end_params)

    %{entity: final_rel, params: params}
  end

  def extract_node_properties(%{__struct__: queryable} = node_data) do
    id_field = Seraph.Repo.Helper.identifier_field(queryable)
    id_value = Map.fetch!(node_data, id_field)

    Map.put(%{}, id_field, id_value)
  end

  def extract_node_properties(node_properties) do
    node_properties
  end

  # def from_queryable(queryable, _properties \\ %{}, identifier \\ "rel") do
  #   # relationship = %Relationship{
  #   %Relationship{
  #     queryable: queryable,
  #     identifier: identifier,
  #     type: queryable.__schema__(:type)
  #   }

  #   # props = Entity.Property.from_map(properties, relationship)

  #   # Map.put(relationship, :properties, props)
  # end

  defimpl Seraph.Query.Cypher, for: Relationship do
    def encode(%Relationship{alias: rel_alias, identifier: identifier}, operation: :return)
        when not is_nil(rel_alias) do
      "#{identifier} AS #{rel_alias}"
    end

    def encode(%Relationship{identifier: identifier}, operation: :return) do
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
