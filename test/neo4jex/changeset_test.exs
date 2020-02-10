defmodule Neo4jex.ChangesetTest do
  use ExUnit.Case, async: true

  defmodule User do
    use Neo4jex.Schema.Node

    node "User" do
      property :name, :string
      property :numeric_id, :integer
    end
  end

  defmodule Post do
    use Neo4jex.Schema.Node

    node "Post" do
      property :title, :string
      property :text, :string
    end
  end

  defmodule UserWrotePost do
    use Neo4jex.Schema.Relationship

    relationship "WROTE" do
      start_node User
      end_node Post

      property :at, :utc_datetime
    end
  end

  alias Neo4jex.Changeset

  test "Node: cast/4 produces a valid Ecto.Changeset" do
    assert %Ecto.Changeset{valid?: true} =
             Changeset.cast(%User{}, %{name: "John", numeric_id: 5}, [:name, :numeric_id])
  end

  test "Node: change/2 produces a valid Ecto.Changeset" do
    assert %Ecto.Changeset{} = Changeset.change(%User{name: "User"})
  end

  test "Relationship: cast/4 produces a valid Ecto.Changeset" do
    assert %Ecto.Changeset{valid?: true} =
             Changeset.cast(%UserWrotePost{}, %{at: DateTime.utc_now()}, [:at])
  end

  test "Relationship: change/2 produces a valid Ecto.Changeset" do
    assert %Ecto.Changeset{} = Changeset.change(%UserWrotePost{})
  end
end
