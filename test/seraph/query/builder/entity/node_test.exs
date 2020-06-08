defmodule Seraph.Query.Builder.Entity.NodeTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Entity.Node
  alias Seraph.Test.User

  test "ok: {}" do
    ast = quote do: {}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: nil,
             labels: [],
             properties: [],
             queryable: Seraph.Node
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {%{uuid: ^user_uuid}}" do
    ast = quote do: {%{uuid: ^user_uuid}}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: nil,
             labels: [],
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: nil,
                 entity_queryable: Seraph.Node,
                 name: :uuid,
                 type: nil,
                 value: {:user_uuid, [], Seraph.Query.Builder.Entity.NodeTest}
               }
             ],
             queryable: Seraph.Node
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {%{uuid: \"uuid-1\"}}" do
    ast = quote do: {%{uuid: "uuid-1"}}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: nil,
             labels: [],
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: nil,
                 entity_queryable: Seraph.Node,
                 name: :uuid,
                 type: nil,
                 value: "uuid-1"
               }
             ],
             queryable: Seraph.Node
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {u}" do
    ast = quote do: {u}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: "u",
             labels: [],
             properties: [],
             queryable: Seraph.Node
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {u, %{uuid: ^user_uuid}}" do
    ast = quote do: {u, %{uuid: ^user_uuid}}

    assert %Seraph.Query.Builder.Entity.Node{
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
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {u, %{uuid: \"uuid-1\"}}" do
    ast = quote do: {u, %{uuid: "uuid-1"}}

    assert %Seraph.Query.Builder.Entity.Node{
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
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {u, User}" do
    ast = quote do: {u, User}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: "u",
             labels: ["User"],
             properties: [],
             queryable: Seraph.Test.User
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {u, User, %{uuid: ^user_uuid}}" do
    ast = quote do: {u, User, %{uuid: ^user_uuid}}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: "u",
             labels: ["User"],
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
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {u, User, %{uuid: \"uuid-1\"}}" do
    ast = quote do: {u, User, %{uuid: "uuid-1"}}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: "u",
             labels: ["User"],
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "u",
                 entity_queryable: Seraph.Test.User,
                 name: :uuid,
                 type: nil,
                 value: "uuid-1"
               }
             ],
             queryable: Seraph.Test.User
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {User}" do
    ast = quote do: {User}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: nil,
             labels: ["User"],
             properties: [],
             queryable: Seraph.Test.User
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {User, %{uuid: ^user_uuid}}" do
    ast = quote do: {User, %{uuid: ^user_uuid}}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: nil,
             labels: ["User"],
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: nil,
                 entity_queryable: Seraph.Test.User,
                 name: :uuid,
                 type: nil,
                 value: {:user_uuid, [], Seraph.Query.Builder.Entity.NodeTest}
               }
             ],
             queryable: Seraph.Test.User
           } = Node.from_ast(ast, __ENV__)
  end

  test "ok: {User, %{uuid: \"uuid-1\"}}" do
    ast = quote do: {User, %{uuid: "uuid-1"}}

    assert %Seraph.Query.Builder.Entity.Node{
             alias: nil,
             identifier: nil,
             labels: ["User"],
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: nil,
                 entity_queryable: Seraph.Test.User,
                 name: :uuid,
                 type: nil,
                 value: "uuid-1"
               }
             ],
             queryable: Seraph.Test.User
           } = Node.from_ast(ast, __ENV__)
  end

  test "fail: unknwon queryable" do
    assert_raise UndefinedFunctionError, fn ->
      defmodule WillFail do
        ast = quote do: {u, Unknown}
        Seraph.Query.Builder.Entity.Node.from_ast(ast, __ENV__)
      end
    end
  end
end
