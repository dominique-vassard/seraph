defmodule Seraph.Query.Builder.Entity.Value do
  alias Seraph.Query.Builder.Entity.Value
  defstruct [:alias, :bound_name, :value]

  @type t :: %__MODULE__{
          alias: atom,
          bound_name: String.t(),
          value: any
        }
  defimpl Seraph.Query.Cypher, for: Value do
    def encode(%Value{alias: data_alias}, operation: :order_by) do
      "#{data_alias}"
    end

    def encode(%Value{alias: data_alias, bound_name: bound_name}, operation: :return) do
      "$#{bound_name} AS #{data_alias}"
    end
  end
end
