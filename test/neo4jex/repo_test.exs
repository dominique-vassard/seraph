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

  describe "get/2" do
    test "ok" do
      data = add_fixtures()
      uuid = data.uuid

      retrieved_user = TestRepo.get(User, uuid)

      assert %User{
               uuid: ^uuid,
               first_name: "John",
               last_name: "Doe",
               view_count: 5
             } = retrieved_user

      refute is_nil(retrieved_user.__id__)
    end

    test "no result returns nil" do
      assert is_nil(TestRepo.get(User, "non-existent"))
    end

    defmodule NoIdentifier do
      use Neo4jex.Schema.Node
      @identifier false
      @merge_keys [:id]

      node "NoIdentifier" do
        property :id, :string
      end
    end

    test "raise with queryable without identifier" do
      assert_raise ArgumentError, fn ->
        TestRepo.get(NoIdentifier, "none")
      end
    end
  end

  describe "set/2" do
    test "ok" do
      data = add_fixtures()
      data_uuid = data.uuid
      user = TestRepo.get(User, data.uuid)

      changeset = User.changeset(user, %{last_name: "New name", view_count: 3})

      assert %Neo4jex.Test.User{
               additional_labels: [],
               first_name: "John",
               last_name: "New name",
               uuid: ^data_uuid,
               view_count: 3
             } = TestRepo.set(User, changeset)
    end

    test "ok with multiple labels (add only)" do
      data = add_fixtures(%{additional_labels: ["Buyer"]})
      data_uuid = data.uuid
      user = TestRepo.get(User, data.uuid)

      changeset = User.changeset(user, %{additional_labels: ["Buyer", "New"]})

      assert %Neo4jex.Test.User{
               additional_labels: ["Buyer", "New"],
               first_name: "John",
               last_name: "Doe",
               uuid: ^data_uuid,
               view_count: 5
             } = TestRepo.set(User, changeset)
    end

    test "ok with multiple labels (remove only)" do
      data = add_fixtures(%{additional_labels: ["Buyer", "Old"]})
      data_uuid = data.uuid
      user = TestRepo.get(User, data.uuid)

      changeset = User.changeset(user, %{additional_labels: ["Old"]})

      assert %Neo4jex.Test.User{
               additional_labels: ["Old"],
               first_name: "John",
               last_name: "Doe",
               uuid: ^data_uuid,
               view_count: 5
             } = TestRepo.set(User, changeset)
    end

    test "ok with multiple labels (add + remove only)" do
      data = add_fixtures(%{additional_labels: ["Buyer", "Old"]})
      data_uuid = data.uuid
      user = TestRepo.get(User, data.uuid)

      changeset = User.changeset(user, %{additional_labels: ["Old", "Client"]})

      assert %Neo4jex.Test.User{
               additional_labels: ["Old", "Client"],
               first_name: "John",
               last_name: "Doe",
               uuid: ^data_uuid,
               view_count: 5
             } = TestRepo.set(User, changeset)
    end

    test "invalid changeset" do
      data = add_fixtures()
      user = TestRepo.get(User, data.uuid)

      changeset = User.changeset(user, %{view_count: :invalid})
      assert {:error, %Ecto.Changeset{valid?: false}} = TestRepo.set(User, changeset)
    end
  end

  defp add_fixtures(data \\ %{}) do
    default_data = %{
      uuid: UUID.uuid4(),
      first_name: "John",
      last_name: "Doe",
      view_count: 5
    }

    cql = """
    CREATE
     (u:User)
    SET
      u.uuid = $uuid,
      u.first_name = $first_name,
      u.last_name = $last_name,
      u.view_count = $view_count
    """

    params = Map.merge(default_data, data)
    TestRepo.query!(cql, params)

    params
  end
end
