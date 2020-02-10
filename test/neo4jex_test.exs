defmodule Neo4jexTest do
  use ExUnit.Case
  doctest Neo4jex

  test "greets the world" do
    assert Neo4jex.hello() == :world
  end
end
