defmodule Seraph.Query.Builder.MergeTest do
  use ExUnit.Case, async: true
  # alias Seraph.Query.Builder.Merge

  test "fail: don't accept empty nodes" do
    assert_raise ArgumentError, fn ->
      defmodule WillFail do
        ast = quote do: {}
        Seraph.Query.Builder.Merge.build(ast, __ENV__)
      end
    end
  end
end
