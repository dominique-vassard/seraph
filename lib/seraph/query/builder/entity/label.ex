defmodule Seraph.Query.Builder.Entity.Label do
  defstruct [:node_identifier, :values]

  @type t :: %__MODULE__{
          node_identifier: String.t(),
          values: [String.t()]
        }
end
