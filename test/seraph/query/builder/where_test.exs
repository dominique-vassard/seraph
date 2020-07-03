defmodule Seraph.Query.Builder.WhereTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Where

  describe "build/3" do
    test ":== with direct value" do
      ast = quote do: u.uuid == "uuid-1"

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :==,
               value: nil,
               variable: :uuid
             } = condition

      assert [where__0: "uuid-1"] = params
    end

    test ":== with pinned value" do
      ast = quote do: u.uuid == ^uuid

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "uuid",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :==,
               value: nil,
               variable: :uuid
             } = condition

      assert [uuid: {:uuid, [], Seraph.Query.Builder.WhereTest}] = params
    end

    test ":and" do
      ast = quote do: u.uuid == "uuid-1" and u.firstName == "John"

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: nil,
               conditions: [
                 %Seraph.Query.Builder.Entity.Condition{
                   bound_name: "where__0",
                   conditions: nil,
                   entity_identifier: "u",
                   join_operator: :and,
                   operator: :==,
                   value: nil,
                   variable: :uuid
                 },
                 %Seraph.Query.Builder.Entity.Condition{
                   bound_name: "where__1",
                   conditions: nil,
                   entity_identifier: "u",
                   join_operator: :and,
                   operator: :==,
                   value: nil,
                   variable: :firstName
                 }
               ],
               entity_identifier: nil,
               join_operator: :and,
               operator: :and,
               value: nil,
               variable: nil
             } = condition

      assert [where__1: "John", where__0: "uuid-1"] = params
    end

    test ":or" do
      ast = quote do: u.firstName == "John" or u.firstName == "Jack"
      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: nil,
               conditions: [
                 %Seraph.Query.Builder.Entity.Condition{
                   bound_name: "where__0",
                   conditions: nil,
                   entity_identifier: "u",
                   join_operator: :and,
                   operator: :==,
                   value: nil,
                   variable: :firstName
                 },
                 %Seraph.Query.Builder.Entity.Condition{
                   bound_name: "where__1",
                   conditions: nil,
                   entity_identifier: "u",
                   join_operator: :and,
                   operator: :==,
                   value: nil,
                   variable: :firstName
                 }
               ],
               entity_identifier: nil,
               join_operator: :and,
               operator: :or,
               value: nil,
               variable: nil
             } = condition

      assert [where__1: "Jack", where__0: "John"] = params
    end

    test ":xor" do
      ast = quote do: xor(u.firstName == "John", u.firstName == "Jack")
      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: nil,
               conditions: [
                 %Seraph.Query.Builder.Entity.Condition{
                   bound_name: "where__0",
                   conditions: nil,
                   entity_identifier: "u",
                   join_operator: :and,
                   operator: :==,
                   value: nil,
                   variable: :firstName
                 },
                 %Seraph.Query.Builder.Entity.Condition{
                   bound_name: "where__1",
                   conditions: nil,
                   entity_identifier: "u",
                   join_operator: :and,
                   operator: :==,
                   value: nil,
                   variable: :firstName
                 }
               ],
               entity_identifier: nil,
               join_operator: :and,
               operator: :xor,
               value: nil,
               variable: nil
             } = condition

      assert [where__1: "Jack", where__0: "John"] = params
    end

    test ":is_nil" do
      ast = quote do: is_nil(u.lastName)

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: nil,
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :is_nil,
               value: nil,
               variable: :lastName
             } = condition

      assert [] = params
    end

    test ":not" do
      ast = quote do: not is_nil(u.lastName)

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: nil,
               conditions: [
                 %Seraph.Query.Builder.Entity.Condition{
                   bound_name: nil,
                   conditions: nil,
                   entity_identifier: "u",
                   join_operator: :and,
                   operator: :is_nil,
                   value: nil,
                   variable: :lastName
                 }
               ],
               entity_identifier: nil,
               join_operator: :and,
               operator: :not,
               value: nil,
               variable: nil
             } = condition

      assert [] = params
    end

    test ":in" do
      ast = quote do: u.lastName in ["John", "Jack"]

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :in,
               value: nil,
               variable: :lastName
             } = condition

      assert [where__0: ["John", "Jack"]] = params
    end

    test ":<>" do
      ast = quote do: u.lastName <> "John"

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :<>,
               value: nil,
               variable: :lastName
             } = condition

      assert [where__0: "John"] = params
    end

    test ":exists" do
      ast = quote do: exists(u.lastName)

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: nil,
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :exists,
               value: nil,
               variable: :lastName
             } = condition

      assert [] = params
    end

    test "comparison operators :>, :>=, :<, :<=" do
      ast = quote do: u.viewCount > 5

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :>,
               value: nil,
               variable: :viewCount
             } = condition

      assert [where__0: 5] = params

      ast = quote do: u.viewCount >= 5

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :>=,
               value: nil,
               variable: :viewCount
             } = condition

      assert [where__0: 5] = params

      ast = quote do: u.viewCount < 5

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :<,
               value: nil,
               variable: :viewCount
             } = condition

      assert [where__0: 5] = params

      ast = quote do: u.viewCount <= 5

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :<=,
               value: nil,
               variable: :viewCount
             } = condition

      assert [where__0: 5] = params
    end

    test "text operators :starts_with, :ends_with, :contains" do
      ast = quote do: starts_with(u.lastName, "J")

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :starts_with,
               value: nil,
               variable: :lastName
             } = condition

      assert [where__0: "J"] = params

      ast = quote do: ends_with(u.lastName, "J")

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :ends_with,
               value: nil,
               variable: :lastName
             } = condition

      assert [where__0: "J"] = params

      ast = quote do: contains(u.lastName, "J")

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :contains,
               value: nil,
               variable: :lastName
             } = condition

      assert [where__0: "J"] = params
    end

    test "=~" do
      ast = quote do: u.lastName =~ "J"

      assert %Where{condition: condition, params: params} = Where.build(ast, __ENV__)

      assert %Seraph.Query.Builder.Entity.Condition{
               bound_name: "where__0",
               conditions: nil,
               entity_identifier: "u",
               join_operator: :and,
               operator: :=~,
               value: nil,
               variable: :lastName
             } = condition

      assert [where__0: "J"] = params
    end

    test "multiple bound params" do
      ast = quote do: u.uuid == "uuid-1" and u.lastName == ^ln and u.firstName == "John"

      assert %Where{condition: _, params: params} = Where.build(ast, __ENV__)

      assert [where__1: "John", ln: {:ln, [], Seraph.Query.Builder.WhereTest}, where__0: "uuid-1"] =
               params
    end
  end
end
