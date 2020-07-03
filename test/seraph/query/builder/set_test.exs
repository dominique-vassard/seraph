defmodule Seraph.Query.Builder.SetTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Set

  describe "build/2" do
    test "u.firstName = \"Jack\"" do
      ast = quote do: [u.firstName = "Jack"]

      %{set: %Set{expressions: expressions}, params: params} = Set.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: "u_firstName_0",
                 entity_identifier: "u",
                 entity_queryable: nil,
                 name: :firstName,
                 type: nil,
                 value: nil
               }
             ] == expressions

      assert [u_firstName_0: "Jack"] == params
    end

    test "u.lastName = ^ln" do
      ast = quote do: [u.lastName = ^ln]

      %{set: %Set{expressions: expressions}, params: params} = Set.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: "ln",
                 entity_identifier: "u",
                 entity_queryable: nil,
                 name: :lastName,
                 type: nil,
                 value: nil
               }
             ] == expressions

      assert [ln: {:ln, [], Seraph.Query.Builder.SetTest}] == params
    end

    test "{u, NewLabel}" do
      ast = quote do: [{u, NewLabel}]

      %{set: %Set{expressions: expressions}, params: params} = Set.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Label{
                 node_identifier: "u",
                 values: ["NewLabel"]
               }
             ] == expressions

      assert [] == params
    end

    test "{u, [Buyer, Recurrent]}" do
      ast = quote do: [{u, [Buyer, Recurrent]}]

      %{set: %Set{expressions: expressions}, params: params} = Set.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Label{
                 node_identifier: "u",
                 values: ["Buyer", "Recurrent"]
               }
             ] == expressions

      assert [] == params
    end

    test "u.viewCount = u.viewCount + 1" do
      ast = quote do: [u.viewCount = u.viewCount + 1]

      %{set: %Set{expressions: expressions}, params: params} = Set.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "u",
                 entity_queryable: nil,
                 name: :viewCount,
                 type: nil,
                 value: %Seraph.Query.Builder.Entity.Function{
                   alias: nil,
                   args: [
                     %Seraph.Query.Builder.Entity.EntityData{
                       alias: nil,
                       entity_identifier: "u",
                       property: :viewCount
                     },
                     1
                   ],
                   infix?: true,
                   name: :+
                 }
               }
             ] == expressions

      assert [] == params
    end

    test "u.viewCount = id(u)" do
      ast = quote do: [u.viewCount = id(u)]

      %{set: %Set{expressions: expressions}, params: params} = Set.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "u",
                 entity_queryable: nil,
                 name: :viewCount,
                 type: nil,
                 value: %Seraph.Query.Builder.Entity.Function{
                   alias: nil,
                   args: [
                     %Seraph.Query.Builder.Entity.EntityData{
                       alias: nil,
                       entity_identifier: "u",
                       property: nil
                     }
                   ],
                   infix?: false,
                   name: :id
                 }
               }
             ] == expressions

      assert [] == params
    end

    # {u, nil},
  end

  describe "check/2" do
    test "ok" do
      ast = quote do: [u.firstName = "Jack", u.viewCount = id(u)]

      %{set: set, params: params} = Set.build(ast, __ENV__)

      assert :ok = Set.check(set, query_fixtures(params))
    end

    test "fails: Property - unknown entity identifier" do
      ast = quote do: [unknwown.firstName = "Jack"]

      %{set: set, params: params} = Set.build(ast, __ENV__)

      assert {:error, message} = Set.check(set, query_fixtures(params))
      assert String.starts_with?(message, "[Set] Entity with identifier")
    end

    test "fails: Property - unknown property" do
      ast = quote do: [u.unknown = "Jack"]

      %{set: set, params: params} = Set.build(ast, __ENV__)

      assert {:error, message} = Set.check(set, query_fixtures(params))
      assert String.starts_with?(message, "Property")
    end

    test "fails: Property - wrong value type" do
      ast = quote do: [u.firstName = :invalid]

      %{set: set, params: params} = Set.build(ast, __ENV__)

      assert {:error, message} = Set.check(set, query_fixtures(params))
      assert String.starts_with?(message, "Value")
    end

    test "fails: Function on unknown identifier" do
      ast = quote do: [u.viewCount = unknown.viewCount + 1]

      %{set: set, params: params} = Set.build(ast, __ENV__)

      assert {:error, message} = Set.check(set, query_fixtures(params))
      assert String.starts_with?(message, "[Set] Entity with identifier")
    end

    test "fails: Function on unknown property" do
      ast = quote do: [u.viewCount = u.unknown + 1]

      %{set: set, params: params} = Set.build(ast, __ENV__)

      assert {:error, message} = Set.check(set, query_fixtures(params))
      assert String.starts_with?(message, "Property")
    end
  end

  defp query_fixtures(params) do
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
        }
      },
      params: params
    }
  end
end
