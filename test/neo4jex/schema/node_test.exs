defmodule Neo4jex.Schema.NodeTest do
  use ExUnit.Case

  alias Neo4jex.Test.Post

  defmodule SimpleSchema do
    use Neo4jex.Schema.Node

    node "SimpleSchema" do
      property :first_name, :string
      property :last_name, :string
      property :view_count, :integer, default: 1
      property :geoloc, :boolean
      property :virtual, :string, virtual: true
    end
  end

  test "schema metadata" do
    assert SimpleSchema.__schema__(:primary_label) == "SimpleSchema"

    assert SimpleSchema.__schema__(:properties) == [
             :uuid,
             :first_name,
             :last_name,
             :view_count,
             :geoloc,
             :virtual
           ]

    assert SimpleSchema.__schema__(:type, :first_name) == :string
    assert SimpleSchema.__schema__(:type, :last_name) == :string
    assert SimpleSchema.__schema__(:type, :view_count) == :integer
    assert SimpleSchema.__schema__(:type, :geoloc) == :boolean

    assert SimpleSchema.__schema__(:changeset_properties) == [
             additional_labels: {:array, :string},
             first_name: :string,
             last_name: :string,
             view_count: :integer,
             geoloc: :boolean,
             virtual: :string
           ]

    assert SimpleSchema.__schema__(:persisted_properties) == [
             :uuid,
             :first_name,
             :last_name,
             :view_count,
             :geoloc
           ]
  end

  test "defaults" do
    assert %SimpleSchema{}.first_name == nil
    assert %SimpleSchema{}.view_count == 1
  end

  defmodule InPlaceRelatedSchema do
    use Neo4jex.Schema.Node

    node "RelatedSchema" do
      property :name, :string

      outgoing_relationship "WROTE", Neo4jex.Test.Post, :posts
      outgoing_relationship "WROTE", Neo4jex.Test.Comment, :comments
      outgoing_relationship "EDIT", Neo4jex.Test.Post, :edited_posts, cardinality: :one
      incoming_relationship "FOLLOWED", Neo4jex.Test.User, :followers
    end
  end

  test "in place relationship metadata" do
    assert [
             followed: %Neo4jex.Schema.Relationship.Incoming{
               cardinality: :many,
               end_node: Neo4jex.Schema.NodeTest.InPlaceRelatedSchema,
               field: :followers,
               start_node: Neo4jex.Test.User,
               type: "FOLLOWED",
               schema: nil
             },
             edit: %Neo4jex.Schema.Relationship.Outgoing{
               cardinality: :one,
               end_node: Neo4jex.Test.Post,
               field: :edited_posts,
               start_node: Neo4jex.Schema.NodeTest.InPlaceRelatedSchema,
               type: "EDIT",
               schema: nil
             },
             wrote: %Neo4jex.Schema.Relationship.Outgoing{
               cardinality: :many,
               end_node: Neo4jex.Test.Comment,
               field: :comments,
               start_node: Neo4jex.Schema.NodeTest.InPlaceRelatedSchema,
               type: "WROTE",
               schema: nil
             },
             wrote: %Neo4jex.Schema.Relationship.Outgoing{
               cardinality: :many,
               end_node: Neo4jex.Test.Post,
               field: :posts,
               start_node: Neo4jex.Schema.NodeTest.InPlaceRelatedSchema,
               type: "WROTE",
               schema: nil
             }
           ] = InPlaceRelatedSchema.__schema__(:relationships)

    expected = [
      %Neo4jex.Schema.Relationship.Outgoing{
        cardinality: :many,
        end_node: Neo4jex.Test.Comment,
        field: :comments,
        start_node: Neo4jex.Schema.NodeTest.InPlaceRelatedSchema,
        type: "WROTE"
      },
      %Neo4jex.Schema.Relationship.Outgoing{
        cardinality: :many,
        end_node: Neo4jex.Test.Post,
        field: :posts,
        start_node: Neo4jex.Schema.NodeTest.InPlaceRelatedSchema,
        type: "WROTE"
      }
    ]

    assert expected ==
             InPlaceRelatedSchema.__schema__(:relationship, "WROTE")

    assert expected == InPlaceRelatedSchema.__schema__(:relationship, :wrote)
    assert InPlaceRelatedSchema.__schema__(:incoming_relationships) == [:followed]
    assert InPlaceRelatedSchema.__schema__(:outgoing_relationships) == [:edit, :wrote]

    struct_fields =
      %InPlaceRelatedSchema{}
      |> Map.from_struct()
      |> Map.keys()

    assert :posts in struct_fields
    assert :comments in struct_fields
    assert :edited_posts in struct_fields
    assert :followers in struct_fields
  end

  defmodule UserFollowsUser do
    use Neo4jex.Schema.Relationship

    relationship cardinality: :one do
      start_node Neo4jex.Test.User
      end_node Neo4jex.Test.User

      property :at, :utc_datetime
    end
  end

  defmodule Wrote do
    use Neo4jex.Schema.Relationship

    relationship "WROTE" do
      start_node WithSchemaRelatedSchema
      end_node Neo4jex.Test.Post

      property :at, :utc_datetime
    end
  end

  defmodule UsedMod do
    use Neo4jex.Schema.Relationship

    relationship "USED" do
      start_node Post
      end_node WithSchemaRelatedSchema

      property :at, :utc_datetime
    end
  end

  defmodule WithSchemaRelatedSchema do
    use Neo4jex.Schema.Node

    node "RelatedSchema" do
      property :name, :string

      outgoing_relationship "WROTE", Post, :posts, through: Wrote
      incoming_relationship "USED", Post, :used_posts, through: UsedMod
    end
  end

  test "with schema metadata" do
    assert [
             used: %Neo4jex.Schema.Relationship.Incoming{
               cardinality: nil,
               end_node: Neo4jex.Schema.NodeTest.WithSchemaRelatedSchema,
               field: :used_posts,
               schema: Neo4jex.Schema.NodeTest.UsedMod,
               start_node: Neo4jex.Test.Post,
               type: "USED"
             },
             wrote: %Neo4jex.Schema.Relationship.Outgoing{
               cardinality: nil,
               end_node: Neo4jex.Test.Post,
               field: :posts,
               schema: Neo4jex.Schema.NodeTest.Wrote,
               start_node: Neo4jex.Schema.NodeTest.WithSchemaRelatedSchema,
               type: "WROTE"
             }
           ] == WithSchemaRelatedSchema.__schema__(:relationships)

    assert WithSchemaRelatedSchema.__schema__(:incoming_relationships) == [:used]
    assert WithSchemaRelatedSchema.__schema__(:outgoing_relationships) == [:wrote]

    struct_fields =
      %WithSchemaRelatedSchema{}
      |> Map.from_struct()
      |> Map.keys()

    assert :posts in struct_fields
    assert :used_posts in struct_fields
  end

  describe "Error" do
    test "when duplicating fields" do
      assert_raise ArgumentError, fn ->
        defmodule DuplicatedFieldError do
          use Neo4jex.Schema.Node

          node "DuplicatedFieldError" do
            property :one, :string
            property :one, :integer
          end
        end
      end
    end

    test "when adding a relations with type same as a field name (outgoing)" do
      assert_raise ArgumentError, fn ->
        defmodule DuplicatedRelFieldByTypeOut do
          use Neo4jex.Schema.Node

          node "DuplicatedRelFieldByTypeOut" do
            property :one, :string

            outgoing_relationship "One", One, :ones
          end
        end
      end
    end

    test "when adding a relations with type same as a field name (incoming)" do
      assert_raise ArgumentError, fn ->
        defmodule DuplicatedRelFieldByTypeIn do
          use Neo4jex.Schema.Node

          node "DuplicatedRelFieldByTypeIn" do
            property :one, :string

            incoming_relationship "One", One, :ones
          end
        end
      end
    end

    test "when adding a relations with field already existing (outgoing)" do
      assert_raise ArgumentError, fn ->
        defmodule FieldAlreadyExistsOut do
          use Neo4jex.Schema.node()

          node "FieldAlreadyExistsOut" do
            property :posts, :string

            outgoing_relationship "WROTE", Post, :posts
          end
        end
      end
    end

    test "when adding a relations with field already existing (incoming)" do
      assert_raise ArgumentError, fn ->
        defmodule FieldAlreadyExistsIn do
          use Neo4jex.Schema.node()

          node "FieldAlreadyExistsIn" do
            property :posts, :string

            incoming_relationship("WROTE", Post, :posts)
          end
        end
      end
    end

    test "with relationship module: when defined type is not the same as in module" do
      assert_raise ArgumentError, fn ->
        defmodule ValidRelationship do
          use Neo4jex.Schema.Relationship

          relationship "VALIDATED" do
            start_node Start
            end_node End
            property :one, :string
          end
        end

        defmodule InvalidRelType do
          use Neo4jex.Schema.Node

          node "InvalidRelType" do
            outgoing_relationship "INVALID", Post, :invalid, through: ValidRelationship
          end
        end
      end
    end

    # test "with relationship module: when defined start node is invalid" do
    #   assert_raise ArgumentError, fn ->
    #     defmodule InvalidRelOut do
    #       use Neo4jex.Schema.Relationship

    #       relationship "INVALIDRELOUT" do
    #         start_node Other
    #         end_node EndNode
    #       end
    #     end

    #     defmodule InvalidStartNode do
    #       use Neo4jex.Schema.Node

    #       node "InvalidStartNode" do
    #         outgoing_relationship "INVALIDRELOUT", EndNode, :not_used, through: InvalidRelOut
    #       end
    #     end
    #   end
    # end

    # test "with relationship module: when defined end node is invalid" do
    #   assert_raise ArgumentError, fn ->
    #     defmodule InvalidRelIn do
    #       use Neo4jex.Schema.Relationship

    #       relationship "INVALIDRELIN" do
    #         start_node Start
    #         end_node Invalid
    #       end
    #     end

    #     defmodule InvalidEndNode do
    #       use Neo4jex.Schema.Node

    #       node "InvalidEndNode" do
    #         incoming_relationship "INVALIDRELIN", Start, :not_used, through: InvalidRelIn
    #       end
    #     end
    #   end
    # end
  end
end
