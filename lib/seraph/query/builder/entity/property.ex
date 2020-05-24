defmodule Seraph.Query.Builder.Entity.Property do
  alias Seraph.Query.Builder.Entity.Property
  @moduledoc false
  defstruct [:alias, :bound_name, :entity_identifier, :entity_queryable, :name, :value, :type]

  @type t :: %__MODULE__{
          alias: nil | String.t(),
          bound_name: nil | String.t(),
          entity_identifier: String.t(),
          entity_queryable: Seraph.Repo.queryable() | Seraph.Node.t(),
          name: atom(),
          type: atom,
          value: any()
        }

  @spec from_map(map, Seraph.Query.Builder.Entity.t()) :: [Property.t()]
  def from_map(properties, entity) do
    properties
    |> Enum.map(fn {prop_key, prop_value} ->
      %Property{
        entity_identifier: entity.identifier,
        entity_queryable: entity.queryable,
        name: prop_key,
        value: prop_value
      }
    end)
  end

  defimpl Seraph.Query.Cypher, for: Property do
    @spec encode(Seraph.Query.Builder.Entity.Property.t(), Keyword.t()) :: String.t()
    def encode(%Property{bound_name: bound_name, name: name}, _) do
      "#{Atom.to_string(name)}: $#{bound_name}"
    end

    def encode(%Property{entity_identifier: entity_identifier, name: name}, operation: :return) do
      "#{entity_identifier}.#{name}"
    end
  end
end
