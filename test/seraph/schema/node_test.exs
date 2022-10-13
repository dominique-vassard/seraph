defmodule Seraph.Schema.NodeTest do
  use ExUnit.Case

  alias Seraph.Test.Post

  defmodule SimpleSchema do
    use Seraph.Schema.Node

    node "SimpleSchema" do
      property :firstName, :string
      property :lastName, :string
      property :address, :string
      property :address2, :string
      property :viewCount, :integer, default: 1
      property :geoloc, :boolean
      property :virtual, :string, virtual: true
    end
  end

  defmodule NumberedSchema do
    use Seraph.Schema.Node

    node "NumberedSchema2" do
    end
  end

  test "schema metadata" do
    assert SimpleSchema.__schema__(:primary_label) == "SimpleSchema"

    assert SimpleSchema.__schema__(:properties) == [
             :uuid,
             :firstName,
             :lastName,
             :address,
             :address2,
             :viewCount,
             :geoloc,
             :virtual
           ]

    assert SimpleSchema.__schema__(:type, :firstName) == :string
    assert SimpleSchema.__schema__(:type, :lastName) == :string
    assert SimpleSchema.__schema__(:type, :address) == :string
    assert SimpleSchema.__schema__(:type, :address2) == :string
    assert SimpleSchema.__schema__(:type, :viewCount) == :integer
    assert SimpleSchema.__schema__(:type, :geoloc) == :boolean

    assert SimpleSchema.__schema__(:changeset_properties) == [
             uuid: :string,
             additionalLabels: {:array, :string},
             firstName: :string,
             lastName: :string,
             address: :string,
             address2: :string,
             viewCount: :integer,
             geoloc: :boolean,
             virtual: :string
           ]

    assert SimpleSchema.__schema__(:persisted_properties) == [
             :uuid,
             :firstName,
             :lastName,
             :address,
             :address2,
             :viewCount,
             :geoloc
           ]
  end

  test "defaults" do
    assert %SimpleSchema{}.firstName == nil
    assert %SimpleSchema{}.viewCount == 1
  end

  defmodule NoPropsRels do
    import Seraph.Schema.Relationship

    defrelationship("FOLLOWS", WithSchemaRelatedSchema, Seraph.Test.Post)
  end

  defmodule Wrote do
    use Seraph.Schema.Relationship

    relationship "WROTE" do
      start_node WithSchemaRelatedSchema
      end_node Seraph.Test.Post

      property :at, :utc_datetime
    end
  end

  defmodule UsedMod do
    use Seraph.Schema.Relationship

    relationship "USED" do
      start_node Post
      end_node WithSchemaRelatedSchema

      property :at, :utc_datetime
    end
  end

  defmodule WithSchemaRelatedSchema do
    use Seraph.Schema.Node

    node "RelatedSchema" do
      property :name, :string

      outgoing_relationship "WROTE", Post, :posts, Wrote

      outgoing_relationship "FOLLOWS",
                            Post,
                            :followed_posts,
                            NoPropsRels.WithSchemaRelatedSchemaToPost.Follows

      incoming_relationship "USED", Post, :used_posts, UsedMod
    end
  end

  test "with schema metadata" do
    assert [
             wrote: %Seraph.Schema.Relationship.Outgoing{
               direction: :outgoing,
               cardinality: :many,
               end_node: Seraph.Test.Post,
               field: :posts,
               schema: Seraph.Schema.NodeTest.Wrote,
               start_node: Seraph.Schema.NodeTest.WithSchemaRelatedSchema,
               type: "WROTE"
             },
             follows: %Seraph.Schema.Relationship.Outgoing{
               direction: :outgoing,
               cardinality: :many,
               end_node: Seraph.Test.Post,
               field: :followed_posts,
               schema: Seraph.Schema.NodeTest.NoPropsRels.WithSchemaRelatedSchemaToPost.Follows,
               start_node: Seraph.Schema.NodeTest.WithSchemaRelatedSchema,
               type: "FOLLOWS"
             },
             used: %Seraph.Schema.Relationship.Incoming{
               direction: :incoming,
               cardinality: :many,
               end_node: Seraph.Schema.NodeTest.WithSchemaRelatedSchema,
               field: :used_posts,
               schema: Seraph.Schema.NodeTest.UsedMod,
               start_node: Seraph.Test.Post,
               type: "USED"
             }
           ] == WithSchemaRelatedSchema.__schema__(:relationships)

    assert WithSchemaRelatedSchema.__schema__(:incoming_relationships) == [:used]
    assert WithSchemaRelatedSchema.__schema__(:outgoing_relationships) == [:follows, :wrote]

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
          use Seraph.Schema.Node

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
          use Seraph.Schema.Node

          node "DuplicatedRelFieldByTypeOut" do
            property :one, :string

            outgoing_relationship "One", One, :ones, Seraph.Test.UserToPost.Wrote
          end
        end
      end
    end

    test "when adding a relations with type same as a field name (incoming)" do
      assert_raise ArgumentError, fn ->
        defmodule DuplicatedRelFieldByTypeIn do
          use Seraph.Schema.Node

          node "DuplicatedRelFieldByTypeIn" do
            property :one, :string

            incoming_relationship "One", One, :ones, Seraph.Test.UserToPost.Wrote
          end
        end
      end
    end

    test "when adding a relations with field already existing (outgoing)" do
      assert_raise ArgumentError, fn ->
        defmodule FieldAlreadyExistsOut do
          use Seraph.Schema.node()

          node "FieldAlreadyExistsOut" do
            property :posts, :string

            outgoing_relationship "WROTE", Post, :posts, Seraph.Test.UserToPost.Wrote
          end
        end
      end
    end

    test "when adding a relations with field already existing (incoming)" do
      assert_raise ArgumentError, fn ->
        defmodule FieldAlreadyExistsIn do
          use Seraph.Schema.node()

          node "FieldAlreadyExistsIn" do
            property :posts, :string

            incoming_relationship "WROTE", Post, :posts, Seraph.Test.UserToPost.Wrote
          end
        end
      end
    end

    test "with relationship module: when defined type is not the same as in module" do
      assert_raise ArgumentError, fn ->
        defmodule ValidRelationship do
          use Seraph.Schema.Relationship

          relationship "VALIDATED" do
            start_node Start
            end_node End
            property :one, :string
          end
        end

        defmodule InvalidRelType do
          use Seraph.Schema.Node

          node "InvalidRelType" do
            outgoing_relationship "INVALID", Post, :invalid2, through: ValidRelationship
          end
        end
      end
    end

    # test "with relationship module: when defined start node is invalid" do
    #   assert_raise ArgumentError, fn ->
    #     defmodule InvalidRelOut do
    #       use Seraph.Schema.Relationship

    #       relationship "INVALIDRELOUT" do
    #         start_node Other
    #         end_node EndNode
    #       end
    #     end

    #     defmodule InvalidStartNode do
    #       use Seraph.Schema.Node

    #       node "InvalidStartNode" do
    #         outgoing_relationship "INVALIDRELOUT", EndNode, :not_used, through: InvalidRelOut
    #       end
    #     end
    #   end
    # end

    # test "with relationship module: when defined end node is invalid" do
    #   assert_raise ArgumentError, fn ->
    #     defmodule InvalidRelIn do
    #       use Seraph.Schema.Relationship

    #       relationship "INVALIDRELIN" do
    #         start_node Start
    #         end_node Invalid
    #       end
    #     end

    #     defmodule InvalidEndNode do
    #       use Seraph.Schema.Node

    #       node "InvalidEndNode" do
    #         incoming_relationship "INVALIDRELIN", Start, :not_used, through: InvalidRelIn
    #       end
    #     end
    #   end
    # end
  end

  test ":id property is not valid" do
    assert_raise ArgumentError, fn ->
      defmodule InvalidProp do
        use Seraph.Schema.Node

        node "Invalid" do
          property :id, :integer
        end
      end
    end
  end

  test ":id identifier is not valid" do
    assert_raise ArgumentError, fn ->
      defmodule InvalidProp do
        use Seraph.Schema.Node

        @identifier {:id, :integer, []}

        node "Invalid" do
        end
      end
    end
  end

  describe "Naming convention enforcement" do
    test "Invalid node name" do
      assert_raise ArgumentError, fn ->
        defmodule WrongNodeName do
          use Seraph.Schema.Node

          node "invalid_label" do
            property :name, :string
          end
        end
      end

      assert_raise ArgumentError, fn ->
        defmodule WrongNodeName do
          use Seraph.Schema.Node

          node "INVALIDLABEL" do
            property :name, :string
          end
        end
      end
    end

    test "invalid property name" do
      assert_raise ArgumentError, fn ->
        defmodule WrongProperyName do
          use Seraph.Schema.Node

          node "WrongProperyName" do
            property :invalid_name, :string
          end
        end
      end
    end

    test "invalid relationship type" do
      assert_raise ArgumentError, fn ->
        defmodule WrongRelName do
          use Seraph.Schema.Node

          node "WrongRelName" do
            outgoing_relationship(
              "wrongType",
              Post,
              :invalid_rel,
              Seraph.Test.NoPropsRels.UserToUser.Follows
            )
          end
        end
      end
    end
  end
end
