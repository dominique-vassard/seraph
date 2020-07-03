defmodule Seraph.Query.Builder.SkipTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Skip

  describe "build/2" do
    test "with number: 3" do
      ast = quote do: 3

      assert %{skip: skip, params: []} = Skip.build(ast, __ENV__)

      assert %Skip{
               value: 3,
               bound_name: nil
             } == skip
    end

    test "with pinned data: ^skip" do
      ast = quote do: ^skip_value

      assert %{skip: skip, params: params} = Skip.build(ast, __ENV__)

      assert %Skip{
               value: nil,
               bound_name: "skip_value"
             } == skip

      assert [skip_value: {:skip_value, [], Seraph.Query.Builder.SkipTest}] == params
    end
  end

  describe "check/2" do
    test "ok" do
      ast = quote do: 3
      %{skip: skip} = Skip.build(ast, __ENV__)
      assert :ok = Skip.check(skip, %Seraph.Query{})
    end

    test "ok with pinned data" do
      skip_value = 3
      ast = quote do: ^skip_value
      %{skip: skip, params: _} = Skip.build(ast, __ENV__)
      assert :ok = Skip.check(skip, %Seraph.Query{params: [skip_value: skip_value]})
    end

    test "fail: value is not an integer" do
      ast = quote do: 4.6
      %{skip: skip} = Skip.build(ast, __ENV__)
      assert {:error, error} = Skip.check(skip, %Seraph.Query{})
      assert error =~ "[Skip] should be a positive integer, 0 excluded"
    end

    test "fail: value is not an postive integer" do
      ast = quote do: -5
      %{skip: skip} = Skip.build(ast, __ENV__)
      assert {:error, error} = Skip.check(skip, %Seraph.Query{})
      assert error =~ "[Skip] should be a positive integer, 0 excluded"
    end

    test "fail: value is 0" do
      ast = quote do: 0
      %{skip: skip} = Skip.build(ast, __ENV__)
      assert {:error, error} = Skip.check(skip, %Seraph.Query{})
      assert error =~ "[Skip] should be a positive integer, 0 excluded"
    end

    test "fail: bound value is not an integer" do
      skip_value = 4.6
      ast = quote do: ^skip_value
      %{skip: skip, params: _} = Skip.build(ast, __ENV__)

      assert {:error, error} = Skip.check(skip, %Seraph.Query{params: [skip_value: skip_value]})

      assert error =~ "[Skip] should be a positive integer, 0 excluded"
    end

    test "fail: bound value is not an postive integer" do
      skip_value = -5
      ast = quote do: ^skip_value
      %{skip: skip, params: _} = Skip.build(ast, __ENV__)

      assert {:error, error} = Skip.check(skip, %Seraph.Query{params: [skip_value: skip_value]})

      assert error =~ "[Skip] should be a positive integer, 0 excluded"
    end

    test "fail: bound value is 0" do
      skip_value = 0
      ast = quote do: ^skip_value
      %{skip: skip, params: _} = Skip.build(ast, __ENV__)

      assert {:error, error} = Skip.check(skip, %Seraph.Query{params: [skip_value: skip_value]})

      assert error =~ "[Skip] should be a positive integer, 0 excluded"
    end
  end
end
