defmodule SeraphTest do
  use ExUnit.Case
  doctest Seraph

  test "greets the world" do
    assert Seraph.hello() == :world
  end
end
