defmodule Seraph.Query.Builder.CreateTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Create
  alias Seraph.Test.{Post, User, UserToPost}
  alias Seraph.Test.UserToPost.Wrote

  describe "build" do
    test "ok: node identifier - [{u, User, %{firstName: \"John\"}}]" do
      ast = quote do: [{u, User, %{firstName: "John"}}]

      node_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "u_firstName_0",
            entity_identifier: "u",
            entity_queryable: Seraph.Test.User,
            name: :firstName,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.User
      }

      built_data = Create.build(ast, __ENV__)

      assert [^node_data] = built_data.create.raw_entities
      assert 1 == length(built_data.create.raw_entities)
      assert %{"u" => ^node_data} = built_data.identifiers
      assert 1 == map_size(built_data.identifiers)
      assert [u_firstName_0: "John"] == built_data.params
    end

    test "ok: node without identifier - [{User, %{firstName: \"John\"}}]" do
      ast = quote do: [{User, %{firstName: "John"}}]

      node_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: nil,
        labels: ["User"],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "create__prop__firstName_0",
            entity_identifier: nil,
            entity_queryable: Seraph.Test.User,
            name: :firstName,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.User
      }

      built_data = Create.build(ast, __ENV__)
      assert [^node_data] = built_data.create.raw_entities
      assert 1 == length(built_data.create.raw_entities)
      assert %{} == built_data.identifiers
      assert [create__prop__firstName_0: "John"] == built_data.params
    end

    test "ok: nodes identifiers in relationship" do
      ast = quote do: [[{u, User, %{firstName: ^f_name}}, [rel, Wrote], {p}]]

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: ["User"],
        properties: [
          %Seraph.Query.Builder.Entity.Property{
            alias: nil,
            bound_name: "f_name",
            entity_identifier: "u",
            entity_queryable: Seraph.Test.User,
            name: :firstName,
            type: nil,
            value: nil
          }
        ],
        queryable: Seraph.Test.User
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "p",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        queryable: Seraph.Test.UserToPost.Wrote,
        start: start_data,
        type: "WROTE"
      }

      built_data = Create.build(ast, __ENV__)
      assert [^rel_data] = built_data.create.raw_entities
      assert 1 == length(built_data.create.raw_entities)
      assert %{"u" => ^start_data, "rel" => ^rel_data, "p" => ^end_data} = built_data.identifiers
      assert 3 == map_size(built_data.identifiers)
      assert [f_name: {:f_name, [], Seraph.Query.Builder.CreateTest}] == built_data.params
    end

    test "ok: no queyables in relationship's nodes - [{u}, [rel, Wrote], {p}]" do
      ast = quote do: [[{u}, [rel, Wrote], {p}]]

      start_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "u",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      end_data = %Seraph.Query.Builder.Entity.Node{
        alias: nil,
        identifier: "p",
        labels: [],
        properties: [],
        queryable: Seraph.Node
      }

      rel_data = %Seraph.Query.Builder.Entity.Relationship{
        alias: nil,
        end: end_data,
        identifier: "rel",
        queryable: Seraph.Test.UserToPost.Wrote,
        start: start_data,
        type: "WROTE"
      }

      built_data = Create.build(ast, __ENV__)
      assert [^rel_data] = built_data.create.raw_entities
      assert 1 == length(built_data.create.raw_entities)
      assert %{"u" => ^start_data, "rel" => ^rel_data, "p" => ^end_data} = built_data.identifiers
      assert 3 == map_size(built_data.identifiers)
      assert [] == built_data.params
    end

    test "fail: don't accept node without queryable" do
      assert_raise ArgumentError, fn ->
        defmodule WillFail do
          ast = quote do: [{u, %{uuid: ^user_uuid}}]
          Create.build(ast, __ENV__)
        end
      end

      assert_raise ArgumentError, fn ->
        defmodule WillFail do
          ast = quote do: [{u}]
          Create.build(ast, __ENV__)
        end
      end

      assert_raise ArgumentError, fn ->
        defmodule WillFail do
          ast = quote do: [{%{uuid: ^user_uuid}}]
          Create.build(ast, __ENV__)
        end
      end
    end

    test "fail: don't accept empty nodes" do
      assert_raise ArgumentError, fn ->
        defmodule WillFail do
          ast = quote do: [{}]
          Create.build(ast, __ENV__)
        end
      end
    end
  end
end
