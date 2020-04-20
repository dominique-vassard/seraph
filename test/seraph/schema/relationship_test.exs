defmodule Seraph.Schema.RelationshipTest do
  use ExUnit.Case, async: true

  defmodule WroteSimpleSchema do
    use Seraph.Schema.Relationship

    @cardinality [outgoing: :one]

    relationship "WROTE" do
      start_node Seraph.Test.Post
      end_node Seraph.Test.User

      property :at, :utc_datetime
      property :virtual, :boolean, virtual: true
    end
  end

  defmodule NoPropsRelationships do
    import Seraph.Schema.Relationship

    defrelationship("READ", Seraph.Test.User, Seraph.Test.Post)
    defrelationship("FOLLOWS", Seraph.Test.User, Seraph.Test.User, cardinality: [incoming: :one])

    defrelationship("EDITED_BY", Seraph.Test.Post, Seraph.Test.User,
      cardinality: [outgoing: :one, incoming: :one]
    )
  end

  test "schema metadata" do
    assert WroteSimpleSchema.__schema__(:type) == "WROTE"
    assert WroteSimpleSchema.__schema__(:cardinality) == [incoming: :many, outgoing: :one]

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

  describe "defrelationship/4" do
    test "ok: no opts" do
      assert NoPropsRelationships.UserToPost.Read.__schema__(:type) == "READ"

      assert NoPropsRelationships.UserToPost.Read.__schema__(:cardinality) == [
               outgoing: :many,
               incoming: :many
             ]

      assert NoPropsRelationships.UserToPost.Read.__schema__(:properties) == []

      assert NoPropsRelationships.UserToPost.Read.__schema__(:changeset_properties) == [
               start_node: :map,
               end_node: :map
             ]

      assert NoPropsRelationships.UserToPost.Read.__schema__(:persisted_properties) == []
    end

    test "ok: with :cardinality" do
      assert NoPropsRelationships.UserToUser.Follows.__schema__(:type) == "FOLLOWS"

      assert NoPropsRelationships.UserToUser.Follows.__schema__(:cardinality) == [
               outgoing: :many,
               incoming: :one
             ]

      assert NoPropsRelationships.UserToUser.Follows.__schema__(:properties) == []

      assert NoPropsRelationships.UserToUser.Follows.__schema__(:changeset_properties) == [
               start_node: :map,
               end_node: :map
             ]

      assert NoPropsRelationships.UserToUser.Follows.__schema__(:persisted_properties) == []
    end

    test "ok: module name with _" do
      assert NoPropsRelationships.PostToUser.EditedBy.__schema__(:type) == "EDITED_BY"
    end

    test "ok: has changeset function" do
      assert %Seraph.Changeset{valid?: false} =
               %NoPropsRelationships.PostToUser.EditedBy{}
               |> NoPropsRelationships.PostToUser.EditedBy.changeset(%{start_node: :invalid})
    end
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
