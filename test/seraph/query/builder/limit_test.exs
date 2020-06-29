defmodule Seraph.Query.Builder.LimitTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Limit

  describe "build/2" do
    test "with number: 3" do
      ast = quote do: 3

      assert %{limit: limit, params: []} = Limit.build(ast, __ENV__)

      assert %Limit{
               value: 3,
               bound_name: nil
             } == limit
    end

    test "with pinned data: ^limit" do
      ast = quote do: ^limit_value

      assert %{limit: limit, params: params} = Limit.build(ast, __ENV__)

      assert %Limit{
               value: nil,
               bound_name: "limit_value"
             } == limit

      assert [limit_value: {:limit_value, [], Seraph.Query.Builder.LimitTest}] == params
    end
  end

  describe "check/2" do
    test "ok" do
      ast = quote do: 3
      %{limit: limit} = Limit.build(ast, __ENV__)
      assert :ok = Limit.check(limit, %Seraph.Query{})
    end

    test "ok with pinned data" do
      limit_value = 3
      ast = quote do: ^limit_value
      %{limit: limit, params: _} = Limit.build(ast, __ENV__)
      assert :ok = Limit.check(limit, %Seraph.Query{params: [limit_value: limit_value]})
    end

    test "fail: value is not an integer" do
      ast = quote do: 4.6
      %{limit: limit} = Limit.build(ast, __ENV__)
      assert {:error, error} = Limit.check(limit, %Seraph.Query{})
      assert error =~ "[Limit] should be a positive integer, 0 excluded"
    end

    test "fail: value is not an postive integer" do
      ast = quote do: -5
      %{limit: limit} = Limit.build(ast, __ENV__)
      assert {:error, error} = Limit.check(limit, %Seraph.Query{})
      assert error =~ "[Limit] should be a positive integer, 0 excluded"
    end

    test "fail: value is 0" do
      ast = quote do: 0
      %{limit: limit} = Limit.build(ast, __ENV__)
      assert {:error, error} = Limit.check(limit, %Seraph.Query{})
      assert error =~ "[Limit] should be a positive integer, 0 excluded"
    end

    test "fail: bound value is not an integer" do
      limit_value = 4.6
      ast = quote do: ^limit_value
      %{limit: limit, params: _} = Limit.build(ast, __ENV__)

      assert {:error, error} =
               Limit.check(limit, %Seraph.Query{params: [limit_value: limit_value]})

      assert error =~ "[Limit] should be a positive integer, 0 excluded"
    end

    test "fail: bound value is not an postive integer" do
      limit_value = -5
      ast = quote do: ^limit_value
      %{limit: limit, params: _} = Limit.build(ast, __ENV__)

      assert {:error, error} =
               Limit.check(limit, %Seraph.Query{params: [limit_value: limit_value]})

      assert error =~ "[Limit] should be a positive integer, 0 excluded"
    end

    test "fail: bound value is 0" do
      limit_value = 0
      ast = quote do: ^limit_value
      %{limit: limit, params: _} = Limit.build(ast, __ENV__)

      assert {:error, error} =
               Limit.check(limit, %Seraph.Query{params: [limit_value: limit_value]})

      assert error =~ "[Limit] should be a positive integer, 0 excluded"
    end
  end
end
