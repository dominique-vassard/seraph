defmodule Seraph.Query.Builder.Entity.RelationshipTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Entity.Relationship
  alias Seraph.Test.UserToPost.Wrote

  test "ok: [{u}, [], {p}]" do
    ast = quote do: [{u}, [], {p}]

    start_node = start_node()
    end_node = end_node()

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: nil,
             properties: [],
             queryable: Seraph.Relationship,
             start: ^start_node,
             type: nil
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [%{at: ^date}], {p}]" do
    ast = quote do: [{u}, [%{at: ^date}], {p}]

    start_node = start_node()
    end_node = end_node()

    %Seraph.Query.Builder.Entity.Relationship{
      alias: nil,
      end: ^end_node,
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
      start: ^start_node,
      type: nil
    } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [%{at: \"2020-05-04\"}], {p}]" do
    ast = quote do: [{u}, [%{at: "2020-05-04"}], {p}]

    start_node = start_node()
    end_node = end_node()

    %Seraph.Query.Builder.Entity.Relationship{
      alias: nil,
      end: ^end_node,
      identifier: nil,
      properties: [
        %Seraph.Query.Builder.Entity.Property{
          alias: nil,
          bound_name: nil,
          entity_identifier: nil,
          entity_queryable: Seraph.Relationship,
          name: :at,
          type: nil,
          value: "2020-05-04"
        }
      ],
      queryable: Seraph.Relationship,
      start: ^start_node,
      type: nil
    } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [rel], {p}]" do
    ast = quote do: [{u}, [rel], {p}]

    start_node = start_node()
    end_node = end_node()

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: "rel",
             properties: [],
             queryable: Seraph.Relationship,
             start: ^start_node,
             type: nil
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [rel, %{at: ^date}], {p}]" do
    ast = quote do: [{u}, [rel, %{at: ^date}], {p}]

    start_node = start_node()
    end_node = end_node()

    %Seraph.Query.Builder.Entity.Relationship{
      alias: nil,
      end: ^end_node,
      identifier: "rel",
      properties: [
        %Seraph.Query.Builder.Entity.Property{
          alias: nil,
          bound_name: nil,
          entity_identifier: "rel",
          entity_queryable: Seraph.Relationship,
          name: :at,
          type: nil,
          value: {:date, [], Seraph.Query.Builder.Entity.RelationshipTest}
        }
      ],
      queryable: Seraph.Relationship,
      start: ^start_node,
      type: nil
    } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [rel, %{at: \"2020-05-04\"}], {p}]" do
    ast = quote do: [{u}, [rel, %{at: "2020-05-04"}], {p}]

    start_node = start_node()
    end_node = end_node()

    %Seraph.Query.Builder.Entity.Relationship{
      alias: nil,
      end: ^end_node,
      identifier: "rel",
      properties: [
        %Seraph.Query.Builder.Entity.Property{
          alias: nil,
          bound_name: nil,
          entity_identifier: "rel",
          entity_queryable: Seraph.Relationship,
          name: :at,
          type: nil,
          value: "2020-05-04"
        }
      ],
      queryable: Seraph.Relationship,
      start: ^start_node,
      type: nil
    } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [rel, Wrote], {p}]" do
    ast = quote do: [{u}, [rel, Wrote], {p}]

    start_node = start_node(:full)
    end_node = end_node(:full)

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: "rel",
             properties: [],
             queryable: Seraph.Test.UserToPost.Wrote,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [rel, Wrote, %{at: ^date}], {p}]" do
    ast = quote do: [{u}, [rel, Wrote, %{at: ^date}], {p}]

    start_node = start_node(:full)
    end_node = end_node(:full)

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: "rel",
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "rel",
                 entity_queryable: Seraph.Test.UserToPost.Wrote,
                 name: :at,
                 type: nil,
                 value: {:date, [], Seraph.Query.Builder.Entity.RelationshipTest}
               }
             ],
             queryable: Seraph.Test.UserToPost.Wrote,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [rel, Wrote, %{at: \"2020-05-04\"}], {p}]" do
    ast = quote do: [{u}, [rel, Wrote, %{at: "2020-05-04"}], {p}]

    start_node = start_node(:full)
    end_node = end_node(:full)

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: "rel",
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "rel",
                 entity_queryable: Seraph.Test.UserToPost.Wrote,
                 name: :at,
                 type: nil,
                 value: "2020-05-04"
               }
             ],
             queryable: Seraph.Test.UserToPost.Wrote,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [Wrote], {p}]" do
    ast = quote do: [{u}, [Wrote], {p}]

    start_node = start_node(:full)
    end_node = end_node(:full)

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: nil,
             properties: [],
             queryable: Seraph.Test.UserToPost.Wrote,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [Wrote, %{at: ^date}], {p}]" do
    ast = quote do: [{u}, [Wrote, %{at: ^date}], {p}]

    start_node = start_node(:full)
    end_node = end_node(:full)

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: nil,
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: nil,
                 entity_queryable: Seraph.Test.UserToPost.Wrote,
                 name: :at,
                 type: nil,
                 value: {:date, [], Seraph.Query.Builder.Entity.RelationshipTest}
               }
             ],
             queryable: Seraph.Test.UserToPost.Wrote,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [Wrote, %{at: \"2020-05-04\"}], {p}]" do
    ast = quote do: [{u}, [Wrote, %{at: "2020-05-04"}], {p}]

    start_node = start_node(:full)
    end_node = end_node(:full)

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: nil,
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: nil,
                 entity_queryable: Seraph.Test.UserToPost.Wrote,
                 name: :at,
                 type: nil,
                 value: "2020-05-04"
               }
             ],
             queryable: Seraph.Test.UserToPost.Wrote,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [rel, \"WROTE\"], {p}]" do
    ast = quote do: [{u}, [rel, "WROTE"], {p}]

    start_node = start_node()
    end_node = end_node()

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: "rel",
             properties: [],
             queryable: Seraph.Relationship,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [rel, \"WROTE\", %{at: ^date}], {p}]" do
    ast = quote do: [{u}, [rel, "WROTE", %{at: ^date}], {p}]

    start_node = start_node()
    end_node = end_node()

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: "rel",
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "rel",
                 entity_queryable: Seraph.Relationship,
                 name: :at,
                 type: nil,
                 value: {:date, [], Seraph.Query.Builder.Entity.RelationshipTest}
               }
             ],
             queryable: Seraph.Relationship,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [rel, \"WROTE\", %{at: \"2020-05-04\"}], {p}]" do
    ast = quote do: [{u}, [rel, "WROTE", %{at: "2020-05-04"}], {p}]

    start_node = start_node()
    end_node = end_node()

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: "rel",
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "rel",
                 entity_queryable: Seraph.Relationship,
                 name: :at,
                 type: nil,
                 value: "2020-05-04"
               }
             ],
             queryable: Seraph.Relationship,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [\"WROTE\"], {p}]" do
    ast = quote do: [{u}, ["WROTE"], {p}]

    start_node = start_node()
    end_node = end_node()

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: nil,
             properties: [],
             queryable: Seraph.Relationship,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [\"WROTE\", %{at: ^date}], {p}]" do
    ast = quote do: [{u}, ["WROTE", %{at: ^date}], {p}]

    start_node = start_node()
    end_node = end_node()

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
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
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "ok: [{u}, [\"WROTE\", %{at: \"2020-05-04\"}], {p}]" do
    ast = quote do: [{u}, ["WROTE", %{at: "2020-05-04"}], {p}]

    start_node = start_node()
    end_node = end_node()

    assert %Seraph.Query.Builder.Entity.Relationship{
             alias: nil,
             end: ^end_node,
             identifier: nil,
             properties: [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: nil,
                 entity_queryable: Seraph.Relationship,
                 name: :at,
                 type: nil,
                 value: "2020-05-04"
               }
             ],
             queryable: Seraph.Relationship,
             start: ^start_node,
             type: "WROTE"
           } = Relationship.from_ast(ast, __ENV__)
  end

  test "fail: unknwon queryable" do
    assert_raise UndefinedFunctionError, fn ->
      defmodule WillFail do
        ast = quote do: [{u}, [Unknown], {p}]
        Seraph.Query.Builder.Entity.Relationship.from_ast(ast, __ENV__)
      end
    end
  end

  test "fail: Empty relationship [{}, [], {}]" do
    assert_raise ArgumentError, fn ->
      defmodule WillFail do
        ast = quote do: [{}, [], {}]
        Seraph.Query.Builder.Entity.Relationship.from_ast(ast, __ENV__)
      end
    end
  end

  def start_node(shape \\ nil)

  def start_node(:full) do
    %Seraph.Query.Builder.Entity.Node{
      alias: nil,
      identifier: "u",
      labels: ["User"],
      properties: [],
      queryable: Seraph.Test.User
    }
  end

  def start_node(_) do
    %Seraph.Query.Builder.Entity.Node{
      alias: nil,
      identifier: "u",
      labels: [],
      properties: [],
      queryable: Seraph.Node
    }
  end

  def end_node(shape \\ nil)

  def end_node(:full) do
    %Seraph.Query.Builder.Entity.Node{
      alias: nil,
      identifier: "p",
      labels: ["Post"],
      properties: [],
      queryable: Seraph.Test.Post
    }
  end

  def end_node(_) do
    %Seraph.Query.Builder.Entity.Node{
      alias: nil,
      identifier: "p",
      labels: [],
      properties: [],
      queryable: Seraph.Node
    }
  end
end
