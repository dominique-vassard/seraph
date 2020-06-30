defmodule Seraph.IntegrationTest do
  use ExUnit.Case, async: false
  alias Seraph.Support.Storage

  alias Seraph.TestRepo
  alias Seraph.Test.{Post, User}
  alias Seraph.Test.UserToPost.Wrote

  import Seraph.Query

  setup do
    Storage.clear(TestRepo)
    Storage.add_fixtures(TestRepo)
  end

  test "return value" do
    assert [%{"num" => 1}] =
             match([{u, User}])
             |> return(num: 1)
             |> limit(1)
             |> TestRepo.query!()
  end

  test "create node - direct" do
    uuid = UUID.uuid4()

    assert [result] =
             create([{u, User, %{uuid: ^uuid, firstName: "Ben", lastName: "New"}}])
             |> return(u)
             |> TestRepo.all()

    assert %{
             "u" => %Seraph.Test.User{
               additionalLabels: [],
               firstName: "Ben",
               lastName: "New",
               viewCount: 1
             }
           } = result

    cql_check = """
    MATCH
      (u:User {firstName: $first_name, lastName: $last_name})
    RETURN
      COUNT(u) AS nb_result
    """

    params = %{first_name: "Ben", last_name: "New"}
    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  test "create relationship - direct" do
    user_uuid = UUID.uuid4()
    post_uuid = UUID.uuid4()
    date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")

    assert [result] =
             create([
               [
                 {u, User, %{uuid: ^user_uuid, firstName: "Ben", lastName: "New"}},
                 [rel, Wrote, %{at: ^date}],
                 {p, Post, %{uuid: ^post_uuid, title: "New Post"}}
               ]
             ])
             |> return([rel])
             |> TestRepo.all()

    assert %{
             "rel" => %Seraph.Test.UserToPost.Wrote{
               end_node: nil,
               start_node: nil,
               type: "WROTE"
             }
           } = result

    refute is_nil(result["rel"].at)

    cql_check = """
    MATCH
      (u:User {uuid: $user_uuid, firstName: $first_name, lastName: $last_name}),
      (p:Post {uuid: $post_uuid, title: $title}),
      (u)-[rel:WROTE]->(p)
    RETURN
      COUNT(rel) AS nb_result
    """

    params = %{
      user_uuid: user_uuid,
      first_name: "Ben",
      last_name: "New",
      post_uuid: post_uuid,
      title: "New Post"
    }

    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  test "create/set node " do
    uuid = UUID.uuid4()

    assert [result] =
             create([{u, User}])
             |> set([u.uuid = ^uuid, u.firstName = "Ben", u.lastName = "New"])
             |> return(u)
             |> TestRepo.all()

    assert %{
             "u" => %Seraph.Test.User{
               additionalLabels: [],
               firstName: "Ben",
               lastName: "New",
               viewCount: 1
             }
           } = result

    cql_check = """
    MATCH
      (u:User {firstName: $first_name, lastName: $last_name})
    RETURN
      COUNT(u) AS nb_result
    """

    params = %{first_name: "Ben", last_name: "New"}
    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  test "match/create/set relationship" do
    user_uuid = UUID.uuid4()
    post_uuid = UUID.uuid4()
    date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")

    assert [result] =
             create([[{u, User}, [rel, Wrote], {p, Post}]])
             |> set([
               u.uuid = ^user_uuid,
               u.firstName = "Ben",
               u.lastName = "New",
               p.uuid = ^post_uuid,
               p.title = "New Post",
               rel.at = ^date
             ])
             |> return([rel])
             |> TestRepo.all()

    assert %{
             "rel" => %Seraph.Test.UserToPost.Wrote{
               end_node: nil,
               start_node: nil,
               type: "WROTE"
             }
           } = result

    refute is_nil(result["rel"].at)

    cql_check = """
    MATCH
      (u:User {uuid: $user_uuid, firstName: $first_name, lastName: $last_name}),
      (p:Post {uuid: $post_uuid, title: $title}),
      (u)-[rel:WROTE]->(p)
    RETURN
      COUNT(rel) AS nb_result
    """

    params = %{
      user_uuid: user_uuid,
      first_name: "Ben",
      last_name: "New",
      post_uuid: post_uuid,
      title: "New Post"
    }

    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  test "match/set relationship", %{uuids: uuids} do
    user_uuid = uuids.user1
    post_uuid = uuids.post6
    date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")

    assert [result] =
             match([{u, User, %{uuid: ^user_uuid}}, {p, Post, %{uuid: ^post_uuid}}])
             |> create([[{u}, [rel, Wrote], {p}]])
             |> set([rel.at = ^date])
             |> return([rel])
             |> TestRepo.all()

    assert %{
             "rel" => %Seraph.Test.UserToPost.Wrote{
               end_node: nil,
               start_node: nil,
               type: "WROTE"
             }
           } = result

    refute is_nil(result["rel"].at)

    cql_check = """
    MATCH
      (u:User {uuid: $user_uuid}),
      (p:Post {uuid: $post_uuid}),
      (u)-[rel:WROTE]->(p)
    RETURN
      COUNT(rel) AS nb_result
    """

    params = %{
      user_uuid: user_uuid,
      post_uuid: post_uuid
    }

    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  test "match/set with value", %{uuids: uuids} do
    user_uuid = uuids.user1

    query =
      match [{u, User, %{uuid: ^user_uuid}}],
        set: [u.firstName = "Updated"],
        return: [[first_name: u.firstName]]

    assert [result] = TestRepo.all(query)

    assert %{"first_name" => "Updated"} = result

    cql_check = """
    MATCH
      (u:User {firstName: $first_name})
    RETURN
      COUNT(u) AS nb_result
    """

    params = %{first_name: "Updated"}
    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  test "match/set with function", %{uuids: uuids} do
    user_uuid = uuids.user1

    query =
      match [{u, User, %{uuid: ^user_uuid}}],
        set: [u.viewCount = u.viewCount + 5],
        return: [[view_count: u.viewCount]]

    assert [result] = TestRepo.all(query)

    assert %{"view_count" => 5} = result

    cql_check = """
    MATCH
      (u:User {uuid: $user_uuid, viewCount: $view_count})
    RETURN
      COUNT(u) AS nb_result
    """

    params = %{user_uuid: user_uuid, view_count: 5}
    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  describe "merge on create / on match" do
    test "node creation (bare merge)" do
      uuid = UUID.uuid4()

      query =
        merge {u, User, %{uuid: ^uuid, firstName: "New User"}},
          return: [u]

      assert [result] = TestRepo.all(query)

      cql_check = """
      MATCH
        (u:User {uuid: $user_uuid, firstName: $first_name})
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{user_uuid: uuid, first_name: "New User"}
      assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
    end

    test "node creation" do
      uuid = UUID.uuid4()

      query =
        merge {u, User, %{uuid: ^uuid}},
          on_create_set: [u.firstName = "New User"],
          return: [u]

      assert [result] = TestRepo.all(query)

      cql_check = """
      MATCH
        (u:User {uuid: $user_uuid, firstName: $first_name})
      RETURN
        COUNT(u) AS nb_result
      """

      params = %{user_uuid: uuid, first_name: "New User"}
      assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
    end

    test "node update", %{uuids: uuids} do
      user_uuid = uuids.user1

      merge({u, User, %{uuid: ^user_uuid}})
      |> on_create_set([u.firstName = "New User"])
      |> return([u])
      |> TestRepo.all()

      query =
        merge {u, User, %{uuid: ^user_uuid}},
          on_match_set: [u.firstName = "Updated"],
          return: [u]

      assert [result] = TestRepo.all(query)

      cql_check = """
      MATCH
        (u:User {uuid: $user_uuid})
      RETURN
         u
      """

      params = %{user_uuid: user_uuid}

      assert [
               %{
                 "u" => %Bolt.Sips.Types.Node{
                   labels: ["User"],
                   properties: %{"firstName" => "Updated", "lastName" => "Doe", "viewCount" => 0}
                 }
               }
             ] = TestRepo.raw_query!(cql_check, params)
    end

    test "relationship creation", %{uuids: uuids} do
      user_uuid = uuids.user1
      post_uuid = uuids.post6
      date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")

      assert [result] =
               match([{u, User, %{uuid: ^user_uuid}}, {p, Post, %{uuid: ^post_uuid}}])
               |> merge([{u}, [rel, Wrote], {p}])
               |> on_create_set([rel.at = ^date])
               |> return([rel])
               |> TestRepo.all()

      assert %{
               "rel" => %Seraph.Test.UserToPost.Wrote{
                 end_node: nil,
                 start_node: nil,
                 type: "WROTE"
               }
             } = result

      refute is_nil(result["rel"].at)

      cql_check = """
      MATCH
        (u:User {uuid: $user_uuid}),
        (p:Post {uuid: $post_uuid}),
        (u)-[rel:WROTE]->(p)
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: user_uuid,
        post_uuid: post_uuid
      }

      assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
    end

    test "relationship update", %{uuids: uuids} do
      user_uuid = uuids.user1
      post_uuid = uuids.post1

      date = DateTime.from_naive!(~N[2016-05-24 13:26:08], "Etc/UTC")

      assert [result] =
               match([{u, User, %{uuid: ^user_uuid}}, {p, Post, %{uuid: ^post_uuid}}])
               |> merge([{u}, [rel, Wrote], {p}])
               |> on_match_set([rel.at = ^date])
               |> return([rel])
               |> TestRepo.all()

      assert %{
               "rel" => %Seraph.Test.UserToPost.Wrote{
                 end_node: nil,
                 start_node: nil,
                 type: "WROTE"
               }
             } = result

      refute is_nil(result["rel"].at)

      cql_check = """
      MATCH
        (u:User {uuid: $user_uuid}),
        (p:Post {uuid: $post_uuid}),
        (u)-[rel:WROTE {at: $date}]->(p)
      RETURN
        COUNT(rel) AS nb_result
      """

      params = %{
        user_uuid: user_uuid,
        post_uuid: post_uuid,
        date: date
      }

      assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
    end
  end

  describe "where" do
    test "starts_with" do
      query =
        match [{u, User}],
          where: starts_with(u.firstName, "J"),
          return: [u.firstName]

      assert [%{"u.firstName" => "John"}, %{"u.firstName" => "James"}] = TestRepo.query!(query)
    end

    test "xor" do
      query =
        match [{u, User}],
          where: xor(u.firstName == "John", u.firstName == "Jack"),
          return: [u.firstName]

      assert [%{"u.firstName" => "John"}] = TestRepo.query!(query)
    end
  end

  test "set label" do
    uuid = UUID.uuid4()

    {:ok, _} =
      create([{u, User, %{uuid: ^uuid, firstName: "Ben", lastName: "New"}}])
      |> return(u)
      |> TestRepo.query()

    query =
      match [{u, User, %{uuid: uuid}}],
        set: [{u, New}],
        return: [u]

    assert [
             %{
               "u" => %Seraph.Test.User{
                 additionalLabels: ["New"],
                 firstName: "Ben",
                 lastName: "New",
                 viewCount: 1
               }
             }
           ] = TestRepo.query!(query)

    cql_check = """
    MATCH
      (u:User:New {uuid: $uuid})
    WHERE
      labels(u) = ["User", "New"]
    RETURN
      COUNT(u) AS nb_result
    """

    params = %{uuid: uuid}
    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  test "remove property" do
    uuid = UUID.uuid4()

    {:ok, _} =
      create([{u, User, %{uuid: ^uuid, firstName: "Ben", lastName: "New"}}])
      |> return(u)
      |> TestRepo.query()

    query =
      match [{u, User, %{uuid: uuid}}],
        remove: [u.firstName],
        return: [u]

    assert [
             %{
               "u" => %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: nil,
                 lastName: "New",
                 viewCount: 1
               }
             }
           ] = TestRepo.query!(query)

    cql_check = """
    MATCH
      (u:User {uuid: $uuid})
    WHERE
      u.firstName IS NULL
    RETURN
      COUNT(u) AS nb_result
    """

    params = %{uuid: uuid}
    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  test "remove label" do
    uuid = UUID.uuid4()

    {:ok, _} =
      create([
        {u, User,
         %{additionalLabels: ["New", "Good"], uuid: ^uuid, firstName: "Ben", lastName: "New"}}
      ])
      |> return(u)
      |> TestRepo.query()

    query =
      match [{u, User, %{uuid: uuid}}],
        remove: [{u, Good}],
        return: [u]

    assert [
             %{
               "u" => %Seraph.Test.User{
                 additionalLabels: ["New"],
                 firstName: "Ben",
                 lastName: "New",
                 viewCount: 1
               }
             }
           ] = TestRepo.query!(query)

    cql_check = """
    MATCH
      (u:User:New {uuid: $uuid})
    WHERE
      labels(u) = ["User", "New"]
    RETURN
      COUNT(u) AS nb_result
    """

    params = %{uuid: uuid}
    assert [%{"nb_result" => 1}] = TestRepo.raw_query!(cql_check, params)
  end

  test "delete node", %{uuids: uuids} do
    user_uuid = uuids.user1

    query =
      match([{u, User, %{uuid: ^user_uuid}}])
      |> delete([u])

    assert [] = TestRepo.query!(query)

    cql_check = """
    MATCH
      (u:User {uuid: $user_uuid})
    RETURN
       COUNT(u) AS nb_result
    """

    params = %{
      user_uuid: user_uuid
    }

    assert [%{"nb_result" => 0}] == TestRepo.raw_query!(cql_check, params)
  end

  test "delete relationship", %{uuids: uuids} do
    user_uuid = uuids.user1
    post_uuid = uuids.post1

    query =
      match([[{u, User, %{uuid: ^user_uuid}}, [rel, Wrote], {p, Post, %{uuid: ^post_uuid}}]])
      |> delete([rel])

    assert [] = TestRepo.query!(query)

    cql_check = """
    MATCH
      (u:User {uuid: $user_uuid}),
      (p:Post {uuid: $post_uuid}),
      (u)-[rel:WROTE]->(p)
    RETURN
       COUNT(rel) AS nb_result
    """

    params = %{
      user_uuid: user_uuid,
      post_uuid: post_uuid
    }

    assert [%{"nb_result" => 0}] == TestRepo.raw_query!(cql_check, params)
  end

  test "limit" do
    assert [_] =
             match([{u, User}])
             |> return([u])
             |> limit(1)
             |> TestRepo.query!()

    limit = 2

    query =
      match [{u, User}],
        return: [u],
        limit: ^limit

    assert [_, _] = TestRepo.query!(query)
  end

  test "skip" do
    assert [
             %{"u.firstName" => "James"},
             %{"u.firstName" => "John"}
           ] =
             match([{u, User}])
             |> return([u.firstName])
             |> order_by([u.firstName])
             |> skip(1)
             |> TestRepo.query!()

    skip = 2

    query =
      match [{u, User}],
        return: [u.firstName],
        order_by: [u.firstName],
        skip: ^skip

    assert [%{"u.firstName" => "John"}] = TestRepo.query!(query)
  end

  test "skip + limit" do
    assert [
             %{"u.firstName" => "James"}
           ] =
             match([{u, User}])
             |> return([u.firstName])
             |> order_by([u.firstName])
             |> skip(1)
             |> limit(1)
             |> TestRepo.query!()
  end

  test "order_by" do
    assert [
             %{"u.firstName" => "John", "u.lastName" => "Doe"},
             %{"u.firstName" => "Igor", "u.lastName" => "Gone"},
             %{"u.firstName" => "James", "u.lastName" => "Who"}
           ] =
             match([{u, User}])
             |> return([u.firstName, u.lastName])
             |> order_by(asc: u.lastName, desc: u.firstName)
             |> TestRepo.query!()
  end
end
