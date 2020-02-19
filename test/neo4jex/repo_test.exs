defmodule Neo4jex.RepoTest do
  use ExUnit.Case, async: true
  alias Neo4jex.TestRepo
  alias Neo4jex.Test.{User, Post}
  alias Neo4jex.Test.UserToPost.Wrote

  setup do
    TestRepo.query!("MATCH (n) DETACH DELETE n", %{}, with_stats: true)

    [
      Neo4jex.Cypher.Node.list_all_constraints(""),
      Neo4jex.Cypher.Node.list_all_indexes("")
    ]
    |> Enum.map(fn cql ->
      TestRepo.raw_query!(cql)
      |> Map.get(:records, [])
    end)
    |> List.flatten()
    |> Enum.map(&Neo4jex.Cypher.Node.drop_constraint_index_from_cql/1)
    |> Enum.map(&TestRepo.query/1)

    :ok
  end

  describe "create/1" do
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
      refute is_nil(created_user.uuid)

      cql = """
      MATCH
        (u:User)
      WHERE
        u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: created_user.uuid,
        first_name: "John",
        last_name: "Doe",
        view_count: 5,
        id: created_user.__id__
      }

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
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: created_user.uuid,
        first_name: "John",
        last_name: "Doe",
        view_count: 5,
        id: created_user.__id__
      }

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
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: created_user.uuid,
        first_name: "John",
        last_name: "Doe",
        view_count: 5,
        id: created_user.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    defmodule WithoutIdentifier do
      use Neo4jex.Schema.Node
      @identifier false
      @merge_keys [:name]

      node "WithoutIdentifier" do
        property :name, :string
      end
    end

    test "without default identifier" do
      test = %WithoutIdentifier{name: "Joe"}

      assert {:ok, created} = TestRepo.create(test)
      assert is_nil(Map.get(created, :uuid))

      cql = """
      MATCH
        (n:WithoutIdentifier)
      WHERE
        n.name = $name
        AND NOT EXISTS(n.uuid)
      RETURN
        COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, %{name: "Joe"})
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

  describe "merge_on_create/1" do
    test "simple merge_on_create successful creation" do
      params = %{
        first_name: "John",
        last_name: "Doe",
        view_count: 24
      }

      {:ok, created_user} =
        %User{}
        |> User.changeset(params)
        |> TestRepo.merge_on_create()

      assert %Neo4jex.Test.User{
               additional_labels: [],
               first_name: "John",
               last_name: "Doe",
               view_count: 24
             } = created_user

      refute is_nil(created_user.uuid)
      refute is_nil(created_user.__id__)

      cql = """
      MATCH
        (u:User)
      WHERE
        u.uuid = $uuid
        AND u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
      RETURN
        COUNT(u) AS nb_result
      """

      params = Map.merge(params, %{uuid: created_user.uuid})
      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "when creating an already created node don't do anything" do
      params = %{
        first_name: "John",
        last_name: "Doe",
        view_count: 5
      }

      {:ok, user} =
        %User{}
        |> User.changeset(params)
        |> TestRepo.create()

      assert {:ok, user} ==
               User.changeset(user, %{last_name: "New name"})
               |> TestRepo.merge_on_create()

      cql = """
      MATCH
        (u:User)
      WHERE
        u.uuid = $uuid
        AND u.first_name = $first_name
        AND u.view_count = $view_count
      RETURN
        u.last_name As last_name
      """

      params = Map.merge(params, %{uuid: user.uuid})
      assert [%{"last_name" => "Doe"}] = TestRepo.query!(cql, params)
    end

    test "succesful with multiple label" do
      params = %{
        additional_labels: ["Admin", "Director"],
        first_name: "John",
        last_name: "Doe",
        view_count: 24
      }

      {:ok, created_user} =
        %User{}
        |> User.changeset(params)
        |> TestRepo.merge_on_create()

      assert %Neo4jex.Test.User{
               additional_labels: ["Admin", "Director"],
               first_name: "John",
               last_name: "Doe",
               view_count: 24
             } = created_user

      refute is_nil(created_user.uuid)
      refute is_nil(created_user.__id__)

      cql = """
      MATCH
        (u:User:Admin:Director)
      WHERE
        u.uuid = $uuid
        AND u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
      RETURN
        COUNT(u) AS nb_result
      """

      params = Map.merge(params, %{uuid: created_user.uuid})
      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end
  end

  describe "merge_on_match/1" do
    test "succesful" do
      params = %{
        first_name: "John",
        last_name: "Doe",
        view_count: 5
      }

      {:ok, created_user} =
        %User{}
        |> User.changeset(params)
        |> TestRepo.create()

      assert {:ok, merged_user} =
               User.changeset(created_user, %{last_name: "New name"})
               |> TestRepo.merge_on_match()

      assert %Neo4jex.Test.User{
               additional_labels: [],
               first_name: "John",
               last_name: "New name",
               view_count: 5
             } = merged_user

      cql = """
      MATCH
        (u:User)
      WHERE
        u.uuid = $uuid
        AND u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
      RETURN
        COUNT(u) AS nb_result
      """

      params = Map.merge(params, %{uuid: created_user.uuid, last_name: "New name"})
      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "succesful with new additional labels" do
      params = %{
        first_name: "John",
        last_name: "Doe",
        view_count: 5
      }

      {:ok, created_user} =
        %User{}
        |> User.changeset(params)
        |> TestRepo.create()

      assert {:ok, merged_user} =
               User.changeset(created_user, %{additional_labels: ["New", "Buyer"]})
               |> TestRepo.merge_on_match()

      assert %Neo4jex.Test.User{
               additional_labels: ["New", "Buyer"]
             } = merged_user

      cql = """
      MATCH
        (u:User:New:Buyer)
      WHERE
        u.uuid = $uuid
        AND u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
      RETURN
        COUNT(u) AS nb_result
      """

      params = Map.merge(params, %{uuid: created_user.uuid})
      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "succesful with new additional labels and old ones removed" do
      params = %{
        additional_labels: ["Admin", "Director"],
        first_name: "John",
        last_name: "Doe",
        view_count: 5
      }

      {:ok, created_user} =
        %User{}
        |> User.changeset(params)
        |> TestRepo.create()

      assert {:ok, merged_user} =
               User.changeset(created_user, %{
                 additional_labels: ["Admin", "Buyer"],
                 view_count: 25
               })
               |> TestRepo.merge_on_match()

      assert %Neo4jex.Test.User{
               additional_labels: ["Admin", "Buyer"],
               view_count: 25
             } = merged_user

      cql = """
        MATCH
        (u:User:Admin:Buyer)
      WHERE
        u.uuid = $uuid
        AND u.first_name = $first_name
        AND u.last_name = $last_name
        AND u.view_count = $view_count
      RETURN
        COUNT(u) AS nb_result
      """

      params = Map.merge(params, %{uuid: created_user.uuid, view_count: 25})
      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end
  end
end
