defmodule Seraph.Query.Builder.EntityTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Entity

  describe "build_properties/3" do
    test "ok: all data" do
      properties = %{
        uuid: "uuid-1",
        firstName: "John"
      }

      assert [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "n",
                 entity_queryable: Seraph.Node,
                 name: :uuid,
                 type: nil,
                 value: "uuid-1"
               },
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "n",
                 entity_queryable: Seraph.Node,
                 name: :firstName,
                 type: nil,
                 value: "John"
               }
             ] = Entity.build_properties(Seraph.Node, "n", properties)
    end

    test "ok: with nil identifier" do
      properties = %{
        uuid: "uuid-1",
        firstName: "John"
      }

      assert [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: nil,
                 entity_queryable: Seraph.Node,
                 name: :uuid,
                 type: nil,
                 value: "uuid-1"
               },
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: nil,
                 entity_queryable: Seraph.Node,
                 name: :firstName,
                 type: nil,
                 value: "John"
               }
             ] = Entity.build_properties(Seraph.Node, nil, properties)
    end

    test "ok: with empty properties" do
      assert [] == Entity.build_properties(Seraph.Node, "n", %{})
    end

    test "ok with quoted values" do
      properties = [at: {:^, [], [{:date, [], Seraph.Query.Builder.Entity.RelationshipTest}]}]

      assert [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "n",
                 entity_queryable: Seraph.Node,
                 name: :at,
                 type: nil,
                 value: {:date, [], Seraph.Query.Builder.Entity.RelationshipTest}
               }
             ] = Entity.build_properties(Seraph.Node, "n", properties)
    end
  end

  describe "extract_params/2" do
    test "ok: Node, no current params" do
      entity = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: nil,
            entity_identifier: "u",
            entity_queryable: Seraph.Node,
            name: :uuid,
            type: nil,
            value: "uuid-1"
          }
        ],
        queryable: Seraph.Node
      }

      assert %{
               entity: %Seraph.Query.Builder.Entity.Node{
                 alias: nil,
                 identifier: "u",
                 labels: [],
                 properties: [
                   %Seraph.Query.Builder.Entity.Property{
                     alias: nil,
                     bound_name: "u_uuid_0",
                     entity_identifier: "u",
                     entity_queryable: Seraph.Node,
                     name: :uuid,
                     type: nil,
                     value: nil
                   }
                 ],
                 queryable: Seraph.Node
               },
               params: [u_uuid_0: "uuid-1"]
             } = Entity.extract_params(entity, [], "match__")
    end

    test "ok: Node with pinned data, no current params" do
      entity = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: nil,
            entity_identifier: "u",
            entity_queryable: Seraph.Node,
            name: :uuid,
            type: nil,
            value: {:user_uuid, [], Seraph.Query.Builder.Entity.NodeTest}
          }
        ],
        queryable: Seraph.Node
      }

      assert %{
               entity: %Seraph.Query.Builder.Entity.Node{
                 alias: nil,
                 identifier: "u",
                 labels: [],
                 properties: [
                   %Seraph.Query.Builder.Entity.Property{
                     alias: nil,
                     bound_name: "user_uuid",
                     entity_identifier: "u",
                     entity_queryable: Seraph.Node,
                     name: :uuid,
                     type: nil,
                     value: nil
                   }
                 ],
                 queryable: Seraph.Node
               },
               params: [user_uuid: {:user_uuid, [], Seraph.Query.Builder.Entity.NodeTest}]
             } = Entity.extract_params(entity, [], "match__")
    end

    test "ok: Node, current params" do
      entity = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: nil,
            entity_identifier: "u",
            entity_queryable: Seraph.Node,
            name: :uuid,
            type: nil,
            value: "uuid-1"
          }
        ],
        queryable: Seraph.Node
      }

      assert %{
               entity: %Seraph.Query.Builder.Entity.Node{
                 alias: nil,
                 identifier: "u",
                 labels: [],
                 properties: [
                   %Seraph.Query.Builder.Entity.Property{
                     alias: nil,
                     bound_name: "u_uuid_0",
                     entity_identifier: "u",
                     entity_queryable: Seraph.Node,
                     name: :uuid,
                     type: nil,
                     value: nil
                   }
                 ],
                 queryable: Seraph.Node
               },
               params: [u_uuid_0: "uuid-1", existing: 1]
             } = Entity.extract_params(entity, [existing: 1], "match__")
    end

    test "ok: Node, duplicated param name (direct data - new data added)" do
      entity = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: nil,
            entity_identifier: "u",
            entity_queryable: Seraph.Node,
            name: :uuid,
            type: nil,
            value: "uuid-1"
          }
        ],
        queryable: Seraph.Node
      }

      assert %{
               entity: %Seraph.Query.Builder.Entity.Node{
                 alias: nil,
                 identifier: "u",
                 labels: [],
                 properties: [
                   %Seraph.Query.Builder.Entity.Property{
                     alias: nil,
                     bound_name: "u_uuid_1",
                     entity_identifier: "u",
                     entity_queryable: Seraph.Node,
                     name: :uuid,
                     type: nil,
                     value: nil
                   }
                 ],
                 queryable: Seraph.Node
               },
               params: [u_uuid_1: "uuid-1", u_uuid_0: "first-uuid"]
             } = Entity.extract_params(entity, [u_uuid_0: "first-uuid"], "match__")
    end

    test "ok: Node, duplicated param name (pinned data - old data replaced)" do
      entity = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: nil,
            entity_identifier: "u",
            entity_queryable: Seraph.Node,
            name: :uuid,
            type: nil,
            value: {:user_uuid, [], Seraph.Query.Builder.Entity.NodeTest}
          }
        ],
        queryable: Seraph.Node
      }

      assert %{
               entity: %Seraph.Query.Builder.Entity.Node{
                 alias: nil,
                 identifier: "u",
                 labels: [],
                 properties: [
                   %Seraph.Query.Builder.Entity.Property{
                     alias: nil,
                     bound_name: "user_uuid",
                     entity_identifier: "u",
                     entity_queryable: Seraph.Node,
                     name: :uuid,
                     type: nil,
                     value: nil
                   }
                 ],
                 queryable: Seraph.Node
               },
               params: [user_uuid: {:user_uuid, [], Seraph.Query.Builder.Entity.NodeTest}]
             } = Entity.extract_params(entity, [user_uuid: "again"], "match__")
    end

    test "ok: relationship, no current params" do
      entity = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: "p",
          labels: ["Post"],
          properties: [
            %Seraph.Query.Builder.Entity.Property{
              alias: nil,
              bound_name: nil,
              entity_identifier: "p",
              entity_queryable: Seraph.Test.Post,
              name: :title,
              type: nil,
              value: "Great title"
            }
          ],
          queryable: Seraph.Test.Post
        },
        identifier: nil,
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: nil,
            entity_identifier: nil,
            entity_queryable: Seraph.Relationship,
            name: :at,
            type: nil,
            value: {:date, [], Seraph.Query.Builder.Entity.RelationshipTest}
          }
        ],
        queryable: Seraph.Relationship,
        start: %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: "u",
          labels: [],
          properties: [
            %Seraph.Query.Builder.Entity.Property{
              alias: nil,
              bound_name: nil,
              entity_identifier: "u",
              entity_queryable: Seraph.Test.User,
              name: :uuid,
              type: nil,
              value: {:user_uuid, [], Seraph.Query.Builder.Entity.NodeTest}
            }
          ],
          queryable: Seraph.Test.User
        },
        type: "WROTE"
      }

      assert %{
               entity: %Seraph.Query.Builder.Entity.Relationship{
                 alias: nil,
                 end: %Seraph.Query.Builder.Entity.Node{
                   alias: nil,
                   identifier: "p",
                   labels: ["Post"],
                   properties: [
                     %Seraph.Query.Builder.Entity.Property{
                       alias: nil,
                       bound_name: "p_title_0",
                       entity_identifier: "p",
                       entity_queryable: Seraph.Test.Post,
                       name: :title,
                       type: nil,
                       value: nil
                     }
                   ],
                   queryable: Seraph.Test.Post
                 },
                 identifier: nil,
                 properties: [
                   %Seraph.Query.Builder.Entity.Property{
                     alias: nil,
                     bound_name: "date",
                     entity_identifier: nil,
                     entity_queryable: Seraph.Relationship,
                     name: :at,
                     type: nil,
                     value: nil
                   }
                 ],
                 queryable: Seraph.Relationship,
                 start: %Seraph.Query.Builder.Entity.Node{
                   alias: nil,
                   identifier: "u",
                   labels: [],
                   properties: [
                     %Seraph.Query.Builder.Entity.Property{
                       alias: nil,
                       bound_name: "user_uuid",
                       entity_identifier: "u",
                       entity_queryable: Seraph.Test.User,
                       name: :uuid,
                       type: nil,
                       value: nil
                     }
                   ],
                   queryable: Seraph.Test.User
                 },
                 type: "WROTE"
               },
               params: [
                 date: {:date, [], Seraph.Query.Builder.Entity.RelationshipTest},
                 p_title_0: "Great title",
                 user_uuid: {:user_uuid, [], Seraph.Query.Builder.Entity.NodeTest}
               ]
             } = Entity.extract_params(entity, [], "match__")
    end
  end
end
