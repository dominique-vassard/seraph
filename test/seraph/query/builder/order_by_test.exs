defmodule Seraph.Query.Builder.OrderByTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.OrderBy

  describe "build/2" do
    test "[u]" do
      ast = quote do: [u]

      assert %Seraph.Query.Builder.OrderBy{
               orders: nil,
               raw_orders: raw_orders
             } = OrderBy.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.EntityData{
                   entity_identifier: "u"
                 },
                 order: :asc
               }
             ] = raw_orders
    end

    test "[u, rel]" do
      ast = quote do: [u, rel]

      assert %Seraph.Query.Builder.OrderBy{
               orders: nil,
               raw_orders: raw_orders
             } = OrderBy.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.EntityData{
                   entity_identifier: "u"
                 },
                 order: :asc
               },
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.EntityData{
                   entity_identifier: "rel"
                 },
                 order: :asc
               }
             ] = raw_orders
    end

    test "[u.firstName, u.lastName]" do
      ast = quote do: [u.firstName, u.lastName]

      assert %Seraph.Query.Builder.OrderBy{
               orders: nil,
               raw_orders: raw_orders
             } = OrderBy.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.EntityData{
                   entity_identifier: "u",
                   property: :firstName
                 },
                 order: :asc
               },
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.EntityData{
                   entity_identifier: "u",
                   property: :lastName
                 },
                 order: :asc
               }
             ] = raw_orders
    end

    test "[asc: u.firstName, desc: rel.at]" do
      ast = quote do: [asc: u.firstName, desc: rel.at]

      assert %Seraph.Query.Builder.OrderBy{
               orders: nil,
               raw_orders: raw_orders
             } = OrderBy.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.EntityData{
                   alias: nil,
                   entity_identifier: "u",
                   property: :firstName
                 },
                 order: :asc
               },
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.EntityData{
                   alias: nil,
                   entity_identifier: "rel",
                   property: :at
                 },
                 order: :asc
               }
             ] = raw_orders
    end
  end

  describe "check/2" do
    test "ok " do
      ast = quote do: [asc: u.firstName, desc: rel.at]
      order_by = OrderBy.build(ast, __ENV__)
      assert :ok = OrderBy.check(order_by, query_fixtures())
    end

    test "ok with alias" do
      ast = quote do: [desc: simple_val]
      order_by = OrderBy.build(ast, __ENV__)
      assert :ok = OrderBy.check(order_by, query_fixtures())
    end

    test "fails: unknown identifier or alias" do
      ast = quote do: [unknown]
      order_by = OrderBy.build(ast, __ENV__)
      assert {:error, error} = OrderBy.check(order_by, query_fixtures())
      assert error =~ "[OrderBy]"
    end

    test "fails: unknown property" do
      ast = quote do: [u.unknown]
      order_by = OrderBy.build(ast, __ENV__)
      assert {:error, error} = OrderBy.check(order_by, query_fixtures())
      assert error =~ "Property"
    end
  end

  describe "prepare/3" do
    test "ok" do
      ast = quote do: [u, rel]
      raw_order_by = OrderBy.build(ast, __ENV__)

      assert %OrderBy{orders: orders, raw_orders: nil} =
               OrderBy.prepare(raw_order_by, query_fixtures(), [])

      assert [
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.Node{
                   alias: nil,
                   identifier: "u",
                   labels: ["User"],
                   properties: [],
                   queryable: Seraph.Test.User
                 },
                 order: :asc
               },
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.Relationship{
                   alias: nil,
                   end: %Seraph.Query.Builder.Entity.Node{
                     alias: nil,
                     identifier: nil,
                     labels: ["Post"],
                     properties: [],
                     queryable: Seraph.Test.Post
                   },
                   identifier: "rel",
                   properties: [],
                   queryable: Seraph.Relationship,
                   start: %Seraph.Query.Builder.Entity.Node{
                     alias: nil,
                     identifier: "u",
                     labels: ["User"],
                     properties: [],
                     queryable: Seraph.Test.User
                   },
                   type: nil
                 },
                 order: :asc
               }
             ] = orders
    end

    test "ok with properties" do
      ast = quote do: [asc: u.lastName, desc: u.firstName]
      raw_order_by = OrderBy.build(ast, __ENV__)

      assert %OrderBy{orders: orders, raw_orders: nil} =
               OrderBy.prepare(raw_order_by, query_fixtures(), [])

      assert [
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.Property{
                   alias: nil,
                   bound_name: nil,
                   entity_identifier: "u",
                   entity_queryable: Seraph.Test.User,
                   name: :lastName,
                   type: nil,
                   value: nil
                 },
                 order: :asc
               },
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.Property{
                   alias: nil,
                   bound_name: nil,
                   entity_identifier: "u",
                   entity_queryable: Seraph.Test.User,
                   name: :firstName,
                   type: nil,
                   value: nil
                 },
                 order: :asc
               }
             ] = orders
    end

    test "ok with value and alias" do
      ast = quote do: [first_name, simple_val]
      raw_order_by = OrderBy.build(ast, __ENV__)

      assert %OrderBy{orders: orders, raw_orders: nil} =
               OrderBy.prepare(raw_order_by, query_fixtures(), [])

      assert [
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.Property{
                   alias: :first_name,
                   bound_name: nil,
                   entity_identifier: "u",
                   entity_queryable: Seraph.Test.User,
                   name: :firstName,
                   type: nil,
                   value: nil
                 },
                 order: :asc
               },
               %Seraph.Query.Builder.Entity.Order{
                 entity: %Seraph.Query.Builder.Entity.Value{
                   alias: :simple_val,
                   bound_name: "return__0",
                   value: nil
                 },
                 order: :asc
               }
             ] = orders
    end
  end

  defp query_fixtures() do
    %Seraph.Query{
      identifiers: %{
        "rel" => %Seraph.Query.Builder.Entity.Relationship{
          alias: nil,
          end: %Seraph.Query.Builder.Entity.Node{
            alias: nil,
            identifier: nil,
            labels: ["Post"],
            properties: [],
            queryable: Seraph.Test.Post
          },
          identifier: "rel",
          properties: [],
          queryable: Seraph.Relationship,
          start: %Seraph.Query.Builder.Entity.Node{
            alias: nil,
            identifier: "u",
            labels: ["User"],
            properties: [],
            queryable: Seraph.Test.User
          },
          type: nil
        },
        "u" => %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: "u",
          labels: ["User"],
          properties: [],
          queryable: Seraph.Test.User
        },
        "mk" => %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: "mk",
          labels: ["MergeKeys"],
          properties: [],
          queryable: Seraph.Test.MergeKeys
        }
      },
      operations: [
        match: %Seraph.Query.Builder.Match{},
        return: %Seraph.Query.Builder.Return{
          raw_variables: [
            %Seraph.Query.Builder.Entity.Value{
              alias: :simple_val,
              value: 4
            },
            %Seraph.Query.Builder.Entity.EntityData{
              alias: :first_name,
              entity_identifier: "u",
              property: :firstName
            }
          ],
          variables: %{
            "first_name" => %Seraph.Query.Builder.Entity.Property{
              alias: :first_name,
              bound_name: nil,
              entity_identifier: "u",
              entity_queryable: Seraph.Test.User,
              name: :firstName,
              type: nil,
              value: nil
            },
            "simple_val" => %Seraph.Query.Builder.Entity.Value{
              alias: :simple_val,
              bound_name: "return__0",
              value: nil
            },
            "u" => %Seraph.Query.Builder.Entity.Node{
              alias: nil,
              identifier: "u",
              labels: ["User"],
              properties: [],
              queryable: Seraph.Test.User
            }
          }
        }
      ],
      params: []
    }
  end
end
