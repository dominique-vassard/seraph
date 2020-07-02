defmodule Seraph.Node do
  @moduledoc """
  Represents a Node without a defined schema.
  """
  defstruct [:__id__, :labels, properties: %{}]

  @type t :: %__MODULE__{
          __id__: integer,
          labels: [String.t()],
          properties: map
        }

  @doc false
  @spec map(Bolt.Sips.Types.Node.t()) :: Seraph.Node.t()
  def map(%Bolt.Sips.Types.Node{id: id, labels: labels, properties: properties}) do
    %Seraph.Node{
      __id__: id,
      labels: labels,
      properties: properties
    }
  end
end
