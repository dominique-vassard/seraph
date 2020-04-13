defmodule Seraph.RepoTest do
  use ExUnit.Case, async: true
  alias Seraph.TestRepo
  alias Seraph.Test.User

  setup do
    TestRepo.query!("MATCH (n) DETACH DELETE n", %{}, with_stats: true)

    [
      Seraph.Cypher.Node.list_all_constraints(""),
      Seraph.Cypher.Node.list_all_indexes("")
    ]
    |> Enum.map(fn cql ->
      TestRepo.raw_query!(cql)
      |> Map.get(:records, [])
    end)
    |> List.flatten()
    |> Enum.map(&Seraph.Cypher.Node.drop_constraint_index_from_cql/1)
    |> Enum.map(&TestRepo.query/1)

    :ok
  end

  describe "create/1" do
    test "Node alone (bare, no changeset)" do
      user = %User{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert {:ok, created_user} = TestRepo.create(user)

      assert %Seraph.Test.User{
               firstName: "John",
               lastName: "Doe",
               viewCount: 5
             } = created_user

      refute is_nil(created_user.__id__)
      refute is_nil(created_user.uuid)

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: created_user.uuid,
        firstName: "John",
        lastName: "Doe",
        viewCount: 5,
        id: created_user.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "Node alone (changeset invalid)" do
      params = %{
        firstName: :invalid
      }

      assert {:error, %Seraph.Changeset{valid?: false}} =
               %User{}
               |> User.changeset(params)
               |> TestRepo.create()
    end

    test "Node alone (changeset valid)" do
      params = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert {:ok, created_user} =
               %User{}
               |> User.changeset(params)
               |> TestRepo.create()

      assert %Seraph.Test.User{
               firstName: "John",
               lastName: "Doe",
               viewCount: 5
             } = created_user

      refute is_nil(created_user.__id__)

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: created_user.uuid,
        firstName: "John",
        lastName: "Doe",
        viewCount: 5,
        id: created_user.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "multi label Node (direct)" do
      user = %User{
        additionalLabels: ["Buyer", "Regular"],
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert {:ok, created_user} = TestRepo.create(user)

      assert %Seraph.Test.User{
               additionalLabels: ["Buyer", "Regular"],
               firstName: "John",
               lastName: "Doe",
               viewCount: 5
             } = created_user

      refute is_nil(created_user.__id__)

      cql = """
      MATCH
        (u:User:Buyer:Regular)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: created_user.uuid,
        firstName: "John",
        lastName: "Doe",
        viewCount: 5,
        id: created_user.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    defmodule WithoutIdentifier do
      use Seraph.Schema.Node
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
        additionalLabels: ["Buyer", "Irregular"],
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert {:ok, created_user} =
               %User{}
               |> User.changeset(params)
               |> TestRepo.create()

      assert %Seraph.Test.User{
               additionalLabels: ["Buyer", "Irregular"],
               firstName: "John",
               lastName: "Doe",
               viewCount: 5
             } = created_user

      refute is_nil(created_user.__id__)

      cql = """
      MATCH
        (u:User:Irregular:Buyer)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{firstName: "John", lastName: "Doe", viewCount: 5, id: created_user.__id__}

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "raise when using !" do
      params = %{
        firstName: :invalid,
        lastName: "Doe",
        viewCount: 5
      }

      assert_raise Seraph.InvalidChangesetError, fn ->
        %User{}
        |> User.changeset(params)
        |> TestRepo.create!()
      end
    end
  end

  describe "get/2" do
    test "ok" do
      data = add_fixtures()
      uuid = data.uuid

      retrieved_user = TestRepo.get(User, uuid)

      assert %User{
               uuid: ^uuid,
               firstName: "John",
               lastName: "Doe",
               viewCount: 5
             } = retrieved_user

      refute is_nil(retrieved_user.__id__)
    end

    test "no result returns nil" do
      assert is_nil(TestRepo.get(User, "non-existent"))
    end

    defmodule NoIdentifier do
      use Seraph.Schema.Node
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

    test "raise when used with !" do
      assert_raise Seraph.NoResultsError, fn ->
        TestRepo.get!(User, "unknown")
      end
    end
  end

  describe "merge/2" do
    test "ok with changeset: node creation" do
      params = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert {:ok, merged_node} =
               %User{}
               |> User.changeset(params)
               |> TestRepo.merge()

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        firstName: "John",
        lastName: "Doe",
        viewCount: 5,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "ok with data: node creation" do
      data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert {:ok, merged_node} =
               %User{}
               |> User.changeset(data)
               |> Seraph.Changeset.apply_changes()
               |> TestRepo.merge()

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        firstName: "John",
        lastName: "Doe",
        viewCount: 5,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "ok with changeset: node update" do
      user_data = add_fixtures()

      user = TestRepo.get(User, user_data.uuid)

      params = %{
        firstName: "James",
        lastName: "Who",
        viewCount: 0
      }

      assert {:ok, merged_node} =
               user
               |> User.changeset(params)
               |> TestRepo.merge()

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        firstName: "James",
        lastName: "Who",
        viewCount: 0,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "ok with data: node update" do
      user_data = add_fixtures()

      user = TestRepo.get(User, user_data.uuid)

      params = %{
        firstName: "James",
        lastName: "Who",
        viewCount: 0
      }

      assert {:ok, merged_node} =
               user
               |> User.changeset(params)
               |> Seraph.Changeset.apply_changes()
               |> TestRepo.merge()

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        firstName: "James",
        lastName: "Who",
        viewCount: 0,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "fail: when a basic map is given" do
      assert_raise ArgumentError, fn ->
        TestRepo.merge(%{firstName: "test"})
      end
    end

    test "fail: invalid changeset" do
      user_data = add_fixtures()

      user = TestRepo.get(User, user_data.uuid)

      params = %{
        firstName: :invalid
      }

      assert {:error, %Seraph.Changeset{valid?: false}} =
               user
               |> User.changeset(params)
               |> TestRepo.merge()
    end

    test "raise: when used with !" do
      user_data = add_fixtures()

      user = TestRepo.get(User, user_data.uuid)

      params = %{
        firstName: :invalid
      }

      assert_raise Seraph.InvalidChangesetError, fn ->
        user
        |> User.changeset(params)
        |> TestRepo.merge!()
      end
    end
  end

  describe "merge/3 (on_create, on_match)" do
    test "ok: on_create opt (not existing -> creation)" do
      data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert {:ok, merged_node} =
               TestRepo.merge(User, %{uuid: "some-uuid"}, on_create: {data, &User.changeset/2})

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        firstName: "John",
        lastName: "Doe",
        viewCount: 5,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "ok: on_create opt (existing -> no change)" do
      user = add_fixtures()

      data = %{
        firstName: "James",
        lastName: "What",
        viewCount: 25
      }

      assert {:ok, merged_node} =
               TestRepo.merge(User, %{uuid: user.uuid}, on_create: {data, &User.changeset/2})

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        firstName: "John",
        lastName: "Doe",
        viewCount: 5,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "ok: on_match opt (not existing -> no 'merge' data)" do
      data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert {:ok, merged_node} =
               TestRepo.merge(User, %{uuid: "some-uuid"}, on_match: {data, &User.changeset/2})

      cql = """
      MATCH
        (u:User)
      WHERE
        NOT EXISTS(u.firstName)
        AND NOT EXISTS(u.lastName)
        AND NOT EXISTS(u.viewCount)
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "ok: on_match opt (existing -> update)" do
      user = add_fixtures()

      data = %{
        firstName: "James",
        lastName: "What",
        viewCount: 25
      }

      assert {:ok, merged_node} =
               TestRepo.merge(User, %{uuid: user.uuid}, on_match: {data, &User.changeset/2})

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        firstName: "James",
        lastName: "What",
        viewCount: 25,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "ok: on_create + on_match opts (not existing -> creation)" do
      on_create_data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      on_match_data = %{
        firstName: "James",
        lastName: "What",
        viewCount: 25
      }

      assert {:ok, merged_node} =
               TestRepo.merge(User, %{uuid: "some-uuid"},
                 on_create: {on_create_data, &User.changeset/2},
                 on_match: {on_match_data, &User.update_viewcount_changeset/2}
               )

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        firstName: "John",
        lastName: "Doe",
        viewCount: 5,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "ok: on_create + on_match opts (existing -> update)" do
      user = add_fixtures()

      on_create_data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      on_match_data = %{
        firstName: "James",
        lastName: "What",
        viewCount: 25
      }

      assert {:ok, merged_node} =
               TestRepo.merge(User, %{uuid: user.uuid},
                 on_create: {on_create_data, &User.changeset/2},
                 on_match: {on_match_data, &User.update_viewcount_changeset/2}
               )

      cql = """
      MATCH
        (u:User)
      WHERE
        u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
        AND id(u) = $id
        AND u.uuid = $uuid
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{
        uuid: merged_node.uuid,
        firstName: "John",
        lastName: "Doe",
        viewCount: 25,
        id: merged_node.__id__
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "fail: on_create invalid changeset" do
      on_create_data = %{
        firstName: :invalid,
        lastName: "Doe",
        viewCount: 5
      }

      assert {:error, [on_create: %Seraph.Changeset{valid?: false}]} =
               TestRepo.merge(User, %{uuid: "uuid-1"},
                 on_create: {on_create_data, &User.changeset/2}
               )
    end

    test "fail: on_match invalid changeset" do
      on_match_data = %{
        firstName: "James",
        lastName: "What",
        viewCount: :invalid
      }

      assert {:error, [on_match: %Seraph.Changeset{valid?: false}]} =
               TestRepo.merge(User, %{uuid: "uuid-1"},
                 on_match: {on_match_data, &User.update_viewcount_changeset/2}
               )
    end

    test "fail: with bad args for on_create (data is not map)" do
      data = :invalid

      assert_raise ArgumentError, fn ->
        TestRepo.merge(User, %{uuid: "some-uuid"}, on_create: {data, &User.changeset/2})
      end
    end

    test "fail: with bad args for on_create (changeset fn is not a function)" do
      data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert_raise ArgumentError, fn ->
        TestRepo.merge(User, %{uuid: "some-uuid"}, on_create: {data, :invalid})
      end
    end

    test "fail: with bad args for on_create (changeset fn is not a function of arity 2)" do
      data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert_raise ArgumentError, fn ->
        TestRepo.merge(User, %{uuid: "some-uuid"}, on_create: {data, &is_nil/1})
      end
    end

    test "fail: with bad args for on_match (data is not map)" do
      data = :invalid

      assert_raise ArgumentError, fn ->
        TestRepo.merge(User, %{uuid: "some-uuid"}, on_match: {data, &User.changeset/2})
      end
    end

    test "fail: with bad args for on_match (changeset fn is not a function)" do
      data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert_raise ArgumentError, fn ->
        TestRepo.merge(User, %{uuid: "some-uuid"}, on_match: {data, :invalid})
      end
    end

    test "fail: with bad args for on_match (changeset fn is not a function of arity 2)" do
      data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      assert_raise ArgumentError, fn ->
        TestRepo.merge(User, %{uuid: "some-uuid"}, on_match: {data, &is_nil/1})
      end
    end

    test "raise: when used with !" do
      on_match_data = %{
        firstName: "James",
        lastName: "What",
        viewCount: :invalid
      }

      assert_raise Seraph.InvalidChangesetError, fn ->
        TestRepo.merge!(User, %{uuid: "uuid-1"},
          on_match: {on_match_data, &User.update_viewcount_changeset/2}
        )
      end
    end
  end

  describe "set/2" do
    test "ok" do
      data = add_fixtures()
      data_uuid = data.uuid

      assert {:ok,
              %Seraph.Test.User{
                additionalLabels: [],
                firstName: "John",
                lastName: "New name",
                uuid: ^data_uuid,
                viewCount: 3
              }} =
               TestRepo.get(User, data.uuid)
               |> User.changeset(%{lastName: "New name", viewCount: 3})
               |> TestRepo.set()
    end

    test "ok with multiple labels (add only)" do
      data = add_fixtures(%{additionalLabels: ["Buyer"]})
      data_uuid = data.uuid

      assert {:ok,
              %Seraph.Test.User{
                additionalLabels: ["Buyer", "New"],
                firstName: "John",
                lastName: "Doe",
                uuid: ^data_uuid,
                viewCount: 5
              }} =
               TestRepo.get(User, data.uuid)
               |> User.changeset(%{additionalLabels: ["Buyer", "New"]})
               |> TestRepo.set()
    end

    test "ok with multiple labels (remove only)" do
      data = add_fixtures(%{additionalLabels: ["Buyer", "Old"]})
      data_uuid = data.uuid

      assert {:ok,
              %Seraph.Test.User{
                additionalLabels: ["Old"],
                firstName: "John",
                lastName: "Doe",
                uuid: ^data_uuid,
                viewCount: 5
              }} =
               TestRepo.get(User, data.uuid)
               |> User.changeset(%{additionalLabels: ["Old"]})
               |> TestRepo.set()
    end

    test "ok with multiple labels (add + remove only)" do
      data = add_fixtures(%{additionalLabels: ["Buyer", "Old"]})
      data_uuid = data.uuid

      assert {:ok,
              %Seraph.Test.User{
                additionalLabels: ["Old", "Client"],
                firstName: "John",
                lastName: "Doe",
                uuid: ^data_uuid,
                viewCount: 5
              }} =
               TestRepo.get(User, data.uuid)
               |> User.changeset(%{additionalLabels: ["Old", "Client"]})
               |> TestRepo.set()
    end

    test "invalid changeset" do
      data = add_fixtures()

      assert {:error, %Seraph.Changeset{valid?: false}} =
               TestRepo.get(User, data.uuid)
               |> User.changeset(%{viewCount: :invalid})
               |> TestRepo.set()
    end

    test "raise when used with !" do
      data = add_fixtures()

      assert_raise Seraph.InvalidChangesetError, fn ->
        TestRepo.get(User, data.uuid)
        |> User.changeset(%{lastName: :invalid})
        |> TestRepo.set!()
      end
    end
  end

  describe "delete/1" do
    test "ok with struct" do
      data = add_fixtures()
      data_uuid = data.uuid

      assert {:ok,
              %Seraph.Test.User{
                additionalLabels: [],
                firstName: "John",
                lastName: "Doe",
                uuid: ^data_uuid,
                viewCount: 5
              }} =
               TestRepo.get(User, data.uuid)
               |> TestRepo.delete()

      cql = """
      MATCH
        (u:User)
      WHERE
        u.uuid = $uuid
        AND u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
      RETURN COUNT(u) AS nb_result
      """

      assert [%{"nb_result" => 0}] = TestRepo.query!(cql, data)
    end

    test "ok with changeset" do
      data = add_fixtures()
      data_uuid = data.uuid

      assert {:ok,
              %Seraph.Test.User{
                additionalLabels: [],
                firstName: "John",
                lastName: "Doe",
                uuid: ^data_uuid,
                viewCount: 5
              }} =
               TestRepo.get(User, data.uuid)
               |> User.changeset(%{viewCount: 34})
               |> TestRepo.delete()

      cql = """
      MATCH
        (u:User)
      WHERE
        u.uuid = $uuid
        AND u.firstName = $firstName
        AND u.lastName = $lastName
        AND u.viewCount = $viewCount
      RETURN COUNT(u) AS nb_result
      """

      assert [%{"nb_result" => 0}] = TestRepo.query!(cql, data)
    end

    test "invalid changeset" do
      data = add_fixtures()

      assert {:error, %Seraph.Changeset{valid?: false}} =
               TestRepo.get(User, data.uuid)
               |> User.changeset(%{viewCount: :invalid})
               |> TestRepo.delete()
    end

    test "raise when deleting a non exisitng node" do
      data = add_fixtures()

      user_to_del = TestRepo.get(User, data.uuid)
      TestRepo.delete(user_to_del)

      assert_raise Seraph.DeletionError, fn ->
        TestRepo.delete(user_to_del)
      end
    end

    test "raise when used with !" do
      data = add_fixtures()

      assert_raise Seraph.InvalidChangesetError, fn ->
        TestRepo.get(User, data.uuid)
        |> User.changeset(%{viewCount: :invalid})
        |> TestRepo.delete!()
      end
    end
  end

  defp add_fixtures(data \\ %{}) do
    default_data = %{
      uuid: UUID.uuid4(),
      firstName: "John",
      lastName: "Doe",
      viewCount: 5
    }

    cql = """
    CREATE
     (u:User)
    SET
      u.uuid = $uuid,
      u.firstName = $firstName,
      u.lastName = $lastName,
      u.viewCount = $viewCount
    """

    params = Map.merge(default_data, data)
    TestRepo.query!(cql, params)

    params
  end
end
