defmodule Seraph.Query.Builder.DeleteTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Delete

  describe "build/2" do
    test "u, rel" do
      ast = quote do: [u, rel]

      assert %Delete{raw_entities: raw_entities} = Delete.build(ast, __ENV__)

      assert [
               %Seraph.Query.Builder.Entity.EntityData{
                 entity_identifier: "u"
               },
               %Seraph.Query.Builder.Entity.EntityData{
                 entity_identifier: "rel"
               }
             ] = raw_entities
    end
  end

  describe "prepare/3" do
    test "ok" do
      ast = quote do: [u, rel]

      raw_delete = Delete.build(ast, __ENV__)

      assert %Delete{entities: entities, raw_entities: nil} =
               Delete.prepare(raw_delete, query_fixtures(), [])

      assert [
               %Seraph.Query.Builder.Entity.Node{
                 alias: nil,
                 identifier: "u",
                 labels: ["User"],
                 properties: [],
                 queryable: Seraph.Test.User
               },
               %Seraph.Query.Builder.Entity.Relationship{
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
               }
             ] = entities
    end
  end

  describe "check/2" do
    test "ok" do
      ast = quote do: [u, rel]

      raw_delete = Delete.build(ast, __ENV__)

      assert :ok = Delete.check(raw_delete, query_fixtures())
    end

    test "fails: unknown identifier" do
      ast = quote do: [unknown]

      raw_delete = Delete.build(ast, __ENV__)

      assert {:error, error} = Delete.check(raw_delete, query_fixtures())
      assert error =~ "[Delete] Entity with identifier"
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
