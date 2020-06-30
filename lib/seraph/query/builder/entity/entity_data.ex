defmodule Seraph.Query.Builder.Entity.EntityData do
  alias Seraph.Query.Builder.Entity.EntityData
  defstruct [:alias, :entity_identifier, :property]

  @type t :: %__MODULE__{
          alias: atom,
          entity_identifier: String.t(),
          property: nil | atom
        }

  defimpl Seraph.Query.Cypher, for: EntityData do
    @spec encode(EntityData.t(), Keyword.t()) :: String.t()
    def encode(%EntityData{entity_identifier: entity_identifier, property: nil}, _) do
      "#{entity_identifier}"
    end

    def encode(%EntityData{entity_identifier: entity_identifier, property: property}, _) do
      "#{entity_identifier}.#{property}"
    end
  end
end
