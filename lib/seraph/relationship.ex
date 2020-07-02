defmodule Seraph.Relationship do
  @moduledoc """
  Represents a Relationship without a defined schema.
  """
  defstruct [:__id__, :type, :start_node, :end_node, properties: %{}]

  @type t :: %__MODULE__{
          __id__: integer,
          type: String.t(),
          start_node: nil | Seraph.Schema.Node.t(),
          end_node: nil | Seraph.Schema.Node.t(),
          properties: map
        }

  @doc false
  @spec map(String.t(), %{
          __id__: integer,
          end_node: nil | Seraph.Node.t() | Seraph.Schema.Node.t(),
          start_node: nil | Seraph.Node.t() | Seraph.Schema.Node.t()
        }) :: Seraph.Relationship.t()
  def map(rel_type, result_props) do
    %Seraph.Relationship{
      __id__: result_props.__id__,
      type: rel_type,
      start_node: result_props.start_node,
      end_node: result_props.end_node,
      properties: Map.drop(result_props, [:__id__, :start_node, :end_node])
    }
  end
end
