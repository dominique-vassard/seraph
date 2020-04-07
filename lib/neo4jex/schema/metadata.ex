defmodule Seraph.Schema.Metadata do
  defstruct [:source, :schema]

  @type t :: %__MODULE__{
          source: String.t(),
          schema: module
        }
end
