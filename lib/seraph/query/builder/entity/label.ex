defmodule Seraph.Query.Builder.Entity.Label do
  alias Seraph.Query.Builder.Entity.Label

  defstruct [:node_identifier, :values]

  @type t :: %__MODULE__{
          node_identifier: String.t(),
          values: [String.t()]
        }

  defimpl Seraph.Query.Cypher, for: Label do
    def encode(%Label{node_identifier: identifier, values: labels}, _) do
      labels_str = Enum.join(labels, ":")
      "#{identifier}:#{labels_str}"
    end
  end
end
