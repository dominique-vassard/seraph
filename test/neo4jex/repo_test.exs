defmodule Neo4jex.RepoTest do
  use ExUnit.Case, async: true
  alias Neo4jex.TestRepo
  alias Neo4jex.Test.{User, Post}
  alias Neo4jex.Test.UserToPost.Wrote

  setup do
    TestRepo.query!("MATCH (n) DETACH DELETE n", %{}, with_stats: true)

    :ok
  end

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

      cql = """
      MATCH
        (u:User)
      WHERE
        u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
        AND id(u) = $id
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{first_name: "John", last_name: "Doe", view_count: 5, id: created_user.__id__}

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
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

      cql = """
      MATCH
        (u:User)
      WHERE
        u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
        AND id(u) = $id
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{first_name: "John", last_name: "Doe", view_count: 5, id: created_user.__id__}

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "multi label Node (direct)" do
      user = %User{
        additional_labels: ["Buyer", "Regular"],
        first_name: "John",
        last_name: "Doe",
        view_count: 5
      }

      assert {:ok, created_user} = TestRepo.create(user)

      assert %Neo4jex.Test.User{
               additional_labels: ["Buyer", "Regular"],
               first_name: "John",
               last_name: "Doe",
               view_count: 5
             } = created_user

      refute is_nil(created_user.__id__)

      cql = """
      MATCH
        (u:User:Buyer:Regular)
      WHERE
        u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
        AND id(u) = $id
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{first_name: "John", last_name: "Doe", view_count: 5, id: created_user.__id__}

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "multi label Node (via changeset)" do
      params = %{
        additional_labels: ["Buyer", "Irregular"],
        first_name: "John",
        last_name: "Doe",
        view_count: 5
      }

      assert {:ok, created_user} =
               %User{}
               |> User.changeset(params)
               |> TestRepo.create()

      assert %Neo4jex.Test.User{
               additional_labels: ["Buyer", "Irregular"],
               first_name: "John",
               last_name: "Doe",
               view_count: 5
             } = created_user

      refute is_nil(created_user.__id__)

      cql = """
      MATCH
        (u:User:Irregular:Buyer)
      WHERE
        u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
        AND id(u) = $id
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{first_name: "John", last_name: "Doe", view_count: 5, id: created_user.__id__}

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end
  end
end
