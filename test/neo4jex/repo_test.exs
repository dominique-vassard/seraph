defmodule Neo4jex.RepoTest do
  use ExUnit.Case, async: true
  alias Neo4jex.TestRepo
  alias Neo4jex.Test.{User, Post}
  alias Neo4jex.Test.UserToPost.Wrote

  # test "first" do
  #   TestRepo.query("RETURN 1 AS num")
  #   |> IO.inspect()
  # end

  describe "create/" do
    test "Node alone (bare, no changeset)" do
      user = %User{
        first_name: "John",
        last_name: "Doe",
        view_count: 5
      }

      assert {:ok, created_user} = TestRepo.create(user)

      assert %Neo4jex.Test.User{
               first_name: "John",
               last_name: "Doe",
               view_count: 5
             } = created_user

      refute is_nil(created_user.__id__)
    end

    test "Node alone (changeset invalid)" do
      params = %{
        first_name: :invalid
      }

      assert {:error, %Ecto.Changeset{valid?: false}} =
               %User{}
               |> User.changeset(params)
               |> TestRepo.create()
    end

    test "Node alone (changeset valid)" do
      params = %{
        first_name: "John",
        last_name: "Doe",
        view_count: 5
      }

      assert {:ok, created_user} =
               %User{}
               |> User.changeset(params)
               |> TestRepo.create()

      assert %Neo4jex.Test.User{
               first_name: "John",
               last_name: "Doe",
               view_count: 5
             } = created_user

      refute is_nil(created_user.__id__)
    end
  end
end
