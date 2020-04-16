defmodule Seraph.Schema do
  @moduledoc """
  Represents available schemas.
  """

  @type t :: Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
end
