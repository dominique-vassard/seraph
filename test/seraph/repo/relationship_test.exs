defmodule Seraph.Repo.RelationshipTest do
  use ExUnit.Case, async: false
  alias Seraph.TestRepo
  alias Seraph.Test.{User, Post, UserToPost.Wrote}

  setup do
    TestRepo.query!("MATCH (n) DETACH DELETE n", %{}, with_stats: true)

    Seraph.Support.Storage.clear(TestRepo)

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
               |> TestRepo.Relationship.create()

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
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
               |> TestRepo.Relationship.create()

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               #  at: ^rel_date,
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
             } = rel_wrote

      assert rel_date == DateTime.truncate(rel_wrote.at, :second)

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
        rel_date: rel_wrote.at
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
        |> TestRepo.Relationship.create()
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
               |> TestRepo.Relationship.create(node_creation: true)

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               #  at: ^rel_date,
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
             } = rel_wrote

      assert rel_date == DateTime.truncate(rel_wrote.at, :second)
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
        rel_date: rel_wrote.at
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
               |> TestRepo.Relationship.create()

      assert {:ok, _} =
               changeset
               |> TestRepo.Relationship.create()

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

    test "fails: with invalid changeset" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      data = %{
        start_node: user,
        end_node: post,
        at: :invalid
      }

      assert {:error, %Seraph.Changeset{valid?: false}} =
               %Wrote{}
               |> Wrote.changeset(data)
               |> TestRepo.Relationship.create()
    end

    test "fails: with invalid data" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      data = %Wrote{
        start_node: user,
        end_node: post,
        at: :invalid
      }

      assert {:error, %Seraph.Changeset{valid?: false}} = TestRepo.Relationship.create(data)
    end

    test "raise when used with bang version" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      data = %{
        start_node: user,
        end_node: post,
        at: :invalid
      }

      assert_raise Seraph.InvalidChangesetError, fn ->
        %Wrote{}
        |> Wrote.changeset(data)
        |> TestRepo.Relationship.create!()
      end
    end
  end

  describe "merge/2" do
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
               |> TestRepo.Relationship.merge()

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
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
               |> TestRepo.Relationship.merge()

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               #  at: ^rel_date,
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
             } = rel_wrote

      refute is_nil(rel_wrote.__id__)
      assert rel_date == rel_wrote.at |> DateTime.truncate(:second)

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
        |> TestRepo.Relationship.merge()
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
               |> TestRepo.Relationship.merge(node_creation: true)

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               #  at: ^rel_date,
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
             } = rel_wrote

      refute is_nil(rel_wrote.__id__)
      assert rel_date == rel_wrote.at |> DateTime.truncate(:second)

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
               |> TestRepo.Relationship.merge()

      assert {:ok, _} =
               changeset
               |> TestRepo.Relationship.merge()

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

      assert {:error, %Seraph.Changeset{valid?: false}} =
               %Wrote{}
               |> Wrote.changeset(data)
               |> TestRepo.Relationship.merge()
    end

    test "fails: invalid data" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      data = %Wrote{
        start_node: user,
        end_node: post,
        at: :invalid
      }

      assert {:error, %Seraph.Changeset{valid?: false}} = TestRepo.Relationship.merge(data)
    end

    test "raise when used with bang version" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      data = %{
        start_node: user,
        end_node: post,
        at: :invalid
      }

      assert_raise Seraph.InvalidChangesetError, fn ->
        %Wrote{}
        |> Wrote.changeset(data)
        |> TestRepo.Relationship.merge!()
      end
    end
  end

  describe "merge/4" do
    test "ok: on_create opt (existing -> no change)" do
      old_rel = add_fixtures(:relationship)

      date = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, rel_wrote} =
               TestRepo.Relationship.merge(Wrote, old_rel.start_node, old_rel.end_node,
                 on_create: {%{at: date}, &Wrote.changeset/2}
               )

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
             } = rel_wrote

      refute is_nil(rel_wrote.__id__)

      cql = """
      MATCH
        (:User {uuid: $user_uuid})-[rel:WROTE]->(:Post {uuid: $post_uuid})
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: old_rel.start_node.uuid,
        post_uuid: old_rel.end_node.uuid
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

    test "ok: on_create opt (not existing -> creation)" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      assert {:ok, rel_wrote} =
               TestRepo.Relationship.merge(Wrote, user, post, on_create: {%{}, &Wrote.changeset/2})

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
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

    test "ok: on_match opt (existing -> update)" do
      old_rel = add_fixtures(:relationship)

      {:ok, date, _} = DateTime.from_iso8601("2015-01-23T23:50:07Z")

      assert {:ok, rel_wrote} =
               TestRepo.Relationship.merge(Wrote, old_rel.start_node, old_rel.end_node,
                 on_match: {%{at: DateTime.truncate(date, :second)}, &Wrote.changeset/2}
               )

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
             } = rel_wrote

      refute is_nil(rel_wrote.__id__)

      cql = """
      MATCH
        (:User {uuid: $user_uuid})-[rel:WROTE {at: $rel_date}]->(:Post {uuid: $post_uuid})
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: old_rel.start_node.uuid,
        post_uuid: old_rel.end_node.uuid,
        rel_date: DateTime.truncate(date, :second)
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

    test "ok: on_create opt (not existing -> no change)" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      {:ok, date, _} = DateTime.from_iso8601("2015-01-23T23:50:07Z")

      assert {:ok, rel_wrote} =
               TestRepo.Relationship.merge(Wrote, user, post,
                 on_match: {%{at: DateTime.truncate(date, :second)}, &Wrote.changeset/2}
               )

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
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
        rel_date: DateTime.truncate(date, :second)
      }

      assert [%{"nb_result" => 0}] = TestRepo.query!(cql, params)
    end

    test "ok: on_create + on_match opts (existing -> update)" do
      old_rel = add_fixtures(:relationship)

      {:ok, date, _} = DateTime.from_iso8601("2015-01-23T23:50:07Z")
      create_date = DateTime.utc_now() |> DateTime.truncate(:second)
      match_date = DateTime.truncate(date, :second)

      assert {:ok, rel_wrote} =
               TestRepo.Relationship.merge(Wrote, old_rel.start_node, old_rel.end_node,
                 on_create: {%{at: create_date}, &Wrote.changeset/2},
                 on_match: {%{at: match_date}, &Wrote.changeset/2}
               )

      cql = """
      MATCH
        (:User {uuid: $user_uuid})-[rel:WROTE {at: $rel_date}]->(:Post {uuid: $post_uuid})
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: old_rel.start_node.uuid,
        post_uuid: old_rel.end_node.uuid,
        rel_date: match_date
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

    test "ok: on_create + on_match opts (not existing -> creation)" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      {:ok, date, _} = DateTime.from_iso8601("2015-01-23T23:50:07Z")
      create_date = DateTime.utc_now() |> DateTime.truncate(:second)
      match_date = DateTime.truncate(date, :second)

      assert {:ok, rel_wrote} =
               TestRepo.Relationship.merge(Wrote, user, post,
                 on_create: {%{at: create_date}, &Wrote.changeset/2},
                 on_match: {%{at: match_date}, &Wrote.changeset/2}
               )

      cql = """
      MATCH
        (:User {uuid: $user_uuid})-[rel:WROTE {at: $rel_date}]->(:Post {uuid: $post_uuid})
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: user.uuid,
        post_uuid: post.uuid,
        rel_date: rel_wrote.at
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

    test "ok: no_data opts " do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      assert {:ok, rel_wrote} = TestRepo.Relationship.merge(Wrote, user, post, no_data: true)

      assert %Seraph.Test.UserToPost.Wrote{
               type: "WROTE",
               start_node: %Seraph.Test.User{},
               end_node: %Seraph.Test.Post{}
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

    test "fail: on_create invalid changeset" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      assert {:error, [on_create: %Seraph.Changeset{valid?: false}]} =
               TestRepo.Relationship.merge(Wrote, user, post,
                 on_create: {%{at: :invalid}, &Wrote.changeset/2}
               )
    end

    test "fail: on_match invalid changeset" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      assert {:error, [on_match: %Seraph.Changeset{valid?: false}]} =
               TestRepo.Relationship.merge(Wrote, user, post,
                 on_match: {%{at: :invalid}, &Wrote.changeset/2}
               )
    end

    test "raise: when used with !" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      assert_raise Seraph.InvalidChangesetError, fn ->
        TestRepo.Relationship.merge!(Wrote, user, post,
          on_match: {%{at: :invalid}, &Wrote.changeset/2}
        )
      end
    end
  end

  describe "get/3" do
    test "ok: with structs only" do
      relationship = add_fixtures(:relationship)

      retrieved = TestRepo.Relationship.get(Wrote, relationship.start_node, relationship.end_node)

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This is the first post of all times.",
                 title: "First post"
               },
               start_node: %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "John",
                 lastName: "Doe",
                 viewCount: 5
               },
               type: "WROTE"
             } = retrieved

      refute is_nil(retrieved.__id__)
      refute is_nil(retrieved.at)
      refute is_nil(retrieved.start_node.__id__)
      refute is_nil(retrieved.start_node.uuid)
      refute is_nil(retrieved.end_node.__id__)
      refute is_nil(retrieved.end_node.uuid)
    end

    test "ok: with data only" do
      relationship = add_fixtures(:relationship)

      start_data = %{
        firstName: relationship.start_node.firstName,
        lastName: relationship.start_node.lastName
      }

      end_data = %{
        title: relationship.end_node.title
      }

      retrieved = TestRepo.Relationship.get(Wrote, start_data, end_data)

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This is the first post of all times.",
                 title: "First post"
               },
               start_node: %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "John",
                 lastName: "Doe",
                 viewCount: 5
               },
               type: "WROTE"
             } = retrieved

      refute is_nil(retrieved.__id__)
      refute is_nil(retrieved.at)
      refute is_nil(retrieved.start_node.__id__)
      refute is_nil(retrieved.start_node.uuid)
      refute is_nil(retrieved.end_node.__id__)
      refute is_nil(retrieved.end_node.uuid)
    end

    test "ok: mixed struct and data" do
      relationship = add_fixtures(:relationship)

      end_data = %{
        title: relationship.end_node.title
      }

      retrieved = TestRepo.Relationship.get(Wrote, relationship.start_node, end_data)

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This is the first post of all times.",
                 title: "First post"
               },
               start_node: %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "John",
                 lastName: "Doe",
                 viewCount: 5
               },
               type: "WROTE"
             } = retrieved

      refute is_nil(retrieved.__id__)
      refute is_nil(retrieved.at)
      refute is_nil(retrieved.start_node.__id__)
      refute is_nil(retrieved.start_node.uuid)
      refute is_nil(retrieved.end_node.__id__)
      refute is_nil(retrieved.end_node.uuid)
    end

    test "ok: return nil when no relationship found" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      start_data = %{
        firstName: user.firstName,
        lastName: user.lastName
      }

      end_data = %{
        title: post.title
      }

      assert nil == TestRepo.Relationship.get(Wrote, start_data, end_data)
    end

    test "raise: when more than one result" do
      relationship = add_fixtures(:relationship)

      cql = """
      MATCH
        (user:User {uuid: $user_uuid}),
        (post:Post {uuid: $post_uuid})
      CREATE
        (user)-[:WROTE]->(post)
      """

      params = %{
        user_uuid: relationship.start_node.uuid,
        post_uuid: relationship.end_node.uuid
      }

      TestRepo.query!(cql, params)

      assert_raise Seraph.MultipleRelationshipsError, fn ->
        TestRepo.Relationship.get(Wrote, relationship.start_node, relationship.end_node)
      end
    end

    test "raise: when used with !" do
      user = add_fixtures(:start_node)
      post = add_fixtures(:end_node)

      start_data = %{
        firstName: user.firstName,
        lastName: user.lastName
      }

      end_data = %{
        title: post.title
      }

      assert_raise Seraph.NoResultsError, fn ->
        TestRepo.Relationship.get!(Wrote, start_data, end_data)
      end
    end
  end

  describe "get_by/5" do
    test "ok: without rel clause" do
      add_fixtures(:relationship)

      retrieved =
        TestRepo.Relationship.get_by(Wrote, %{firstName: "John"}, %{title: "First post"})

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This is the first post of all times.",
                 title: "First post"
               },
               start_node: %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "John",
                 lastName: "Doe",
                 viewCount: 5
               },
               type: "WROTE"
             } = retrieved

      refute is_nil(retrieved.__id__)
      refute is_nil(retrieved.at)
      refute is_nil(retrieved.start_node.__id__)
      refute is_nil(retrieved.start_node.uuid)
      refute is_nil(retrieved.end_node.__id__)
      refute is_nil(retrieved.end_node.uuid)
    end

    test "ok: with rel clause" do
      add_fixtures(:relationship)
      {:ok, datetime, _} = DateTime.from_iso8601("2015-01-23T23:50:07Z")
      new_date = DateTime.truncate(datetime, :second)
      add_fixtures(:relationship, %{at: new_date})

      retrieved =
        TestRepo.Relationship.get_by(Wrote, %{firstName: "John"}, %{title: "First post"}, %{
          at: new_date
        })

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This is the first post of all times.",
                 title: "First post"
               },
               start_node: %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "John",
                 lastName: "Doe",
                 viewCount: 5
               },
               type: "WROTE"
             } = retrieved

      refute is_nil(retrieved.__id__)
      refute is_nil(retrieved.at)
      assert DateTime.truncate(retrieved.at, :second) == new_date
      refute is_nil(retrieved.start_node.__id__)
      refute is_nil(retrieved.start_node.uuid)
      refute is_nil(retrieved.end_node.__id__)
      refute is_nil(retrieved.end_node.uuid)
    end

    test "ok: return nil when no relationship found" do
      assert is_nil(
               TestRepo.Relationship.get_by(Wrote, %{firstName: "Inexistent"}, %{
                 firstName: "Noone"
               })
             )
    end

    test "raise: when more than one result" do
      add_fixtures(:relationship)
      add_fixtures(:relationship)

      assert_raise Seraph.MultipleRelationshipsError, fn ->
        TestRepo.Relationship.get_by(Wrote, %{firstName: "John"}, %{title: "First post"})
      end
    end

    test "raise: when used with !" do
      %{firstName: "Noone"}

      assert_raise Seraph.NoResultsError, fn ->
        TestRepo.Relationship.get_by!(Wrote, %{firstName: "Inexistent"}, %{firstName: "Noone"})
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
               |> TestRepo.Relationship.set()

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
               |> TestRepo.Relationship.set()

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 text: "This is the first post of all times.",
                 title: "First post"
               },
               start_node: %Seraph.Test.User{
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
        (new_start)-[new_rel:WROTE {at: $at}]->(post)
        OPTIONAL MATCH
        (old_start)-[old_rel:WROTE]->(post)
      RETURN
        COUNT (new_rel) AS nb_new_rel,
        COUNT (old_rel) AS nb_old_rel
      """

      params = %{
        old_user_uuid: relationship.start_node.uuid,
        new_user_uuid: new_user.uuid,
        post_uuid: relationship.end_node.uuid,
        at: relationship.at
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
               |> TestRepo.Relationship.set()

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 text: "This is the new post.",
                 title: "New post"
               },
               start_node: %Seraph.Test.User{
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
               |> TestRepo.Relationship.set()

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 text: "This is the new post.",
                 title: "New post"
               },
               start_node: %Seraph.Test.User{
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
               |> TestRepo.Relationship.set(node_creation: true)

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 text: "This is the first post of all times.",
                 title: "First post"
               },
               start_node: %Seraph.Test.User{
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
               |> TestRepo.Relationship.set(node_creation: true)

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 text: "This is the new post.",
                 title: "New post"
               },
               start_node: %Seraph.Test.User{
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
               |> TestRepo.Relationship.set(node_creation: true)

      assert %Seraph.Test.UserToPost.Wrote{
               end_node: %Seraph.Test.Post{
                 text: "This is the new post.",
                 title: "New post"
               },
               start_node: %Seraph.Test.User{
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

      assert {:error, %Seraph.Changeset{valid?: false}} =
               relationship
               |> Wrote.changeset(%{start_node: :invalid})
               |> TestRepo.Relationship.set()
    end

    test "raise: when relationship to set is not found" do
      relationship = add_fixtures(:relationship)

      {:ok, new_rel_date_long, _} = DateTime.from_iso8601("2015-01-23T23:50:07Z")

      new_rel_date = DateTime.truncate(new_rel_date_long, :second)

      new_data = %{
        at: new_rel_date
      }

      cql = """
      MATCH
        (start:User {uuid: $start_uuid}),
        (end:Post {uuid: $end_uuid}),
        (start)-[rel:WROTE]->(end)
        DELETE
          rel
      """

      params = %{
        start_uuid: relationship.start_node.uuid,
        end_uuid: relationship.end_node.uuid
      }

      TestRepo.query!(cql, params)

      assert_raise Seraph.StaleEntryError, fn ->
        relationship
        |> Wrote.changeset(new_data)
        |> TestRepo.Relationship.set()
      end
    end

    test "raise when used with bang version" do
      relationship = add_fixtures(:relationship)

      assert_raise Seraph.InvalidChangesetError, fn ->
        relationship
        |> Wrote.changeset(%{start_node: :invalid})
        |> TestRepo.Relationship.set!()
      end
    end
  end

  describe "delete/1" do
    test "ok: with struct" do
      relationship = add_fixtures(:relationship)

      assert {:ok,
              %Seraph.Test.UserToPost.Wrote{
                end_node: %Seraph.Test.Post{
                  additionalLabels: [],
                  text: "This is the first post of all times.",
                  title: "First post"
                },
                start_node: %Seraph.Test.User{
                  additionalLabels: [],
                  firstName: "John",
                  lastName: "Doe",
                  viewCount: 5
                },
                type: "WROTE"
              }} = TestRepo.Relationship.delete(relationship)

      cql = """
      MATCH
        (start:User {uuid: $start_uuid}),
        (end:Post {uuid: $end_uuid}),
        (start)-[rel:WROTE]->(end)
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        start_uuid: relationship.start_node.uuid,
        end_uuid: relationship.end_node.uuid
      }

      assert [%{"nb_result" => 0}] = TestRepo.query!(cql, params)
    end

    test "ok: with changeset" do
      relationship = add_fixtures(:relationship)

      {:ok, new_rel_date_long, _} = DateTime.from_iso8601("2015-01-23T23:50:07Z")

      new_rel_date = DateTime.truncate(new_rel_date_long, :second)

      assert {:ok,
              %Seraph.Test.UserToPost.Wrote{
                end_node: %Seraph.Test.Post{
                  additionalLabels: [],
                  text: "This is the first post of all times.",
                  title: "First post"
                },
                start_node: %Seraph.Test.User{
                  additionalLabels: [],
                  firstName: "John",
                  lastName: "Doe",
                  viewCount: 5
                },
                type: "WROTE"
              }} =
               relationship
               |> Wrote.changeset(%{at: new_rel_date})
               |> TestRepo.Relationship.delete()

      cql = """
      MATCH
        (start:User {uuid: $start_uuid}),
        (end:Post {uuid: $end_uuid}),
        (start)-[rel:WROTE]->(end)
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        start_uuid: relationship.start_node.uuid,
        end_uuid: relationship.end_node.uuid
      }

      assert [%{"nb_result" => 0}] = TestRepo.query!(cql, params)
    end

    test "fail: invalid changeset" do
      relationship = add_fixtures(:relationship)

      assert {:error, %Seraph.Changeset{valid?: false}} =
               relationship
               |> Wrote.changeset(%{at: :invalid})
               |> TestRepo.Relationship.delete()
    end

    test "raise: deleting non existing relationship" do
      relationship = add_fixtures(:relationship)

      new_post_data = %{
        text: "This is the new post.",
        title: "New post"
      }

      new_post = add_fixtures(:end_node, new_post_data)

      assert_raise Seraph.DeletionError, fn ->
        relationship
        |> Map.put(:end_node, new_post)
        |> TestRepo.Relationship.delete()
      end
    end

    test "raise: used with !" do
      relationship = add_fixtures(:relationship)

      assert_raise Seraph.InvalidChangesetError, fn ->
        relationship
        |> Wrote.changeset(%{at: :invalid})
        |> TestRepo.Relationship.delete!()
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
    |> TestRepo.Node.create!()
  end

  defp add_fixtures(:end_node, data) do
    default_data = %{
      title: "First post",
      text: "This is the first post of all times."
    }

    %Post{}
    |> Post.changeset(Map.merge(default_data, data))
    |> TestRepo.Node.create!()
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

    rel =
      %Wrote{}
      |> Wrote.changeset(Map.merge(default_data, data))
      |> TestRepo.Relationship.create!()

    Map.put(rel, :at, DateTime.truncate(rel.at, :second))
  end
end
