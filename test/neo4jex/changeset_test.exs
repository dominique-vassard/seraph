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

  describe "Node:" do
    test "cast/4 produces a valid Ecto.Changeset" do
      assert %Ecto.Changeset{valid?: true} =
               Changeset.cast(%User{}, %{name: "John", numeric_id: 5}, [:name, :numeric_id])
    end

    test "change/2 produces a valid Ecto.Changeset" do
      assert %Ecto.Changeset{} = Changeset.change(%User{name: "User"})
    end

    test "multiple label valid changeset" do
      data = %{
        name: "John",
        numeric_id: 5,
        additional_labels: ["Valid", "Label"]
      }

      assert %Ecto.Changeset{valid?: true} =
               Changeset.cast(%User{}, data, [:name, :numeric_id, :additional_labels])
    end

    test "multiple label invalid changeset" do
      data = %{
        name: "John",
        numeric_id: 5,
        additional_labels: [:invalid]
      }

      assert %Ecto.Changeset{valid?: false} =
               Changeset.cast(%User{}, data, [:name, :numeric_id, :additional_labels])
    end
  end

  describe "Relationship:" do
    test "cast/4 produces a valid Ecto.Changeset" do
      assert %Ecto.Changeset{valid?: true} =
               Changeset.cast(%UserWrotePost{}, %{at: DateTime.utc_now()}, [:at])
    end

    test "change/2 produces a valid Ecto.Changeset" do
      assert %Ecto.Changeset{} = Changeset.change(%UserWrotePost{})
    end
  end
end
