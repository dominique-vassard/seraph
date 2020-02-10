defmodule Neo4jex.Schema.RelationshipTest do
  use ExUnit.Case, async: true

  alias Neo4jex.Test.WrotePost

  test "first" do
    %WrotePost{}
    |> IO.inspect()
  end

  defmodule WroteSimpleSchema do
    use Neo4jex.Schema.Relationship

    relationship "WROTE", cardinality: :one do
      start_node Neo4jex.Test.Post
      end_node Neo4jex.Test.User

      property :at, :utc_datetime
      property :virtual, :boolean, virtual: true
    end
  end

  test "schema metadata" do
    assert WroteSimpleSchema.__schema__(:type) == "WROTE"
    assert WroteSimpleSchema.__schema__(:cardinality) == :one

    assert WroteSimpleSchema.__schema__(:properties) == [:at, :virtual]
    assert WroteSimpleSchema.__schema__(:type, :at) == :utc_datetime
    assert WroteSimpleSchema.__schema__(:type, :virtual) == :boolean

    assert WroteSimpleSchema.__schema__(:changeset_properties) == [
             at: :utc_datetime,
             virtual: :boolean
           ]

    assert WroteSimpleSchema.__schema__(:persisted_properties) == [:at]
  end
end
