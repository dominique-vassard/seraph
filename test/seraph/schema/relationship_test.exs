defmodule Seraph.Schema.RelationshipTest do
  use ExUnit.Case, async: true

  defmodule WroteSimpleSchema do
    use Seraph.Schema.Relationship

    relationship "WROTE", cardinality: :one do
      start_node Seraph.Test.Post
      end_node Seraph.Test.User

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
             start_node: :map,
             end_node: :map,
             at: :utc_datetime,
             virtual: :boolean
           ]

    assert WroteSimpleSchema.__schema__(:persisted_properties) == [:at]
  end

  test "Enforce naming convention" do
    assert_raise ArgumentError, fn ->
      defmodule InvalidRelType do
        use Seraph.Schema.Relationship

        relationship "invalid" do
          start_node Seraph.Test.Post
          end_node Seraph.Test.User
        end
      end
    end
  end
end
