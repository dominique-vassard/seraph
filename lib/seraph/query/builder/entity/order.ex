defmodule Seraph.Query.Builder.Entity.Order do
  alias Seraph.Query.Builder.Entity
  alias Seraph.Query.Builder.Entity.Order

  defstruct [:entity, order: :asc]

  @type t :: %__MODULE__{
          entity: Entity.EntityData | Entity.Value,
          order: :asc | :desc
        }

  @spec build_from_ast(Macro.t() | tuple()) :: Order.t()
  def build_from_ast({order, data}) do
    build_from_ast(data)
    |> Map.put(:order, order)
  end

  def build_from_ast({{:., _, [{identifier, _, _}, property]}, _, _}) do
    %Order{
      entity: %Entity.EntityData{
        entity_identifier: Atom.to_string(identifier),
        property: property
      },
      order: :asc
    }
  end

  def build_from_ast({identifier, _, _}) do
    %Order{
      entity: %Entity.EntityData{
        entity_identifier: Atom.to_string(identifier)
      },
      order: :asc
    }
  end

  defimpl Seraph.Query.Cypher, for: Order do
    def encode(%Order{order: order, entity: entity}, opts) do
      entity_str = Seraph.Query.Cypher.encode(entity, opts)
      order_str = order |> Atom.to_string() |> String.upcase()
      "#{entity_str} #{order_str}"
    end
  end
end
