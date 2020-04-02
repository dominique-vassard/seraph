defmodule Neo4jex.RepoRelationshipTest do
  use ExUnit.Case, async: false
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

  describe "create/3" do
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

    test "ok with existing nodes and with data" do
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
      add_fixtures(:start_node)
      add_fixtures(:end_node)

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

  describe "merge/3" do
    test "ok with existing node" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      data = %{
        start_node: user,
        end_node: post
      }

      assert {:ok, rel_wrote} =
               %Wrote{}
               |> Wrote.changeset(data)
               |> TestRepo.merge()

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

    test "ok: with data" do
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
               |> TestRepo.merge()

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
      add_fixtures(:start_node)
      add_fixtures(:end_node)

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

      data = %{
        start_node: user,
        end_node: post
      }

      assert_raise ArgumentError, fn ->
        %Wrote{}
        |> Wrote.changeset(data)
        |> TestRepo.merge()
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
               |> TestRepo.merge(node_creation: true)

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
               |> TestRepo.merge()

      assert {:ok, _} =
               changeset
               |> TestRepo.merge()

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
               |> TestRepo.merge()
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
        |> TestRepo.merge!()
      end
    end
  end

  describe "set/2" do
    test "ok with data" do
      relationship = add_fixtures(:relationship)

      {:ok, new_rel_date_long, _} = DateTime.from_iso8601("2015-01-23T23:50:07Z")

      new_rel_date = DateTime.truncate(new_rel_date_long, :second)

      new_data = %{
        at: new_rel_date
      }

      assert {:ok, updated_rel} =
               relationship
               |> Wrote.changeset(new_data)
               |> TestRepo.set()

      assert DateTime.truncate(updated_rel.at, :second) == new_rel_date

      cql = """
      MATCH
        (:User {uuid: $user_uuid})-[rel:WROTE {at: $rel_date}]->(:Post {uuid: $post_uuid})
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: relationship.start_node.uuid,
        post_uuid: relationship.end_node.uuid,
        rel_date: new_rel_date
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

    test "ok new start" do
      relationship = add_fixtures(:relationship)

      new_user_data = %{
        firstName: "James",
        lastName: "Who",
        viewCount: 0
      }

      new_user = add_fixtures(:start_node, new_user_data)

      assert {:ok, updated_rel} =
               relationship
               |> Wrote.changeset(%{start_node: new_user})
               |> TestRepo.set()

      assert %Neo4jex.Test.UserToPost.Wrote{
               end_node: %Neo4jex.Test.Post{
                 text: "This is the first post of all times.",
                 title: "First post"
               },
               start_node: %Neo4jex.Test.User{
                 firstName: "James",
                 lastName: "Who"
               },
               type: "WROTE"
             } = updated_rel

      cql = """
      MATCH
        (old_start:User {uuid: $old_user_uuid}),
        (new_start:User {uuid: $new_user_uuid}),
        (post:Post {uuid: $post_uuid}),
        (new_start)-[new_rel:WROTE]->(post)
        OPTIONAL MATCH
        (old_start)-[old_rel:WROTE]->(post)
      RETURN
        COUNT (new_rel) AS nb_new_rel,
        COUNT (old_rel) AS nb_old_rel
      """

      params = %{
        old_user_uuid: relationship.start_node.uuid,
        new_user_uuid: new_user.uuid,
        post_uuid: relationship.end_node.uuid
      }

      assert [%{"nb_new_rel" => 1, "nb_old_rel" => 0}] = TestRepo.query!(cql, params)

      cql = """
      MATCH
      (n)
      RETURN
      COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 3}] = TestRepo.query!(cql)
    end

    test "ok new end" do
      relationship = add_fixtures(:relationship)

      new_post_data = %{
        text: "This is the new post.",
        title: "New post"
      }

      new_post = add_fixtures(:end_node, new_post_data)

      assert {:ok, updated_rel} =
               relationship
               |> Wrote.changeset(%{end_node: new_post})
               |> TestRepo.set()

      assert %Neo4jex.Test.UserToPost.Wrote{
               end_node: %Neo4jex.Test.Post{
                 text: "This is the new post.",
                 title: "New post"
               },
               start_node: %Neo4jex.Test.User{
                 firstName: "John",
                 lastName: "Doe",
                 viewCount: 5
               },
               type: "WROTE"
             } = updated_rel

      cql = """
      MATCH
        (start:User {uuid: $user_uuid}),
        (old_end:Post {uuid: $old_end_uuid}),
        (new_end:Post {uuid: $new_end_uuid}),
        (start)-[new_rel:WROTE]->(new_end)
        OPTIONAL MATCH
        (start)-[old_rel:WROTE]->(old_end)
      RETURN
        COUNT (new_rel) AS nb_new_rel,
        COUNT (old_rel) AS nb_old_rel
      """

      params = %{
        user_uuid: relationship.start_node.uuid,
        old_end_uuid: relationship.end_node.uuid,
        new_end_uuid: new_post.uuid
      }

      assert [%{"nb_new_rel" => 1, "nb_old_rel" => 0}] = TestRepo.query!(cql, params)

      cql = """
      MATCH
      (n)
      RETURN
      COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 3}] = TestRepo.query!(cql)
    end

    test "ok new start / new end" do
      relationship = add_fixtures(:relationship)

      new_post_data = %{
        text: "This is the new post.",
        title: "New post"
      }

      new_post = add_fixtures(:end_node, new_post_data)

      new_user_data = %{
        firstName: "James",
        lastName: "Who",
        viewCount: 0
      }

      new_user = add_fixtures(:start_node, new_user_data)

      assert {:ok, updated_rel} =
               relationship
               |> Wrote.changeset(%{start_node: new_user, end_node: new_post})
               |> TestRepo.set()

      assert %Neo4jex.Test.UserToPost.Wrote{
               end_node: %Neo4jex.Test.Post{
                 text: "This is the new post.",
                 title: "New post"
               },
               start_node: %Neo4jex.Test.User{
                 firstName: "James",
                 lastName: "Who"
               },
               type: "WROTE"
             } = updated_rel

      cql = """
      MATCH
        (old_start:User {uuid: $old_start_uuid}),
        (new_start:User {uuid: $new_start_uuid}),
        (old_end:Post {uuid: $old_end_uuid}),
        (new_end:Post {uuid: $new_end_uuid}),
        (new_start)-[new_rel:WROTE]->(new_end)
        OPTIONAL MATCH
        (old_start)-[old_rel:WROTE]->(old_end)
      RETURN
        COUNT (new_rel) AS nb_new_rel,
        COUNT (old_rel) AS nb_old_rel
      """

      params = %{
        old_start_uuid: relationship.start_node.uuid,
        new_start_uuid: new_user.uuid,
        old_end_uuid: relationship.end_node.uuid,
        new_end_uuid: new_post.uuid
      }

      assert [%{"nb_new_rel" => 1, "nb_old_rel" => 0}] = TestRepo.query!(cql, params)

      cql = """
      MATCH
      (n)
      RETURN
      COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 4}] = TestRepo.query!(cql)
    end

    test "ok with node creation: start node" do
      relationship = add_fixtures(:relationship)

      new_user_data = %{
        firstName: "James",
        lastName: "Who",
        viewCount: 0
      }

      new_user_cs = User.changeset(%User{}, new_user_data)

      assert {:ok, updated_rel} =
               relationship
               |> Wrote.changeset(%{start_node: new_user_cs})
               |> TestRepo.set(node_creation: true)

      assert %Neo4jex.Test.UserToPost.Wrote{
               end_node: %Neo4jex.Test.Post{
                 text: "This is the first post of all times.",
                 title: "First post"
               },
               start_node: %Neo4jex.Test.User{
                 firstName: "James",
                 lastName: "Who"
               },
               type: "WROTE"
             } = updated_rel

      cql = """
      MATCH
        (old_start:User {uuid: $old_user_uuid}),
        (new_start:User {firstName: $new_start_first_name, lastName: $new_start_last_name}),
        (post:Post {uuid: $post_uuid}),
        (new_start)-[new_rel:WROTE]->(post)
        OPTIONAL MATCH
        (old_start)-[old_rel:WROTE]->(post)
      RETURN
        COUNT (new_rel) AS nb_new_rel,
        COUNT (old_rel) AS nb_old_rel
      """

      params = %{
        old_user_uuid: relationship.start_node.uuid,
        new_start_first_name: new_user_data.firstName,
        new_start_last_name: new_user_data.lastName,
        post_uuid: relationship.end_node.uuid
      }

      assert [%{"nb_new_rel" => 1, "nb_old_rel" => 0}] = TestRepo.query!(cql, params)

      cql = """
      MATCH
      (n)
      RETURN
      COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 3}] = TestRepo.query!(cql)
    end

    test "ok with node creation: end node" do
      relationship = add_fixtures(:relationship)

      new_post_data = %{
        text: "This is the new post.",
        title: "New post"
      }

      new_post_cs = Post.changeset(%Post{}, new_post_data)

      assert {:ok, updated_rel} =
               relationship
               |> Wrote.changeset(%{end_node: new_post_cs})
               |> TestRepo.set(node_creation: true)

      assert %Neo4jex.Test.UserToPost.Wrote{
               end_node: %Neo4jex.Test.Post{
                 text: "This is the new post.",
                 title: "New post"
               },
               start_node: %Neo4jex.Test.User{
                 firstName: "John",
                 lastName: "Doe",
                 viewCount: 5
               },
               type: "WROTE"
             } = updated_rel

      cql = """
      MATCH
        (start:User {uuid: $user_uuid}),
        (old_end:Post {uuid: $old_end_uuid}),
        (new_end:Post {title: $new_end_title, text: $new_end_text}),
        (start)-[new_rel:WROTE]->(new_end)
        OPTIONAL MATCH
        (start)-[old_rel:WROTE]->(old_end)
      RETURN
        COUNT (new_rel) AS nb_new_rel,
        COUNT (old_rel) AS nb_old_rel
      """

      params = %{
        user_uuid: relationship.start_node.uuid,
        old_end_uuid: relationship.end_node.uuid,
        new_end_text: new_post_data.text,
        new_end_title: new_post_data.title
      }

      assert [%{"nb_new_rel" => 1, "nb_old_rel" => 0}] = TestRepo.query!(cql, params)

      cql = """
      MATCH
      (n)
      RETURN
      COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 3}] = TestRepo.query!(cql)
    end

    test "ok with node creation: start node and end node" do
      relationship = add_fixtures(:relationship)

      new_user_data = %{
        firstName: "James",
        lastName: "Who",
        viewCount: 0
      }

      new_user_cs = User.changeset(%User{}, new_user_data)

      new_post_data = %{
        text: "This is the new post.",
        title: "New post"
      }

      new_post_cs = Post.changeset(%Post{}, new_post_data)

      assert {:ok, updated_rel} =
               relationship
               |> Wrote.changeset(%{start_node: new_user_cs, end_node: new_post_cs})
               |> TestRepo.set(node_creation: true)

      assert %Neo4jex.Test.UserToPost.Wrote{
               end_node: %Neo4jex.Test.Post{
                 text: "This is the new post.",
                 title: "New post"
               },
               start_node: %Neo4jex.Test.User{
                 firstName: "James",
                 lastName: "Who"
               },
               type: "WROTE"
             } = updated_rel

      cql = """
      MATCH
        (old_start:User {uuid: $old_start_uuid}),
        (new_start:User {firstName: $new_start_first_name, lastName: $new_start_last_name}),
        (old_end:Post {uuid: $old_end_uuid}),
        (new_end:Post {title: $new_end_title, text: $new_end_text}),
        (new_start)-[new_rel:WROTE]->(new_end)
        OPTIONAL MATCH
        (old_start)-[old_rel:WROTE]->(old_end)
      RETURN
        COUNT (new_rel) AS nb_new_rel,
        COUNT (old_rel) AS nb_old_rel
      """

      params = %{
        old_start_uuid: relationship.start_node.uuid,
        new_start_first_name: new_user_data.firstName,
        new_start_last_name: new_user_data.lastName,
        old_end_uuid: relationship.end_node.uuid,
        new_end_text: new_post_data.text,
        new_end_title: new_post_data.title
      }

      assert [%{"nb_new_rel" => 1, "nb_old_rel" => 0}] = TestRepo.query!(cql, params)

      cql = """
      MATCH
      (n)
      RETURN
      COUNT(n) AS nb_result
      """

      assert [%{"nb_result" => 4}] = TestRepo.query!(cql)
    end

    test "invalid changeset" do
      relationship = add_fixtures(:relationship)

      assert {:error, %Ecto.Changeset{valid?: false}} =
               relationship
               |> Wrote.changeset(%{start_node: :invalid})
               |> TestRepo.set()
    end

    test "raise when used with bang version" do
      relationship = add_fixtures(:relationship)

      assert_raise Neo4jex.InvalidChangesetError, fn ->
        relationship
        |> Wrote.changeset(%{start_node: :invalid})
        |> TestRepo.set!()
      end
    end
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

  defp add_fixtures(:relationship, data) do
    user = add_fixtures(:start_node)
    post = add_fixtures(:end_node)

    rel_date = DateTime.utc_now() |> DateTime.truncate(:second)

    default_data = %{
      start_node: user,
      end_node: post,
      at: rel_date
    }

    %Wrote{}
    |> Wrote.changeset(Map.merge(default_data, data))
    |> TestRepo.create!()
  end
end
