defmodule Seraph.Node do
  defstruct [:__id__, :labels, properties: %{}]

  @type t :: %__MODULE__{
          __id__: integer,
          labels: [String.t()],
          properties: map
        }

  def map(%Bolt.Sips.Types.Node{id: id, labels: labels, properties: properties}) do
    %Seraph.Node{
      __id__: id,
      labels: labels,
      properties: properties
    }
  end
end
