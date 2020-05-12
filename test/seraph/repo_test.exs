defmodule Seraph.RepoTest do
  use ExUnit.Case, async: false
  alias Seraph.Support.Storage

  alias Seraph.TestRepo
  alias Seraph.Test.{Admin, Post, User}
  alias Seraph.Test.UserToPost.Wrote
  alias Seraph.Test.NoPropsRels.UserToComment

  import Seraph.Query

  setup_all do
    Storage.clear(TestRepo)
    Storage.add_fixtures(TestRepo)
  end

  # describe "query/3" do
  #   test "ok"
  #   test "no result"
  #   test "db error"
  #   test "raise when used with!"
  # end

  describe "all/2 with query" do
    # ##############################################NODE
    test "ok: no result returns [" do
      query =
        match [{u, User, %{uuid: "non-existing"}}],
          return: u

      assert [] == TestRepo.all(query)
    end

    test "ok: node with queryable" do
      query =
        match [{u, User}],
          where: u.firstName == "John" or u.firstName == "James",
          return: u

      assert [
               %{
                 "u" => %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "John",
                   lastName: "Doe",
                   viewCount: 0
                 }
               },
               %{
                 "u" => %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 }
               }
             ] = TestRepo.all(query)
    end

    test "ok: node without queryable" do
      query =
        match [{u}],
          where: u.firstName == "John" or u.firstName == "James",
          return: u

      assert [
               %{
                 "u" => %Seraph.Node{
                   labels: ["User"],
                   properties: %{
                     "firstName" => "John",
                     "lastName" => "Doe",
                     "viewCount" => 0
                   }
                 }
               },
               %{
                 "u" => %Seraph.Node{
                   labels: ["User"],
                   properties: %{
                     "firstName" => "James",
                     "lastName" => "Who",
                     "viewCount" => 0
                   }
                 }
               }
             ] = TestRepo.all(query)
    end

    test "ok: aliased result node" do
      query =
        match [{u, User}],
          where: u.firstName == "John" or u.firstName == "James",
          return: [person: u]

      assert [
               %{
                 "person" => %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "John",
                   lastName: "Doe",
                   viewCount: 0
                 }
               },
               %{
                 "person" => %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 }
               }
             ] = TestRepo.all(query)
    end

    # ############################################## RELATIONSHIP

    test "ok: relationship with queryable" do
      query =
        match [[{u}, [rel, Wrote], {p}]],
          return: rel

      results = TestRepo.all(query)

      assert is_list(results)
      assert length(results) == 5
    end

    test "relationship with queryable and start / end node in query result (relationship_result: contextual)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [rel, u, p]

      assert [
               %{
                 "p" => %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 "rel" => %Seraph.Test.UserToPost.Wrote{
                   at: nil,
                   end_node: %Seraph.Test.Post{
                     additionalLabels: [],
                     text: "This post 5",
                     title: "post5"
                   },
                   start_node: %Seraph.Test.User{
                     additionalLabels: [],
                     firstName: "James",
                     lastName: "Who",
                     viewCount: 0
                   },
                   type: "WROTE"
                 },
                 "u" => %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 }
               }
             ] = TestRepo.all(query)
    end

    test "relationship with queryable and only start node in query result (relationship_result: contextual)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [u, rel]

      assert [
               %{
                 "rel" => %Seraph.Test.UserToPost.Wrote{
                   at: nil,
                   end_node: nil,
                   start_node: %Seraph.Test.User{
                     additionalLabels: [],
                     firstName: "James",
                     lastName: "Who",
                     viewCount: 0
                   },
                   type: "WROTE"
                 },
                 "u" => %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 }
               }
             ] = TestRepo.all(query)
    end

    test "relationship with queryable and only end node in query result (relationship_result: contextual)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [rel, p]

      assert [
               %{
                 "p" => %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 "rel" => %Seraph.Test.UserToPost.Wrote{
                   at: nil,
                   end_node: %Seraph.Test.Post{
                     additionalLabels: [],
                     text: "This post 5",
                     title: "post5"
                   },
                   start_node: nil,
                   type: "WROTE"
                 }
               }
             ] = TestRepo.all(query)
    end

    test "relationship with queryable and without related nodes in query result (relationship_result: contextual)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [rel]

      assert [
               %{
                 "rel" => %Seraph.Test.UserToPost.Wrote{
                   at: nil,
                   end_node: nil,
                   start_node: nil,
                   type: "WROTE"
                 }
               }
             ] = TestRepo.all(query)
    end

    test "relationship with queryable and start / end node in query result  (relationship_result: no_nodes)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [rel, u, p]

      assert [
               %{
                 "p" => %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 "rel" => %Seraph.Test.UserToPost.Wrote{
                   at: nil,
                   end_node: nil,
                   start_node: nil,
                   type: "WROTE"
                 },
                 "u" => %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 }
               }
             ] = TestRepo.all(query, relationship_result: :no_nodes)
    end

    test "relationship with queryable and only start node in query result (relationship_result: no_nodes)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [u, rel]

      assert [
               %{
                 "rel" => %Seraph.Test.UserToPost.Wrote{
                   at: nil,
                   end_node: nil,
                   start_node: nil,
                   type: "WROTE"
                 },
                 "u" => %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 }
               }
             ] = TestRepo.all(query, relationship_result: :no_nodes)
    end

    test "relationship with queryable and only end node in query result (relationship_result: no_nodes)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [rel, p]

      assert [
               %{
                 "p" => %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 "rel" => %Seraph.Test.UserToPost.Wrote{
                   at: nil,
                   end_node: nil,
                   start_node: nil,
                   type: "WROTE"
                 }
               }
             ] = TestRepo.all(query, relationship_result: :no_nodes)
    end

    test "relationship with queryable and without related nodes in query result (relationship_result: no_nodes)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [rel]

      assert [
               %{
                 "rel" => %Seraph.Test.UserToPost.Wrote{
                   at: nil,
                   end_node: nil,
                   start_node: nil,
                   type: "WROTE"
                 }
               }
             ] = TestRepo.all(query, relationship_result: :no_nodes)
    end

    test "relationship with queryable and start / end node in query result (relationship_result: full)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [rel, u, p]

      assert [
               %{
                 "p" => %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 "rel" => %Seraph.Test.UserToPost.Wrote{
                   at: nil,
                   end_node: %Seraph.Test.Post{
                     additionalLabels: [],
                     text: "This post 5",
                     title: "post5"
                   },
                   start_node: %Seraph.Test.User{
                     additionalLabels: [],
                     firstName: "James",
                     lastName: "Who",
                     viewCount: 0
                   },
                   type: "WROTE"
                 },
                 "u" => %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 }
               }
             ] = TestRepo.all(query, relationship_result: :full)
    end

    test "relationship with queryable and only start node in query result (relationship_result: full)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [u, rel]

      assert [results] = TestRepo.all(query, relationship_result: :full)

      assert %{
               "rel" => %Seraph.Test.UserToPost.Wrote{
                 at: nil,
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 },
                 type: "WROTE"
               },
               "u" => %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "James",
                 lastName: "Who",
                 viewCount: 0
               }
             } = results

      assert map_size(results) == 2
    end

    test "relationship with queryable and only start node in query result - end node unaliased (relationship_result: full)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {}]],
          return: [u, rel]

      assert [results] = TestRepo.all(query, relationship_result: :full)

      assert %{
               "rel" => %Seraph.Test.UserToPost.Wrote{
                 at: nil,
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 },
                 type: "WROTE"
               },
               "u" => %Seraph.Test.User{
                 additionalLabels: [],
                 firstName: "James",
                 lastName: "Who",
                 viewCount: 0
               }
             } = results

      assert map_size(results) == 2
    end

    test "relationship with queryable and only end node in query result (relationship_result: full)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [rel, p]

      assert [results] = TestRepo.all(query, relationship_result: :full)

      assert %{
               "p" => %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This post 5",
                 title: "post5"
               },
               "rel" => %Seraph.Test.UserToPost.Wrote{
                 at: nil,
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 },
                 type: "WROTE"
               }
             } = results

      assert map_size(results) == 2
    end

    test "relationship with queryable and only end node in query result - start node unaliased (relationship_result: full)" do
      query =
        match [[{}, [rel, Wrote], {p, %{title: "post5"}}]],
          return: [rel, p]

      assert [results] = TestRepo.all(query, relationship_result: :full)

      assert %{
               "p" => %Seraph.Test.Post{
                 additionalLabels: [],
                 text: "This post 5",
                 title: "post5"
               },
               "rel" => %Seraph.Test.UserToPost.Wrote{
                 at: nil,
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 },
                 type: "WROTE"
               }
             } = results

      assert map_size(results) == 2
    end

    test "relationship with queryable and without related nodes in query result (relationship_result: full)" do
      query =
        match [[{u, %{firstName: "James"}}, [rel, Wrote], {p}]],
          return: [rel]

      assert [results] = TestRepo.all(query, relationship_result: :full)

      assert %{
               "rel" => %Seraph.Test.UserToPost.Wrote{
                 at: nil,
                 end_node: %Seraph.Test.Post{
                   additionalLabels: [],
                   text: "This post 5",
                   title: "post5"
                 },
                 start_node: %Seraph.Test.User{
                   additionalLabels: [],
                   firstName: "James",
                   lastName: "Who",
                   viewCount: 0
                 },
                 type: "WROTE"
               }
             } = results

      assert map_size(results) == 1
    end

    test "relationship with queryable and without related nodes in query result - unaliased start / end (relationship_result: full)" do
      query =
        match [[{}, [rel, Wrote], {}]],
          return: [rel]

      assert results = TestRepo.all(query, relationship_result: :full)

      assert length(results) == 5

      Enum.each(results, fn result ->
        assert map_size(result) == 1
        assert Map.keys(result) == ["rel"]
      end)
    end

    test "ok: relationship without queryable" do
      query =
        match [[{u, User}, [rel], {p}]],
          return: rel

      results = TestRepo.all(query)

      assert is_list(results)
      assert length(results) == 21
    end

    # test "relationship without queryable and start / end node in query result" do
    #   query =
    #     match [[{u, User}, [rel], {a, Admin}]],
    #       return: [u, rel, a]

    #   TestRepo.all(query)
    #   |> IO.inspect()
    # end

    # test "relationship without queryable and only start node in query result"
    # test "relationship without queryable and only end node in query result"
    # test "relationship without queryable and without related nodes in query result"
  end
end
