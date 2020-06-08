defmodule Seraph.Query.Builder.OnCreateSetTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.OnCreateSet

  describe "build/2" do
    test "u.firstName = \"Jack\"" do
      ast = quote do: [u.firstName = "Jack"]

      %{on_create_set: %OnCreateSet{expressions: expressions}, params: params} =
        OnCreateSet.build(ast, __ENV__)

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

      %{on_create_set: %OnCreateSet{expressions: expressions}, params: params} =
        OnCreateSet.build(ast, __ENV__)

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

      assert [ln: {:ln, [], Seraph.Query.Builder.OnCreateSetTest}] == params
    end

    test "{u, NewLabel}" do
      ast = quote do: [{u, NewLabel}]

      %{on_create_set: %OnCreateSet{expressions: expressions}, params: params} =
        OnCreateSet.build(ast, __ENV__)

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

      %{on_create_set: %OnCreateSet{expressions: expressions}, params: params} =
        OnCreateSet.build(ast, __ENV__)

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

      %{on_create_set: %OnCreateSet{expressions: expressions}, params: params} =
        OnCreateSet.build(ast, __ENV__)

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

    # {u, nil},
  end

  describe "check/2" do
    test "ok" do
      ast = quote do: [u.firstName = "Jack"]

      %{on_create_set: on_create_set, params: params} = OnCreateSet.build(ast, __ENV__)

      assert :ok = OnCreateSet.check(on_create_set, query_fixtures(params))
    end

    test "fails: Property - unknown entity identifier" do
      ast = quote do: [unknwown.firstName = "Jack"]

      %{on_create_set: on_create_set, params: params} = OnCreateSet.build(ast, __ENV__)

      assert {:error, message} = OnCreateSet.check(on_create_set, query_fixtures(params))
      assert String.starts_with?(message, "[OnCreateSet] Entity with identifier")
    end

    test "fails: Property - unknown property" do
      ast = quote do: [u.unknown = "Jack"]

      %{on_create_set: on_create_set, params: params} = OnCreateSet.build(ast, __ENV__)

      assert {:error, message} = OnCreateSet.check(on_create_set, query_fixtures(params))
      assert String.starts_with?(message, "Property")
    end

    test "fails: Property - wrong value type" do
      ast = quote do: [u.firstName = :invalid]

      %{on_create_set: on_create_set, params: params} = OnCreateSet.build(ast, __ENV__)

      assert {:error, message} = OnCreateSet.check(on_create_set, query_fixtures(params))
      assert String.starts_with?(message, "Value")
    end

    test "fails: Function on unknown identifier" do
      ast = quote do: [u.viewCount = unknown.viewCount + 1]

      %{on_create_set: on_create_set, params: params} = OnCreateSet.build(ast, __ENV__)

      assert {:error, message} = OnCreateSet.check(on_create_set, query_fixtures(params))
      assert String.starts_with?(message, "[OnCreateSet] Entity with identifier")
    end

    test "fails: Function on unknown property" do
      ast = quote do: [u.viewCount = u.unknown + 1]

      %{on_create_set: on_create_set, params: params} = OnCreateSet.build(ast, __ENV__)

      assert {:error, message} = OnCreateSet.check(on_create_set, query_fixtures(params))
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
