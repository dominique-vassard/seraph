defmodule Neo4jex.RepoRelationshipTest do
  use ExUnit.Case, async: true
  @moduletag :wip
  alias Neo4jex.TestRepo
  alias Neo4jex.Test.{User, Post, UserToPost.Wrote}

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

  describe "create/2" do
    test "ok with existing nodes" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      data = %{
        start_node: user,
        end_node: post
      }

      assert {:ok, rel_wrote} =
               %Wrote{}
               |> Wrote.changeset(data)
               |> TestRepo.create()

      assert %Neo4jex.Test.UserToPost.Wrote{
               type: "WROTE",
               start_node: %Neo4jex.Test.User{},
               end_node: %Neo4jex.Test.Post{}
             } = rel_wrote

      refute is_nil(rel_wrote.__id__)

      cql = """
      MATCH
        (:User {uuid: $user_uuid})-[rel:WROTE]->(:Post {uuid: $post_uuid})
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: user.uuid,
        post_uuid: post.uuid
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)

      cql = """
      MATCH
      (n)
      RETURN
      COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 2}] = TestRepo.query!(cql)
    end

    test "ok with exisiting nodes and with data" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      rel_date = DateTime.utc_now() |> DateTime.truncate(:second)

      data = %{
        start_node: user,
        end_node: post,
        at: rel_date
      }

      assert {:ok, rel_wrote} =
               %Wrote{}
               |> Wrote.changeset(data)
               |> TestRepo.create()

      assert %Neo4jex.Test.UserToPost.Wrote{
               type: "WROTE",
               at: ^rel_date,
               start_node: %Neo4jex.Test.User{},
               end_node: %Neo4jex.Test.Post{}
             } = rel_wrote

      refute is_nil(rel_wrote.__id__)

      cql = """
      MATCH
        (:User {uuid: $user_uuid})-[rel:WROTE {at: $rel_date}]->(:Post {uuid: $post_uuid})
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: user.uuid,
        post_uuid: post.uuid,
        rel_date: rel_date
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)

      cql = """
      MATCH
      (n)
      RETURN
      COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 2}] = TestRepo.query!(cql)
    end

    test "fail if changeset is provided and opt node_creation: false" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      user_data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      user =
        %User{}
        |> User.changeset(user_data)

      post_data = %{
        title: "First post",
        text: "This is the first post of all times."
      }

      post =
        %Post{}
        |> Post.changeset(post_data)

      rel_date = DateTime.utc_now() |> DateTime.truncate(:second)

      data = %{
        start_node: user,
        end_node: post
      }

      assert_raise ArgumentError, fn ->
        %Wrote{}
        |> Wrote.changeset(data)
        |> TestRepo.create()
      end
    end

    test "ok with opt node_creation: true" do
      user_data = %{
        firstName: "John",
        lastName: "Doe",
        viewCount: 5
      }

      user =
        %User{}
        |> User.changeset(user_data)

      post_data = %{
        title: "First post",
        text: "This is the first post of all times."
      }

      post =
        %Post{}
        |> Post.changeset(post_data)

      rel_date = DateTime.utc_now() |> DateTime.truncate(:second)

      data = %{
        start_node: user,
        end_node: post,
        at: rel_date
      }

      assert {:ok, rel_wrote} =
               %Wrote{}
               |> Wrote.changeset(data)
               |> TestRepo.create(node_creation: true)

      assert %Neo4jex.Test.UserToPost.Wrote{
               type: "WROTE",
               at: ^rel_date,
               start_node: %Neo4jex.Test.User{},
               end_node: %Neo4jex.Test.Post{}
             } = rel_wrote

      refute is_nil(rel_wrote.__id__)

      cql = """
      MATCH
        (:User {uuid: $user_uuid})-[rel:WROTE {at: $rel_date}]->(:Post {uuid: $post_uuid})
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: rel_wrote.start_node.uuid,
        post_uuid: rel_wrote.end_node.uuid,
        rel_date: rel_date
      }

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql, params)
    end

    test "ok - 2 creation -> 2 relationship with same data" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      rel_date = DateTime.utc_now() |> DateTime.truncate(:second)

      data = %{
        start_node: user,
        end_node: post,
        at: rel_date
      }

      changeset =
        %Wrote{}
        |> Wrote.changeset(data)

      assert {:ok, _} =
               changeset
               |> TestRepo.create()

      assert {:ok, _} =
               changeset
               |> TestRepo.create()

      cql = """
      MATCH
        (:User {uuid: $user_uuid})-[rel:WROTE {at: $rel_date}]->(:Post {uuid: $post_uuid})
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: user.uuid,
        post_uuid: post.uuid,
        rel_date: rel_date
      }

      assert [%{"nb_result" => 2}] = TestRepo.query!(cql, params)

      cql = """
      MATCH
      (n)
      RETURN
      COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 2}] = TestRepo.query!(cql)
    end

    test "invalid changeset" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      data = %{
        start_node: user,
        end_node: post,
        at: :invalid
      }

      assert {:error, %Ecto.Changeset{valid?: false}} =
               %Wrote{}
               |> Wrote.changeset(data)
               |> TestRepo.create()
    end

    test "raise when used with bang version" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      data = %{
        start_node: user,
        end_node: post,
        at: :invalid
      }

      assert_raise Neo4jex.InvalidChangesetError, fn ->
        %Wrote{}
        |> Wrote.changeset(data)
        |> TestRepo.create!()
      end
    end
  end

  describe "merge/2" do
    test "ok"
    test "ok with data"
    test "ok with node creation"
    test "ok - 2 creation -> 1 relationship only"
    test "invalid changeset"
    test "raise when used with bang version"
  end

  describe "set/1" do
    test "ok new start"
    test "ok new end"
    test "ok new start / new end"
    test "ok with data"
    test "ok "
    test "invalid changeset"
    test "raise when used with bang version"
  end

  defp add_fixtures(fixture_type, data \\ %{})

  defp add_fixtures(:start_node, data) do
    default_data = %{
      firstName: "John",
      lastName: "Doe",
      viewCount: 5
    }

    %User{}
    |> User.changeset(Map.merge(default_data, data))
    |> TestRepo.create!()
  end

  defp add_fixtures(:end_node, data) do
    default_data = %{
      title: "First post",
      text: "This is the first post of all times."
    }

    %Post{}
    |> Post.changeset(Map.merge(default_data, data))
    |> TestRepo.create!()
  end
end
