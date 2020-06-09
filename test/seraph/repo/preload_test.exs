defmodule Seraph.Repo.PreloadTest do
  use ExUnit.Case, async: false

  alias Seraph.Support.Storage

  alias Seraph.TestRepo
  alias Seraph.Test.{Post, User}

  setup_all do
    Storage.clear(TestRepo)
    Storage.add_fixtures(TestRepo)
  end

  describe "preload single relationship" do
    test ":one / :outgoing / no result", %{uuids: uuids} do
      assert %User{admin_badge: nil, is_a: nil} =
               TestRepo.Node.get(User, uuids.user3)
               |> TestRepo.Node.preload(:is_a)
    end

    test ":one / :outgoing / one result", %{uuids: uuids} do
      assert %User{admin_badge: admin_badge, is_a: admin_rel} =
               TestRepo.Node.get(User, uuids.user2)
               |> TestRepo.Node.preload(:is_a)

      assert %Seraph.Test.Admin{} = admin_badge

      assert %Seraph.Test.NoPropsRels.UserToAdmin.IsA{
               end_node: %Seraph.Test.Admin{},
               start_node: %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "James",
                 lastName: "Who",
                 viewCount: 0
               },
               type: "IS_A"
             } = admin_rel
    end

    test ":one / :outgoing / many result", %{uuids: uuids} do
      assert_raise Seraph.Exception, fn ->
        TestRepo.Node.get(User, uuids.user1)
        |> TestRepo.Node.preload(:is_a)
      end
    end

    test ":many / :outgoing / no result", %{uuids: uuids} do
      assert %User{read_posts: [], read: []} =
               TestRepo.Node.get(User, uuids.user3)
               |> TestRepo.Node.preload(:read)
    end

    test ":many / :outgoing / one result", %{uuids: uuids} do
      assert %User{read_posts: read_posts, read: read_rels} =
               TestRepo.Node.get(User, uuids.user1)
               |> TestRepo.Node.preload(:read)

      assert [
               %Seraph.Test.NoPropsRels.UserToPost.Read{
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 1",
                   title: "post1"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "John",
                   lastName: "Doe",
                   viewCount: 0
                 },
                 type: "READ"
               }
             ] = read_rels

      assert [
               %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This post 1",
                 title: "post1"
               }
             ] = read_posts
    end

    test ":many / :outgoing / many result", %{uuids: uuids} do
      assert %User{read_posts: read_posts, read: read_rels} =
               TestRepo.Node.get(User, uuids.user2)
               |> TestRepo.Node.preload(:read)

      assert [
               %Seraph.Test.NoPropsRels.UserToPost.Read{
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 1",
                   title: "post1"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 },
                 type: "READ"
               },
               %Seraph.Test.NoPropsRels.UserToPost.Read{
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 2",
                   title: "post2"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 },
                 type: "READ"
               },
               %Seraph.Test.NoPropsRels.UserToPost.Read{
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 3",
                   title: "post3"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 },
                 type: "READ"
               }
             ] =
               Enum.sort(read_rels, fn %{end_node: %{title: title1}},
                                       %{end_node: %{title: title2}} ->
                 title1 <= title2
               end)

      assert [
               %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This post 1",
                 title: "post1"
               },
               %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This post 2",
                 title: "post2"
               },
               %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This post 3",
                 title: "post3"
               }
             ] =
               Enum.sort(read_posts, fn %{title: title1}, %{title: title2} -> title1 <= title2 end)
    end

    test ":one / :incoming / no result", %{uuids: uuids} do
      assert %Post{author: nil, wrote: nil} =
               TestRepo.Node.get(Post, uuids.post6)
               |> TestRepo.Node.preload(:wrote)
    end

    test ":one / :incoming / one result", %{uuids: uuids} do
      assert %Post{author: author, wrote: wrote_rel} =
               TestRepo.Node.get(Post, uuids.post1)
               |> TestRepo.Node.preload(:wrote)

      assert %Seraph.Test.User{
               additionalLabels: [],
               firstName: "John",
               lastName: "Doe",
               viewCount: 0
             } = author

      assert %Seraph.Test.UserToPost.Wrote{
               at: nil,
               end_node: %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This post 1",
                 title: "post1"
               },
               start_node: %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "John",
                 lastName: "Doe",
                 viewCount: 0
               },
               type: "WROTE"
             } = wrote_rel
    end

    test ":one / :incoming / many result", %{uuids: uuids} do
      assert_raise Seraph.Exception, fn ->
        TestRepo.Node.get(User, uuids.user1)
        |> TestRepo.Node.preload(:is_a)
      end
    end

    test ":many / :incoming / no result", %{uuids: uuids} do
      assert %Post{readers: [], read: []} =
               TestRepo.Node.get(Post, uuids.post4)
               |> TestRepo.Node.preload(:read)
    end

    test ":many / :incoming / one result", %{uuids: uuids} do
      assert %Post{readers: [reader], read: [read_rel]} =
               TestRepo.Node.get(Post, uuids.post2)
               |> TestRepo.Node.preload(:read)

      assert %Seraph.Test.NoPropsRels.UserToPost.Read{
               end_node: %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This post 2",
                 title: "post2"
               },
               start_node: %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "James",
                 lastName: "Who",
                 viewCount: 0
               },
               type: "READ"
             } = read_rel

      assert %Seraph.Test.User{
               additionalLabels: [],
               firstName: "James",
               lastName: "Who",
               viewCount: 0
             } = reader
    end

    test ":many / :incoming / many result", %{uuids: uuids} do
      assert %Post{readers: readers, read: read_rels} =
               TestRepo.Node.get(Post, uuids.post1)
               |> TestRepo.Node.preload(:read)

      assert [
               %Seraph.Test.NoPropsRels.UserToPost.Read{
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 1",
                   title: "post1"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 },
                 type: "READ"
               },
               %Seraph.Test.NoPropsRels.UserToPost.Read{
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 1",
                   title: "post1"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "John",
                   lastName: "Doe",
                   viewCount: 0
                 },
                 type: "READ"
               }
             ] =
               Enum.sort(read_rels, fn %{start_node: %{firstName: first_name1}},
                                       %{start_node: %{firstName: first_name2}} ->
                 first_name1 <= first_name2
               end)

      assert [
               %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "James",
                 lastName: "Who",
                 viewCount: 0
               },
               %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "John",
                 lastName: "Doe",
                 viewCount: 0
               }
             ] =
               Enum.sort(readers, fn %{firstName: first_name1}, %{firstName: first_name2} ->
                 first_name1 <= first_name2
               end)
    end

    test "retrieve all the relationship with the same type", %{uuids: uuids} do
      assert %User{comments: comments, posts: posts, wrote: wrote_rels} =
               TestRepo.Node.get(User, uuids.user1)
               |> TestRepo.Node.preload(:wrote)

      assert length(comments) > 0
      assert length(posts) > 0

      assert Enum.any?(wrote_rels, fn
               %Seraph.Test.UserToPost.Wrote{} -> true
               _ -> false
             end)

      assert Enum.any?(wrote_rels, fn
               %Seraph.Test.NoPropsRels.UserToComment.Wrote{} -> true
               _ -> false
             end)
    end

    test "using field name load only that data", %{uuids: uuids} do
      assert %User{comments: comments, posts: posts, wrote: wrote_rels} =
               TestRepo.Node.get(User, uuids.user1)
               |> TestRepo.Node.preload(:posts)

      assert %Seraph.Schema.Node.NotLoaded{} = comments
      assert length(posts) > 0

      assert Enum.all?(wrote_rels, fn
               %Seraph.Test.UserToPost.Wrote{} -> true
               _ -> false
             end)
    end
  end

  describe "preload multiple relationships" do
    test ":outgoing only", %{uuids: uuids} do
      assert %User{
               comments: comments,
               posts: posts,
               read_posts: read_posts,
               wrote: wrote_rels,
               read: read_rels
             } =
               TestRepo.Node.get(User, uuids.user1)
               |> TestRepo.Node.preload([:wrote, :read])

      assert length(comments) > 0
      assert length(posts) > 0
      assert length(read_posts) > 0
      assert length(wrote_rels) > 0
      assert length(read_rels) > 0
    end

    test ":incoming only", %{uuids: uuids} do
      assert %User{
               edited_posts: edited_posts,
               edited_by: edited_rels,
               admin_badge: admin_badge,
               is_a: is_a_rel
             } =
               TestRepo.Node.get(User, uuids.user2)
               |> TestRepo.Node.preload([:is_a, :edited_by])

      assert length(edited_posts) > 0
      assert length(edited_rels) > 0
      assert %Seraph.Test.Admin{} = admin_badge
      assert %Seraph.Test.NoPropsRels.UserToAdmin.IsA{} = is_a_rel
    end

    test ":outgoing + :incoming", %{uuids: uuids} do
      assert %User{
               comments: comments,
               posts: posts,
               wrote: wrote_rels,
               admin_badge: admin_badge,
               is_a: is_a_rel
             } =
               TestRepo.Node.get(User, uuids.user2)
               |> TestRepo.Node.preload([:wrote, :is_a])

      assert length(comments) > 0
      assert length(posts) > 0
      assert length(wrote_rels) > 0
      assert %Seraph.Test.Admin{} = admin_badge
      assert %Seraph.Test.NoPropsRels.UserToAdmin.IsA{} = is_a_rel
    end

    test "relationship type and field name at the same time", %{uuids: uuids} do
      assert %User{
               posts: posts,
               wrote: wrote_rels,
               admin_badge: admin_badge,
               is_a: is_a_rel
             } =
               TestRepo.Node.get(User, uuids.user2)
               |> TestRepo.Node.preload([:posts, :is_a])

      assert length(posts) > 0
      assert length(wrote_rels) > 0
      assert %Seraph.Test.Admin{} = admin_badge
      assert %Seraph.Test.NoPropsRels.UserToAdmin.IsA{} = is_a_rel
    end

    test "same relationship type and field name at the same time is ok", %{uuids: uuids} do
      assert %User{
               read_posts: read_posts,
               read: read_rels
             } =
               TestRepo.Node.get(User, uuids.user1)
               |> TestRepo.Node.preload([:read, :read_posts])

      assert length(read_posts) == 1
      assert length(read_rels) == 1
    end
  end

  describe "with option :load" do
    test "load: :nodes", %{uuids: uuids} do
      assert %User{
               read_posts: read_posts,
               read: read_rels
             } =
               TestRepo.Node.get(User, uuids.user1)
               |> TestRepo.Node.preload([:read], load: :nodes)

      assert length(read_posts) > 0
      assert %Seraph.Schema.Relationship.NotLoaded{} = read_rels
    end

    test "load: :relationships", %{uuids: uuids} do
      assert %User{
               read_posts: read_posts,
               read: read_rels
             } =
               TestRepo.Node.get(User, uuids.user1)
               |> TestRepo.Node.preload([:read], load: :relationships)

      assert %Seraph.Schema.Node.NotLoaded{} = read_posts
      assert length(read_rels) > 0
    end
  end

  test "Limit preload", %{uuids: uuids} do
    assert %User{posts: posts, wrote: wrote_rels} =
             TestRepo.Node.get(User, uuids.user1)
             |> TestRepo.Node.preload(:posts, limit: 2)

    assert length(posts) == 2
    assert length(wrote_rels) == 2
  end

  test "Force preload", %{uuids: uuids} do
    user =
      %User{read_posts: [read_posts]} =
      TestRepo.Node.get(User, uuids.user1)
      |> TestRepo.Node.preload(:read)

    cql = """
    MATCH
      (p:Post {uuid: $uuid})
    SET
      p.title = "Updated"
    """

    TestRepo.raw_query!(cql, %{uuid: uuids.post1})

    %User{read_posts: [not_forced_read_posts]} = TestRepo.Node.preload(user, :read)

    assert not_forced_read_posts == read_posts

    %User{read_posts: [forced_read_posts]} = TestRepo.Node.preload(user, :read, force: true)

    assert forced_read_posts.title == "Updated"

    cql = """
    MATCH
      (p:Post {uuid: $uuid})
    SET
      p.title = "post1"
    """

    TestRepo.raw_query!(cql, %{uuid: uuids.post1})
  end

  test "raise with invalid_opts", %{uuids: uuids} do
    user = TestRepo.Node.get(User, uuids.user1)

    assert_raise ArgumentError, fn ->
      TestRepo.Node.preload(user, [:read], load: :invalid)
    end

    assert_raise ArgumentError, fn ->
      TestRepo.Node.preload(user, [:read], force: :invalid)
    end

    assert_raise ArgumentError, fn ->
      TestRepo.Node.preload(user, [:read], limit: :invalid)
    end

    assert_raise ArgumentError, fn ->
      TestRepo.Node.preload(user, [:read], limit: -5)
    end

    assert_raise ArgumentError, fn ->
      TestRepo.Node.preload(user, [:read], limit: 0)
    end

    assert_raise ArgumentError, fn ->
      TestRepo.Node.preload(user, [:read], unknown: :invalid)
    end
  end
end
