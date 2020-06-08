defmodule Seraph.IntegrationTest do
  use ExUnit.Case, async: false
  alias Seraph.Support.Storage

  alias Seraph.TestRepo
  alias Seraph.Test.{Admin, Post, User}
  alias Seraph.Test.UserToPost.Wrote

  import Seraph.Query

  setup do
    Storage.clear(TestRepo)
    Storage.add_fixtures(TestRepo)
  end

  # test "return value" do
  #   assert =
  #     match([{u, User}])
  #     |> return(num: 1)
  #     |> TestRepo.all()
  #     |> IO.inspect()
  # end

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
    assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
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

    assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
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
    assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
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

    assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
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

    assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
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
    assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
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
    assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
  end

  describe "merge on create / on merge" do
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
      assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
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
      assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
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
             ] = TestRepo.query!(cql_check, params)
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

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
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

      assert [%{"nb_result" => 1}] = TestRepo.query!(cql_check, params)
    end
  end
end
