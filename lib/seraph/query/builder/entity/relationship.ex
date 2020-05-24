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
    properties: %{},
    queryable: Seraph.Relationship
  ]

  @type t :: %__MODULE__{
          queryable: Seraph.Repo.queryable() | module,
          identifier: nil | String.t(),
          start: Entity.Node.t(),
          end: Entity.Node.t(),
          type: String.t(),
          alias: nil | String.t(),
          properties: map
        }

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
        "-[#{identifier}#{rel_type_str} {#{props}]->" <>
        Seraph.Query.Cypher.encode(end_node, opts)
    end
  end
end
