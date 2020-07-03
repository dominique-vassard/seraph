defmodule Seraph.Query.Builder.RemoveTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Remove

  describe "build/2" do
    test "{u, OldLabel}" do
      ast = quote do: [{u, OldLabel}]

      assert %Remove{expressions: expressions} = Remove.build(ast, __ENV__)

      assert expressions = [
               %Seraph.Query.Builder.Entity.Label{
                 node_identifier: "u",
                 values: ["OldLabel"]
               }
             ]
    end

    test "{u, [OldLabel1, OldLabel2]}" do
      ast = quote do: [{u, [OldLabel1, OldLabel2]}]

      assert %Remove{expressions: expressions} = Remove.build(ast, __ENV__)

      assert expressions = [
               %Seraph.Query.Builder.Entity.Label{
                 node_identifier: "u",
                 values: ["OldLabel1", "OldLabel2"]
               }
             ]
    end

    test "u.firstName" do
      ast = quote do: [u.firstName]
      assert %Remove{expressions: expressions} = Remove.build(ast, __ENV__)

      assert expressions = [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "u",
                 entity_queryable: nil,
                 name: :firstName,
                 type: nil,
                 value: nil
               }
             ]
    end
  end

  describe "check/2" do
    test "ok" do
      ast = quote do: [{u, OldLabel}, u.firstName]

      remove = Remove.build(ast, __ENV__)

      assert :ok = Remove.check(remove, query_fixtures())
    end

    test "fails: Property - unknown entity identifier" do
      ast = quote do: [{p, OldLabel}]
      remove = Remove.build(ast, __ENV__)

      assert {:error, error} = Remove.check(remove, query_fixtures())
      assert error =~ "[Remove] Entity with identifier"

      ast = quote do: [p.firstName]
      remove = Remove.build(ast, __ENV__)

      assert {:error, error} = Remove.check(remove, query_fixtures())
      assert error =~ "[Remove] Entity with identifier"
    end

    test "fails: Property - unknown property" do
      ast = quote do: [u.unknown]

      remove = Remove.build(ast, __ENV__)

      assert {:error, error} = Remove.check(remove, query_fixtures())
      assert error =~ "Property"
    end

    test "fails: Try to remove primary label" do
      ast = quote do: [{u, User}]

      remove = Remove.build(ast, __ENV__)

      assert {:error, error} = Remove.check(remove, query_fixtures())
      assert error =~ "[Remove] Removing primary label"
    end

    test "fails: Try to remove identifier" do
      ast = quote do: [u.uuid]

      remove = Remove.build(ast, __ENV__)

      assert {:error, error} = Remove.check(remove, query_fixtures())
      assert error =~ "[Remove] Identifier key"
    end

    test "fails: Try to remove merge keys" do
      ast = quote do: [mk.mkField2]

      remove = Remove.build(ast, __ENV__)

      assert {:error, error} = Remove.check(remove, query_fixtures())
      assert error =~ "[Remove] Merge key"
    end

    test "fails: Try to remove relationship type" do
      ast = quote do: [{rel, Type}]

      remove = Remove.build(ast, __ENV__)

      assert {:error, error} = Remove.check(remove, query_fixtures())
      assert error =~ "[Remove] Removing relationship type"
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
      params: []
    }
  end
end
